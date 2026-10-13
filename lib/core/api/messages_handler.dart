import 'dart:math';

import '../cache/cache_policy.dart';
import '../models/conversations_response.dart';
import '../models/history_response.dart';
import '../utils/json_safe.dart';
import 'api_response.dart';
import 'openvk_client.dart';

class MessagesHandler {
  final OpenVkClient _client;

  MessagesHandler(this._client);

  Future<ApiResponse<ConversationsResponse>> getConversations({
    int offset = 0,
    int count = 30,
    String filter = 'all',
    bool extended = true,
    CachePolicy cachePolicy = CachePolicy.networkFirst,
  }) async {
    return _client.callCached<ConversationsResponse>(
      'messages.getConversations',
      params: {
        'offset': offset,
        'count': count,
        'filter': filter,
        'extended': extended ? 1 : 0,
        'fields': 'photo_50,photo_100,online',
      },
      cachePolicy: cachePolicy,
      cacheTag: 'messages_conversations',
      cacheKey: 'conversations_offset_${offset}_count_$count',
      parser: (json) => ConversationsResponse.fromJson(JsonSafe.toMap(json)),
      fallback: () => ConversationsResponse.empty(),
    );
  }

  Future<ApiResponse<HistoryResponse>> getHistory({
    required int peerId,
    int offset = 0,
    int count = 40,
    int? startMessageId,
    bool extended = true,
    CachePolicy cachePolicy = CachePolicy.networkFirst,
  }) async {
    final params = <String, dynamic>{
      'peer_id': peerId,
      'offset': offset,
      'count': count,
      'extended': extended ? 1 : 0,
      'fields': 'photo_50,photo_100,online',
      if (startMessageId != null) 'start_message_id': startMessageId,
    };

    return _client.callCached<HistoryResponse>(
      'messages.getHistory',
      params: params,
      cachePolicy: cachePolicy,
      cacheTag: 'history_$peerId',
      cacheKey: 'history_${peerId}_offset_$offset',
      parser: (json) => HistoryResponse.fromJson(JsonSafe.toMap(json)),
      fallback: () => HistoryResponse.empty(),
    );
  }

  Future<ApiResponse<int>> send({
    required int peerId,
    required String message,
    int? replyTo,
    String? attachment,
  }) async {
    final randomId = Random().nextInt(2147483647);

    final params = <String, dynamic>{
      'peer_id': peerId,
      'random_id': randomId,
      'message': message,
      if (replyTo != null) 'reply_to': replyTo,
      if (attachment != null && attachment.isNotEmpty) 'attachment': attachment,
    };

    final result = await _client.call<int>(
      'messages.send',
      httpMethod: HttpMethod.post,
      params: params,
      parser: (json) {
        if (json is int) return json;
        if (json is num) return json.toInt();
        if (json is Map)
          return JsonSafe.toInt(json['message_id'] ?? json['id']);
        return JsonSafe.toInt(json);
      },
    );

    if (result.isSuccess && _client.cacheService != null) {
      await _client.cacheService!.invalidateByTag(
        tag: 'history_$peerId',
        instanceId: _client.instanceId,
      );
      await _client.cacheService!.invalidateByTag(
        tag: 'messages_conversations',
        instanceId: _client.instanceId,
      );
    }

    return result;
  }

  Future<ApiResponse<bool>> markAsRead({
    required int peerId,
    int? startMessageId,
  }) async {
    final params = <String, dynamic>{
      'peer_id': peerId,
      if (startMessageId != null) 'start_message_id': startMessageId,
    };

    return _client.call<bool>(
      'messages.markAsRead',
      httpMethod: HttpMethod.post,
      params: params,
      parser: (json) => JsonSafe.toBool(json, true),
      fallback: () => false,
    );
  }

  Future<ApiResponse<bool>> deleteConversation({required int peerId}) async {
    return _client.call<bool>(
      'messages.deleteConversation',
      httpMethod: HttpMethod.post,
      params: {'peer_id': peerId},
      parser: (json) => JsonSafe.toBool(json, true),
      fallback: () => false,
    );
  }
}
