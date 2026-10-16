import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../utils/json_safe.dart';

class CacheService {
  final AppDatabase _dbManager;

  CacheService({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  Database get _db => _dbManager.db;

  String _buildScopedKey(String instanceId, String key) => '${instanceId}_$key';

  Future<void> put({
    required String key,
    required dynamic data,
    required String instanceId,
    Duration ttl = const Duration(minutes: 30),
    String? tag,
  }) async {
    try {
      final scopedKey = _buildScopedKey(instanceId, key);
      final jsonStr = jsonEncode(data);
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.insert('cache_entries', {
        'key': scopedKey,
        'instance_id': instanceId,
        'tag': tag,
        'data': jsonStr,
        'created_at': now,
        'ttl_ms': ttl.inMilliseconds,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('[CacheService] Ошибка записи в кэш ($key): $e');
    }
  }

  Future<dynamic> get({
    required String key,
    required String instanceId,
    bool ignoreTtl = false,
  }) async {
    try {
      final scopedKey = _buildScopedKey(instanceId, key);
      final results = await _db.query(
        'cache_entries',
        where: 'key = ?',
        whereArgs: [scopedKey],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final createdAt = JsonSafe.toInt(row['created_at']);
      final ttlMs = JsonSafe.toInt(row['ttl_ms']);
      final now = DateTime.now().millisecondsSinceEpoch;

      final isExpired = now > (createdAt + ttlMs);

      if (isExpired && !ignoreTtl) {
        await invalidate(key: key, instanceId: instanceId);
        return null;
      }

      final dataStr = JsonSafe.toStr(row['data']);
      if (dataStr.isEmpty) return null;

      return jsonDecode(dataStr);
    } catch (e) {
      debugPrint('[CacheService] Ошибка чтения из кэша ($key): $e');
      return null;
    }
  }

  Future<void> invalidate({
    required String key,
    required String instanceId,
  }) async {
    try {
      final scopedKey = _buildScopedKey(instanceId, key);
      await _db.delete(
        'cache_entries',
        where: 'key = ?',
        whereArgs: [scopedKey],
      );
    } catch (e) {
      debugPrint('[CacheService] Ошибка инвалидации кэша ($key): $e');
    }
  }

  Future<void> invalidateMessagesCache(String instanceId) async {
    if (!_dbManager.isInitialized) return;
    try {
      await _db.delete(
        'cache_entries',
        where: "instance_id = ? AND (tag = 'messages_conversations' OR tag LIKE 'history_%')",
        whereArgs: [instanceId],
      );
    } catch (e) {
      debugPrint('[CacheService] Ошибка очистки устаревшего кэша сообщений: $e');
    }
  }

  Future<void> invalidateByTag({
    required String tag,
    required String instanceId,
  }) async {
    try {
      await _db.delete(
        'cache_entries',
        where: 'instance_id = ? AND tag = ?',
        whereArgs: [instanceId, tag],
      );
    } catch (e) {
      debugPrint('[CacheService] Ошибка инвалидации по тегу ($tag): $e');
    }
  }

  Future<bool> hasAnyCachedMessagesOrConversations(String instanceId) async {
    try {
      final results = await _db.rawQuery(
        "SELECT 1 FROM cache_entries WHERE instance_id = ? AND (tag = 'messages_conversations' OR tag LIKE 'history_%') LIMIT 1",
        [instanceId],
      );
      return results.isNotEmpty;
    } catch (e) {
      debugPrint('[CacheService] Ошибка проверки кэша сообщений: $e');
      return false;
    }
  }

  Future<bool> hasEntriesWithTag({
    required String tag,
    required String instanceId,
  }) async {
    try {
      final results = await _db.query(
        'cache_entries',
        columns: ['key'],
        where: 'instance_id = ? AND tag = ?',
        whereArgs: [instanceId, tag],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      debugPrint('[CacheService] Ошибка проверки записей по тегу ($tag): $e');
      return false;
    }
  }

  Future<int> cleanExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      return await _db.delete(
        'cache_entries',
        where: '(? - created_at) > ttl_ms',
        whereArgs: [now],
      );
    } catch (e) {
      debugPrint('[CacheService] Ошибка очистки устаревшего кэша: $e');
      return 0;
    }
  }

  Future<void> clearAll({String? instanceId}) async {
    try {
      if (instanceId != null) {
        await _db.delete(
          'cache_entries',
          where: 'instance_id = ?',
          whereArgs: [instanceId],
        );
      } else {
        await _db.delete('cache_entries');
      }
    } catch (e) {
      debugPrint('[CacheService] Ошибка полной очистки кэша: $e');
    }
  }

  /// Appends a new newsfeed segment to an existing cached newsfeed entry for [key].
  ///
  /// Merges new items into existing cached items avoiding duplicate posts
  /// (checked by composite key owner_id:id). Also merges profiles and groups
  /// and updates the [next_from] pagination cursor.
  Future<void> appendNewsfeedSegment({
    required String key,
    required Map<String, dynamic> newSegment,
    required String instanceId,
    Duration ttl = const Duration(hours: 1),
    String? tag = 'newsfeed',
    int maxItems = 250,
  }) async {
    try {
      final existingData = await get(
        key: key,
        instanceId: instanceId,
        ignoreTtl: true,
      );

      if (existingData is! Map) {
        await put(
          key: key,
          data: newSegment,
          instanceId: instanceId,
          ttl: ttl,
          tag: tag,
        );
        return;
      }

      final existingMap = Map<String, dynamic>.from(existingData);

      final existingItems =
          List<dynamic>.from(existingMap['items'] as List? ?? []);
      final newItems =
          List<dynamic>.from(newSegment['items'] as List? ?? []);

      String itemKey(dynamic item) {
        if (item is Map) {
          final sourceId = item['source_id'];
          final ownerId = item['owner_id'] ?? sourceId ?? item['to_id'] ?? 0;
          final id = item['id'] ?? item['post_id'] ?? 0;
          return '$ownerId:$id';
        }
        return item.toString();
      }

      final seenItemKeys = <String>{
        for (final item in existingItems) itemKey(item),
      };

      for (final item in newItems) {
        final k = itemKey(item);
        if (!seenItemKeys.contains(k)) {
          seenItemKeys.add(k);
          existingItems.add(item);
        }
      }

      if (existingItems.length > maxItems) {
        existingItems.length = maxItems;
      }

      final existingProfiles =
          List<dynamic>.from(existingMap['profiles'] as List? ?? []);
      final newProfiles =
          List<dynamic>.from(newSegment['profiles'] as List? ?? []);
      final seenProfileIds = <dynamic>{
        for (final p in existingProfiles) if (p is Map) p['id'],
      };
      for (final p in newProfiles) {
        if (p is Map) {
          final id = p['id'];
          if (id != null && !seenProfileIds.contains(id)) {
            seenProfileIds.add(id);
            existingProfiles.add(p);
          }
        }
      }

      final existingGroups =
          List<dynamic>.from(existingMap['groups'] as List? ?? []);
      final newGroups =
          List<dynamic>.from(newSegment['groups'] as List? ?? []);
      final seenGroupIds = <dynamic>{
        for (final g in existingGroups) if (g is Map) g['id'],
      };
      for (final g in newGroups) {
        if (g is Map) {
          final id = g['id'];
          if (id != null && !seenGroupIds.contains(id)) {
            seenGroupIds.add(id);
            existingGroups.add(g);
          }
        }
      }

      final nextFrom = newSegment['next_from'] ?? existingMap['next_from'];

      final merged = <String, dynamic>{
        'items': existingItems,
        'profiles': existingProfiles,
        'groups': existingGroups,
        'next_from': ?nextFrom,
      };

      await put(
        key: key,
        data: merged,
        instanceId: instanceId,
        ttl: ttl,
        tag: tag,
      );
    } catch (e) {
      debugPrint('[CacheService] Ошибка appendNewsfeedSegment ($key): $e');
    }
  }

  /// Removes a post from newsfeed caches by [ownerId] and [postId].
  Future<void> removePostFromNewsfeedCache({
    required int ownerId,
    required int postId,
    required String instanceId,
  }) async {
    for (final key in const ['newsfeed_my', 'newsfeed_global']) {
      try {
        final data =
            await get(key: key, instanceId: instanceId, ignoreTtl: true);
        if (data is Map && data['items'] is List) {
          final items = List<dynamic>.from(data['items'] as List);
          final initialLen = items.length;
          items.removeWhere((item) {
            if (item is Map) {
              final sOwnerId =
                  item['owner_id'] ?? item['source_id'] ?? item['to_id'] ?? 0;
              final sId = item['id'] ?? item['post_id'] ?? 0;
              return sOwnerId == ownerId && sId == postId;
            }
            return false;
          });
          if (items.length != initialLen) {
            final updated = Map<String, dynamic>.from(data);
            updated['items'] = items;
            await put(
              key: key,
              data: updated,
              instanceId: instanceId,
              tag: 'newsfeed',
            );
          }
        }
      } catch (e) {
        debugPrint('[CacheService] Ошибка удаления поста из кэша ($key): $e');
      }
    }
  }
}
