import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../cache/cache_policy.dart';
import '../cache/cache_service.dart';
import '../cache/user_cache.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../store/messenger_store.dart';
import '../utils/json_safe.dart';
import 'api_response.dart';
import 'longpoll/longpoll_service.dart';

enum HttpMethod { get, post }

class OpenVkClient {
  final http.Client _httpClient;

  String baseUrl;

  String instanceId;

  String? accessToken;

  String apiVersion;

  Duration timeout;

  bool enableLogging;

  CacheService cacheService;

  late final UserCache userCache;
  late final MessengerStore messengerStore;
  late final LongPollService longPollService;

  OpenVkClient({
    this.baseUrl = 'https://api.openvk.org',
    String? instanceId,
    this.accessToken,
    this.apiVersion = '5.131',
    this.timeout = const Duration(seconds: 15),
    this.enableLogging = kDebugMode,
    CacheService? cacheService,
    http.Client? httpClient,
    UserCache? userCache,
  }) : instanceId = instanceId ?? _deriveInstanceId(baseUrl),
       cacheService = cacheService ?? CacheService(),
       _httpClient = httpClient ?? http.Client() {
    this.userCache = userCache ??
        UserCache(
          fetchUsersHandler: fetchUsers,
          fetchGroupsHandler: fetchGroups,
        );
    messengerStore = MessengerStore(userCache: this.userCache);
    longPollService = LongPollService(
      client: this,
      store: messengerStore,
    );
  }

