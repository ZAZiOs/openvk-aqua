import 'dart:async';

import '../models/user.dart';
import '../models/wall_response.dart';
import '../utils/json_safe.dart';
import 'api_response.dart';
import 'openvk_client.dart';

class WallHandler {
  final OpenVkClient _client;

  WallHandler(this._client);

  /// Fetch user detailed profile info including counters and personal fields.
  Future<ApiResponse<User>> getProfile(int userId) async {
    const fields =
        'photo_50,photo_100,photo_max,online,status,counters,sex,bdate,city,country,'
        'home_town,about,activities,books,games,interests,movies,music,tv,quotes,'
        'screen_name,nickname,relation,relation_partner,personal,site,connections,'
        'registration_date,created_at,reg_date';

    final res = await _client.call<User>(
      'users.get',
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
  }) async {
    final res = await _client.call<WallResponse>(
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

    return _client.call<int>(
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
  }

  /// Delete a post from the wall.
  Future<ApiResponse<bool>> deletePost({
    required int ownerId,
    required int postId,
  }) async {
    return _client.call<bool>(
      'wall.delete',
      httpMethod: HttpMethod.post,
      params: {
        'owner_id': ownerId,
        'post_id': postId,
      },
      parser: (json) => json == 1 || json == true || (json is Map && json['response'] == 1),
      fallback: () => false,
    );
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
