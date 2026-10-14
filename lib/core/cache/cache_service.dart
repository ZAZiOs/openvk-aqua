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
}
