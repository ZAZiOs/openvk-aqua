import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../utils/json_safe.dart';
import 'api_response.dart';
import 'openvk_client.dart';

class OpenVkInstance {
  final int id;
  final String name;
  final String baseUrl;
  final bool isActive;

  const OpenVkInstance({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.isActive,
  });

  String get domain {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host.isNotEmpty ? uri.host : baseUrl;
    } catch (_) {
      return baseUrl;
    }
  }

  factory OpenVkInstance.fromMap(Map<String, dynamic> map) {
    return OpenVkInstance(
      id: JsonSafe.toInt(map['id']),
      name: JsonSafe.toStr(map['name']),
      baseUrl: JsonSafe.toStr(map['base_url']),
      isActive: JsonSafe.toBool(map['is_active']),
    );
  }
}

class SavedAccount {
  final int id;
  final int instanceId;
  final int userId;
  final String name;
  final String avatarUrl;
  final String accessToken;
  final bool isActive;

  const SavedAccount({
    required this.id,
    required this.instanceId,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.accessToken,
    required this.isActive,
  });

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    return SavedAccount(
      id: JsonSafe.toInt(map['id']),
      instanceId: JsonSafe.toInt(map['instance_id']),
      userId: JsonSafe.toInt(map['user_id']),
      name: JsonSafe.toStr(map['name']),
      avatarUrl: JsonSafe.toStr(map['avatar_url']),
      accessToken: JsonSafe.toStr(map['access_token']),
      isActive: JsonSafe.toBool(map['is_active']),
    );
  }
}

class AuthHandler {
  final OpenVkClient client;
  final AppDatabase dbManager;
  final http.Client _httpClient;

  AuthHandler({
    required this.client,
    AppDatabase? dbManager,
    http.Client? httpClient,
  }) : dbManager = dbManager ?? AppDatabase.instance,
       _httpClient = httpClient ?? http.Client();

  Database get _db => dbManager.db;

