import 'dart:async';

import '../cache/cache_policy.dart';
import '../models/user.dart';
import '../models/wall_response.dart';
import '../utils/json_safe.dart';
import 'api_response.dart';
import 'openvk_client.dart';

class WallHandler {
  final OpenVkClient _client;

  WallHandler(this._client);

  /// Fetch user or community detailed profile info including counters and personal fields.
  Future<ApiResponse<User>> getProfile(int userId, {bool forceRefresh = false}) async {
    if (userId < 0) {
      final absId = userId.abs();
      final res = await _client.callCached<User>(
        'groups.getById',
        cacheKey: 'group_profile_$absId',
        cacheTag: 'group_profile_$absId',
        cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
        cacheTtl: const Duration(days: 1),
        params: {
          'group_ids': absId.toString(),
          'fields':
              'description,members_count,status,can_post,is_member,is_admin,counters,'
              'photo_50,photo_100,photo_200,site,city,country,activity,type,is_closed,'
              'registration_date,created_at,start_date',
        },
        parser: (json) {
          if (json is List && json.isNotEmpty) {
            return User.fromJson(JsonSafe.toMap(json.first));
          }
          if (json is Map && json['items'] is List && (json['items'] as List).isNotEmpty) {
            return User.fromJson(JsonSafe.toMap((json['items'] as List).first));
          }
          if (json is Map) {
            return User.fromJson(JsonSafe.toMap(json));
          }
          return User.empty(userId);
        },
        fallback: () => User.empty(userId),
      );

      if (res.isSuccess && res.dataOrNull != null) {
        _client.userCache.putUsers([res.dataOrNull!]);
      }

      return res;
    }

    const fields =
        'photo_50,photo_100,photo_max,online,status,counters,sex,bdate,city,country,'
        'home_town,about,activities,books,games,interests,movies,music,tv,quotes,'
        'screen_name,nickname,relation,relation_partner,personal,site,connections,'
        'registration_date,created_at,reg_date,friend_status';

    final res = await _client.callCached<User>(
      'users.get',
      cacheKey: 'profile_$userId',
      cacheTag: 'profile_$userId',
      cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
      cacheTtl: const Duration(days: 1),
      params: {
        'user_ids': userId,
        'fields': fields,
      },
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return User.fromJson(JsonSafe.toMap(json.first));
        }
        if (json is Map && json['items'] is List && (json['items'] as List).isNotEmpty) {
          return User.fromJson(JsonSafe.toMap((json['items'] as List).first));
        }
        return User.empty(userId);
      },
      fallback: () => User.empty(userId),
    );

    if (res.isSuccess && res.dataOrNull != null) {
      _client.userCache.putUsers([res.dataOrNull!]);
    }

    return res;
  }

  /// Fetch posts on a wall.
  /// [filter]: 'all' (Все записи), 'owner' (Мои записи), 'others' (Записи других).
  Future<ApiResponse<WallResponse>> getWall({
    required int ownerId,
    int offset = 0,
    int count = 20,
    String filter = 'all',
    bool forceRefresh = false,
  }) async {
    final isFirstPage = offset == 0;
    final res = isFirstPage
        ? await _client.callCached<WallResponse>(
            'wall.get',
            cacheKey: 'wall_${ownerId}_$filter',
            cacheTag: 'wall_$ownerId',
            cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
            cacheTtl: const Duration(hours: 1),
            params: {
              'owner_id': ownerId,
              'offset': offset,
              'count': count,
              'filter': filter,
              'extended': 1,
              'fields': 'photo_50,photo_100,online',
            },
            parser: (json) => WallResponse.fromJson(JsonSafe.toMap(json)),
            fallback: () => WallResponse.empty(),
          )
        : await _client.call<WallResponse>(
            'wall.get',
            params: {
              'owner_id': ownerId,
              'offset': offset,
              'count': count,
              'filter': filter,
              'extended': 1,
              'fields': 'photo_50,photo_100,online',
            },
            parser: (json) => WallResponse.fromJson(JsonSafe.toMap(json)),
            fallback: () => WallResponse.empty(),
          );

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      if (data.profiles.isNotEmpty) {
        _client.userCache.putUsers(data.profiles);
      }
      if (data.groups.isNotEmpty) {
        _client.userCache.putGroups(data.groups);
      }
    }

    return res;
  }

  /// Create a new post on the wall.
  Future<ApiResponse<int>> postToWall({
    required int ownerId,
    required String message,
    List<String>? attachments,
  }) async {
    final params = <String, dynamic>{
      'owner_id': ownerId,
      'message': message,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.join(','),
    };

    final res = await _client.call<int>(
      'wall.post',
      httpMethod: HttpMethod.post,
      params: params,
      parser: (json) {
        if (json is Map && json.containsKey('post_id')) {
          return JsonSafe.toInt(json['post_id']);
        }
        return JsonSafe.toInt(json);
      },
      fallback: () => 0,
    );

    if (res.isSuccess) {
      unawaited(_client.cacheService.invalidate(
        key: 'wall_${ownerId}_all',
        instanceId: _client.instanceId,
      ));
      unawaited(_client.cacheService.invalidate(
        key: 'wall_${ownerId}_owner',
        instanceId: _client.instanceId,
      ));
    }

    return res;
  }

  /// Delete a post from the wall.
  Future<ApiResponse<bool>> deletePost({
    required int ownerId,
    required int postId,
  }) async {
    final res = await _client.call<bool>(
      'wall.delete',
      httpMethod: HttpMethod.post,
      params: {
        'owner_id': ownerId,
        'post_id': postId,
      },
      parser: (json) => json == 1 || json == true || (json is Map && json['response'] == 1),
      fallback: () => false,
    );

    if (res.isSuccess) {
      unawaited(_client.cacheService.invalidate(
        key: 'wall_${ownerId}_all',
        instanceId: _client.instanceId,
      ));
      unawaited(_client.cacheService.invalidate(
        key: 'wall_${ownerId}_owner',
        instanceId: _client.instanceId,
      ));
      unawaited(_client.cacheService.invalidate(
        key: 'wall_${ownerId}_others',
        instanceId: _client.instanceId,
      ));
    }

    return res;
  }

  /// Toggle like on a wall post.
  Future<ApiResponse<int>> toggleLike({
    required int ownerId,
    required int postId,
    required bool isCurrentlyLiked,
  }) async {
    final method = isCurrentlyLiked ? 'likes.delete' : 'likes.add';
    return _client.call<int>(
      method,
      httpMethod: HttpMethod.post,
      params: {
        'type': 'post',
        'owner_id': ownerId,
        'item_id': postId,
      },
      parser: (json) {
        if (json is Map && json.containsKey('likes')) {
          return JsonSafe.toInt(json['likes']);
        }
        return 0;
      },
      fallback: () => 0,
    );
  }
}