  static String _deriveInstanceId(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      return uri.host.isNotEmpty ? uri.host : 'default_instance';
    } catch (_) {
      return 'default_instance';
    }
  }

  void updateSession({
    String? newBaseUrl,
    String? newAccessToken,
    String? newInstanceId,
  }) {
    if (newBaseUrl != null) {
      baseUrl = _normalizeBaseUrl(newBaseUrl);
      instanceId = newInstanceId ?? _deriveInstanceId(baseUrl);
    } else if (newInstanceId != null) {
      instanceId = newInstanceId;
    }
    if (newAccessToken != null) accessToken = newAccessToken;
  }

  void clearToken() {
    accessToken = null;
    longPollService.stop();
    messengerStore.clear();
    userCache.clear();
  }

  /// Fetches basic user info from API (users.get) for UserCache or callers.
  Future<List<User>> fetchUsers(List<int> userIds) async {
    if (userIds.isEmpty) return const [];
    try {
      final res = await call<List<User>>(
        'users.get',
        params: {
          'user_ids': userIds.join(','),
          'fields': 'photo_50,photo_100,online',
        },
        parser: (json) {
          if (json is List) {
            return json
                .map((item) => User.fromJson(JsonSafe.toMap(item)))
                .toList();
          }
          return const [];
        },
        fallback: () => const [],
      );
      return res.dataOrNull ?? const [];
    } catch (e) {
      debugPrint('[OpenVkClient] fetchUsers error: $e');
      return const [];
    }
  }

  /// Fetches community info from API (groups.getById) for UserCache or callers.
  Future<List<Group>> fetchGroups(List<int> groupIds) async {
    if (groupIds.isEmpty) return const [];
    try {
      final res = await call<List<Group>>(
        'groups.getById',
        params: {
          'group_ids': groupIds.map((id) => id.abs()).join(','),
          'fields': 'photo_50,photo_100',
        },
        parser: (json) {
          if (json is List) {
            return json
                .map((item) => Group.fromJson(JsonSafe.toMap(item)))
                .toList();
          }
          if (json is Map && json['items'] is List) {
            return (json['items'] as List)
                .map((item) => Group.fromJson(JsonSafe.toMap(item)))
                .toList();
          }
          return const [];
        },
        fallback: () => const [],
      );
      return res.dataOrNull ?? const [];
    } catch (e) {
      debugPrint('[OpenVkClient] fetchGroups error: $e');
      return const [];
    }
  }

  Future<ApiResponse<T>> call<T>(
    String method, {
    HttpMethod httpMethod = HttpMethod.get,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    required T Function(dynamic responseJson) parser,
    T Function()? fallback,
  }) async {
    final cleanMethod = method.startsWith('/') ? method.substring(1) : method;
    final path = cleanMethod.startsWith('method/')
        ? cleanMethod
        : 'method/$cleanMethod';

    final queryParams = <String, String>{
      'v': apiVersion,
      if (accessToken != null && accessToken!.isNotEmpty)
        'access_token': accessToken!,
    };

    if (params != null) {
      params.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });
    }

    final normalizedBase = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalizedBase/$path');

    if (enableLogging) {
      _logRequest(httpMethod, uri, queryParams);
    }

    try {
      http.Response response;

      final requestHeaders = {'Accept': 'application/json', ...?headers};

      if (httpMethod == HttpMethod.get) {
        final finalUri = uri.replace(
          queryParameters: {...uri.queryParameters, ...queryParams},
        );
        response = await _httpClient
            .get(finalUri, headers: requestHeaders)
            .timeout(timeout);
      } else {
        response = await _httpClient
            .post(uri, headers: requestHeaders, body: queryParams)
            .timeout(timeout);
      }

      return _processResponse<T>(
        response: response,
        parser: parser,
        fallback: fallback,
      );
    } on TimeoutException {
      return ApiFailure(
        const ApiError(
          kind: ApiErrorKind.timeout,
          message: 'Время ожидания ответа сервера истекло',
        ),
        fallbackData: fallback?.call(),
      );
    } on SocketException catch (e) {
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.network,
          message: 'Нет соединения с сервером',
          technicalDetails: e.message,
        ),
        fallbackData: fallback?.call(),
      );
    } on http.ClientException catch (e) {
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.network,
          message: 'Ошибка сети при передаче данных',
          technicalDetails: e.message,
        ),
        fallbackData: fallback?.call(),
      );
    } catch (e, stack) {
      if (enableLogging) {
        debugPrint('[OpenVkClient] Непредвиденная ошибка: $e\n$stack');
      }
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.unknown,
          message: 'Произошла непредвиденная ошибка',
          technicalDetails: e.toString(),
        ),
        fallbackData: fallback?.call(),
      );
    }
  }

  Future<ApiResponse<T>> callCached<T>(
    String method, {
    HttpMethod httpMethod = HttpMethod.get,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    required T Function(dynamic responseJson) parser,
    T Function()? fallback,
    CachePolicy cachePolicy = CachePolicy.networkFirst,
    String? cacheKey,
    String? cacheTag,
    Duration cacheTtl = const Duration(minutes: 30),
  }) async {
    final effectiveCacheService = cacheService;

    if (cachePolicy == CachePolicy.networkOnly) {
      return call<T>(
        method,
        httpMethod: httpMethod,
        params: params,
        headers: headers,
        parser: parser,
        fallback: fallback,
      );
    }

    final effectiveKey = cacheKey ?? _generateCacheKey(method, params);

    if (cachePolicy == CachePolicy.cacheFirst) {
      final cachedJson = await effectiveCacheService.get(
        key: effectiveKey,
        instanceId: instanceId,
        ignoreTtl: false,
      );

      if (cachedJson != null) {
        try {
          final data = parser(cachedJson);
          return ApiSuccess<T>(
            data,
            rawJson: cachedJson is Map<String, dynamic> ? cachedJson : null,
            isFromCache: true,
          );
        } catch (e) {
          debugPrint('[OpenVkClient] Ошибка парсинга кэша: $e');
        }
      }
    }

    final netResponse = await call<T>(
      method,
      httpMethod: httpMethod,
      params: params,
      headers: headers,
      parser: parser,
      fallback: null,
    );

    if (netResponse.isSuccess) {
      final rawResponse = netResponse as ApiSuccess<T>;
      final payloadToCache =
          rawResponse.rawJson?['response'] ?? rawResponse.rawJson;
      if (payloadToCache != null) {
        await effectiveCacheService.put(
          key: effectiveKey,
          data: payloadToCache,
          instanceId: instanceId,
          ttl: cacheTtl,
          tag: cacheTag,
        );
      }
      return netResponse;
    }

    if (cachePolicy == CachePolicy.networkFirst) {
      final cachedJson = await effectiveCacheService.get(
        key: effectiveKey,
        instanceId: instanceId,
        ignoreTtl: true,
      );

      if (cachedJson != null) {
        try {
          final data = parser(cachedJson);
          return ApiSuccess<T>(
            data,
            rawJson: cachedJson is Map<String, dynamic> ? cachedJson : null,
            isFromCache: true,
          );
        } catch (e) {
          debugPrint('[OpenVkClient] Ошибка парсинга резервного кэша: $e');
        }
      }
    }

    final failure = netResponse as ApiFailure<T>;
    return ApiFailure<T>(failure.error, fallbackData: fallback?.call());
  }

  String _generateCacheKey(String method, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return method;
    final sortedKeys = params.keys.toList()..sort();
    final paramStr = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    return '$method?$paramStr';
  }

  ApiResponse<T> _processResponse<T>({
    required http.Response response,
    required T Function(dynamic responseJson) parser,
    T Function()? fallback,
  }) {
    final body = response.body.trim();

    if (body.startsWith('<') ||
        body.toLowerCase().contains('<!doctype html>')) {
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.server,
          message:
              'Сервер вернул HTML вместо JSON (возможно, ошибка PHP или шлюза)',
          code: response.statusCode,
          technicalDetails: _truncate(body, 200),
        ),
        fallbackData: fallback?.call(),
      );
    }

    if (response.statusCode >= 500) {
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.server,
          message: 'Сервер временно недоступен (код ${response.statusCode})',
          code: response.statusCode,
          technicalDetails: _truncate(body, 200),
        ),
        fallbackData: fallback?.call(),
      );
    }

    dynamic decodedJson;
    try {
      decodedJson = jsonDecode(body);
    } catch (e) {
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.parse,
          message: 'Не удалось разобрать ответ сервера',
          code: response.statusCode,
          technicalDetails: e.toString(),
        ),
        fallbackData: fallback?.call(),
      );
    }

    if (decodedJson is! Map) {
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.parse,
          message: 'Формат ответа сервера не является JSON-объектом',
          code: response.statusCode,
        ),
        fallbackData: fallback?.call(),
      );
    }

    final map = Map<String, dynamic>.from(decodedJson);

    if (map.containsKey('error')) {
      final errorMap = JsonSafe.toMap(map['error']);
      final errorCode = JsonSafe.toInt(errorMap['error_code']);
      final errorMsg = JsonSafe.toStr(
        errorMap['error_msg'] ?? errorMap['error_text'],
        'Неизвестная ошибка API',
      );

      final kind = switch (errorCode) {
        5 => ApiErrorKind.unauthorized,
        14 => ApiErrorKind.captchaNeeded,
        15 || 200 || 201 => ApiErrorKind.forbidden,
        _ => ApiErrorKind.apiError,
      };

      return ApiFailure(
        ApiError(
          kind: kind,
          message: errorMsg,
          code: errorCode,
          captchaSid: JsonSafe.toNullableStr(errorMap['captcha_sid']),
          captchaImg: JsonSafe.toNullableStr(errorMap['captcha_img']),
          technicalDetails: errorMap.toString(),
        ),
        fallbackData: fallback?.call(),
      );
    }

    final dynamic payload = map.containsKey('response') ? map['response'] : map;

    try {
      final parsedData = parser(payload);
      return ApiSuccess(parsedData, rawJson: map);
    } catch (e, stack) {
      if (enableLogging) {
        debugPrint('[OpenVkClient] Ошибка в парсере данных: $e\n$stack');
      }
      return ApiFailure(
        ApiError(
          kind: ApiErrorKind.parse,
          message: 'Ошибка при обработке данных модели',
          technicalDetails: e.toString(),
        ),
        fallbackData: fallback?.call(),
      );
    }
  }

  String _normalizeBaseUrl(String url) {
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    return clean;
  }

  void _logRequest(HttpMethod method, Uri uri, Map<String, String> params) {
    final masked = Map<String, String>.from(params);
    if (masked.containsKey('access_token')) masked['access_token'] = '***';
    if (masked.containsKey('password')) masked['password'] = '***';
    debugPrint(
      '[OpenVK API] ${method.name.toUpperCase()} ${uri.path} params: $masked',
    );
  }

  String _truncate(String str, int maxLength) {
    if (str.length <= maxLength) return str;
    return '${str.substring(0, maxLength)}...';
  }
}