  Future<ApiResponse<SavedAccount>> login({
    required String username,
    required String password,
    String? instanceBaseUrl,
    String? code,
  }) async {
    final targetUrl = instanceBaseUrl ?? client.baseUrl;
    final normalizedUrl = targetUrl.endsWith('/')
        ? targetUrl.substring(0, targetUrl.length - 1)
        : targetUrl;

    final clientName = 'ovkflutter${Platform.isIOS ? '_ios' : ''}';
    final queryParams = <String, String>{
      'username': username,
      'password': password,
      'grant_type': 'password',
      'client_name': clientName,
    };
    if (code != null && code.isNotEmpty) {
      queryParams['code'] = code;
    }

    final tokenUri = Uri.parse('$normalizedUrl/token')
        .replace(queryParameters: queryParams);

    try {
      final response = await _httpClient
          .get(tokenUri)
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return const ApiFailure(
          ApiError(
            kind: ApiErrorKind.parse,
            message: 'Неверный ответ сервера авторизации',
          ),
        );
      }

      final map = Map<String, dynamic>.from(decoded);

      if (map.containsKey('error') || map.containsKey('error_code')) {
        final err = JsonSafe.toStr(map['error']);
        if (err == 'need_validation' ||
            err == '2fa_required' ||
            map.containsKey('validation_type')) {
          return const ApiFailure(
            ApiError(kind: ApiErrorKind.unauthorized, message: 'need_2fa'),
          );
        }
        final errorMsg = JsonSafe.toStr(
          map['error_description'] ?? map['error_msg'] ?? map['error'],
          'Неверный логин или пароль',
        );
        return ApiFailure(
          ApiError(kind: ApiErrorKind.unauthorized, message: errorMsg),
        );
      }

      final accessToken = JsonSafe.toStr(map['access_token']);
      if (accessToken.isEmpty) {
        return const ApiFailure(
          ApiError(
            kind: ApiErrorKind.unauthorized,
            message: 'Токен доступа не получен',
          ),
        );
      }

      client.updateSession(
        newBaseUrl: normalizedUrl,
        newAccessToken: accessToken,
      );

      final userInfoResponse = await client.call<Map<String, dynamic>>(
        'users.get',
        params: {'fields': 'photo_100'},
        parser: (json) {
          if (json is List && json.isNotEmpty) {
            return JsonSafe.toMap(json.first);
          }
          return {};
        },
      );

      final userMap = userInfoResponse.dataOrNull ?? {};
      final userId = JsonSafe.toInt(userMap['id']);
      final firstName = JsonSafe.toStr(userMap['first_name'], username);
      final lastName = JsonSafe.toStr(userMap['last_name']);
      final fullName = '$firstName $lastName'.trim();
      final avatarUrl = JsonSafe.toStr(userMap['photo_100']);

      final instanceId = await _saveOrUpdateInstance(normalizedUrl);

      final account = await _saveAccount(
        instanceId: instanceId,
        userId: userId,
        name: fullName,
        avatarUrl: avatarUrl,
        accessToken: accessToken,
      );

      client.messengerStore.currentUserId = account.userId;
      unawaited(client.longPollService.checkAndStart());

      return ApiSuccess(account);
    } catch (e) {
      debugPrint('[AuthHandler] Ошибка авторизации: $e');
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.network,
          message: 'Не удалось подключиться к $normalizedUrl',
        ),
      );
    }
  }

  Future<SavedAccount?> restoreSession() async {
    try {
      final activeAccounts = await _db.query(
        'accounts',
        where: 'is_active = 1',
        limit: 1,
      );

      if (activeAccounts.isEmpty) return null;

      final account = SavedAccount.fromMap(activeAccounts.first);

      final instanceRows = await _db.query(
        'instances',
        where: 'id = ?',
        whereArgs: [account.instanceId],
        limit: 1,
      );

      if (instanceRows.isNotEmpty) {
        final instance = OpenVkInstance.fromMap(instanceRows.first);
        client.updateSession(
          newBaseUrl: instance.baseUrl,
          newAccessToken: account.accessToken,
          newInstanceId: instance.baseUrl,
        );
      } else {
        client.accessToken = account.accessToken;
      }

      client.messengerStore.currentUserId = account.userId;
      unawaited(client.longPollService.checkAndStart());

      return account;
    } catch (e) {
      debugPrint('[AuthHandler] Ошибка восстановления сессии: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _db.update('accounts', {'is_active': 0});
      client.clearToken();
    } catch (e) {
      debugPrint('[AuthHandler] Ошибка при выходе: $e');
    }
  }

  Future<List<OpenVkInstance>> getInstances() async {
    try {
      final rows = await _db.query('instances', orderBy: 'id ASC');
      return rows.map((r) => OpenVkInstance.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<OpenVkInstance> addInstance({
    required String name,
    required String url,
  }) async {
    final normalized = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
    final id = await _db.insert('instances', {
      'name': name,
      'base_url': normalized,
      'is_active': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return OpenVkInstance(
      id: id,
      name: name,
      baseUrl: normalized,
      isActive: false,
    );
  }

  Future<void> selectInstance(int id) async {
    await _db.update(
      'instances',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.update(
      'instances',
      {'is_active': 0},
      where: 'id != ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteInstance(int id) async {
    await _db.delete('instances', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> _saveOrUpdateInstance(String url) async {
    final existing = await _db.query(
      'instances',
      where: 'base_url = ?',
      whereArgs: [url],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = JsonSafe.toInt(existing.first['id']);
      await _db.update(
        'instances',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _db.update(
        'instances',
        {'is_active': 0},
        where: 'id != ?',
        whereArgs: [id],
      );
      return id;
    }

    final host = Uri.parse(url).host;
    final name = host.isNotEmpty ? host : 'OpenVK';

    await _db.update('instances', {'is_active': 0});
    return await _db.insert('instances', {
      'name': name,
      'base_url': url,
      'is_active': 1,
    });
  }

  Future<SavedAccount> _saveAccount({
    required int instanceId,
    required int userId,
    required String name,
    required String avatarUrl,
    required String accessToken,
  }) async {
    await _db.update('accounts', {'is_active': 0});

    final existing = await _db.query(
      'accounts',
      where: 'instance_id = ? AND user_id = ?',
      whereArgs: [instanceId, userId],
      limit: 1,
    );

    int id;
    if (existing.isNotEmpty) {
      id = JsonSafe.toInt(existing.first['id']);
      await _db.update(
        'accounts',
        {
          'name': name,
          'avatar_url': avatarUrl,
          'access_token': accessToken,
          'is_active': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      id = await _db.insert('accounts', {
        'instance_id': instanceId,
        'user_id': userId,
        'name': name,
        'avatar_url': avatarUrl,
        'access_token': accessToken,
        'is_active': 1,
      });
    }

    return SavedAccount(
      id: id,
      instanceId: instanceId,
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      accessToken: accessToken,
      isActive: true,
    );
  }
}
