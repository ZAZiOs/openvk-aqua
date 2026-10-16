import '../cache/cache_policy.dart';
import '../models/newsfeed_response.dart';
import '../utils/json_safe.dart';
import 'api_response.dart';
import 'openvk_client.dart';

class NewsfeedHandler {
  final OpenVkClient _client;

  NewsfeedHandler(this._client);

  /// Fetch newsfeed for current user via [newsfeed.get]
  Future<ApiResponse<NewsfeedResponse>> getNewsfeed({
    int count = 25,
    int offset = 0,
    String? startFrom,
    bool forceRefresh = false,
  }) async {
    final isFirstPage = offset == 0 && (startFrom == null || startFrom.isEmpty);
    final params = <String, dynamic>{
      'filters': 'post',
      'count': count,
      'extended': 1,
      'fields': 'photo_50,photo_100,online',
      if (offset > 0) 'offset': offset,
      if (startFrom != null && startFrom.isNotEmpty) 'start_from': startFrom,
    };

    final res = isFirstPage
        ? await _client.callCached<NewsfeedResponse>(
            'newsfeed.get',
            cacheKey: 'newsfeed_my',
            cacheTag: 'newsfeed',
            cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
            cacheTtl: const Duration(hours: 1),
            params: params,
            parser: (json) => NewsfeedResponse.fromJson(JsonSafe.toMap(json)),
            fallback: () => NewsfeedResponse.empty(),
          )
        : await _client.call<NewsfeedResponse>(
            'newsfeed.get',
            params: params,
            parser: (json) => NewsfeedResponse.fromJson(JsonSafe.toMap(json)),
            fallback: () => NewsfeedResponse.empty(),
          );

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      if (data.profiles.isNotEmpty) {
        _client.userCache.putUsers(data.profiles);
      }
      if (data.groups.isNotEmpty) {
        _client.userCache.putGroups(data.groups);
      }

      if (!isFirstPage && res is ApiSuccess<NewsfeedResponse>) {
        final rawResponse = res.rawJson;
        final payload = rawResponse?['response'] is Map
            ? Map<String, dynamic>.from(rawResponse!['response'] as Map)
            : (rawResponse != null
                ? Map<String, dynamic>.from(rawResponse)
                : null);
        if (payload != null && payload.isNotEmpty) {
          try {
            await _client.cacheService.appendNewsfeedSegment(
              key: 'newsfeed_my',
              newSegment: payload,
              instanceId: _client.instanceId,
              ttl: const Duration(hours: 1),
              tag: 'newsfeed',
            );
          } catch (e) {
            // Non-fatal cache write failure
          }
        }
      }
    }

    return res;
  }

  /// Fetch global public newsfeed via [newsfeed.getGlobal]
  Future<ApiResponse<NewsfeedResponse>> getGlobalNewsfeed({
    int count = 25,
    int offset = 0,
    String? startFrom,
    bool forceRefresh = false,
  }) async {
    final isFirstPage = offset == 0 && (startFrom == null || startFrom.isEmpty);
    final params = <String, dynamic>{
      'filters': 'post',
      'count': count,
      'extended': 1,
      'fields': 'photo_50,photo_100,online',
      if (offset > 0) 'offset': offset,
      if (startFrom != null && startFrom.isNotEmpty) 'start_from': startFrom,
    };

    final res = isFirstPage
        ? await _client.callCached<NewsfeedResponse>(
            'newsfeed.getGlobal',
            cacheKey: 'newsfeed_global',
            cacheTag: 'newsfeed',
            cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
            cacheTtl: const Duration(hours: 1),
            params: params,
            parser: (json) => NewsfeedResponse.fromJson(JsonSafe.toMap(json)),
            fallback: () => NewsfeedResponse.empty(),
          )
        : await _client.call<NewsfeedResponse>(
            'newsfeed.getGlobal',
            params: params,
            parser: (json) => NewsfeedResponse.fromJson(JsonSafe.toMap(json)),
            fallback: () => NewsfeedResponse.empty(),
          );

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      if (data.profiles.isNotEmpty) {
        _client.userCache.putUsers(data.profiles);
      }
      if (data.groups.isNotEmpty) {
        _client.userCache.putGroups(data.groups);
      }

      if (!isFirstPage && res is ApiSuccess<NewsfeedResponse>) {
        final rawResponse = res.rawJson;
        final payload = rawResponse?['response'] is Map
            ? Map<String, dynamic>.from(rawResponse!['response'] as Map)
            : (rawResponse != null
                ? Map<String, dynamic>.from(rawResponse)
                : null);
        if (payload != null && payload.isNotEmpty) {
          try {
            await _client.cacheService.appendNewsfeedSegment(
              key: 'newsfeed_global',
              newSegment: payload,
              instanceId: _client.instanceId,
              ttl: const Duration(hours: 1),
              tag: 'newsfeed',
            );
          } catch (e) {
            // Non-fatal cache write failure
          }
        }
      }
    }

    return res;
  }
}
