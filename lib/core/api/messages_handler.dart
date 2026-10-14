import 'dart:async';
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
    final res = await _client.callCached<ConversationsResponse>(
      'messages.getConversations',
      params: {
        'v': '5.86',
        'offset': offset,
        'count': count,
        'filter': filter,
        'extended': extended ? 1 : 0,
        'fields': 'photo_50,photo_100,online',
      },
      cachePolicy: cachePolicy,
      cacheTag: 'messages_conversations',
      cacheKey: 'conversations_${filter}_offset_${offset}_count_$count',
      parser: (json) => ConversationsResponse.fromJson(JsonSafe.toMap(json)),
      fallback: () => ConversationsResponse.empty(),
    );

    if (res.isSuccess && res.dataOrNull != null) {
      _client.messengerStore.setConversations(
        res.dataOrNull!,
        append: offset > 0,
      );
      unawaited(_client.longPollService.checkAndStart());
    }

    return res;
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
      'v': '5.86',
      'peer_id': peerId,
      'offset': offset,
      'count': count,
      'extended': extended ? 1 : 0,
      'fields': 'photo_50,photo_100,online',
      'start_message_id': ?startMessageId,
    };

    final res = await _client.callCached<HistoryResponse>(
      'messages.getHistory',
      params: params,
      cachePolicy: cachePolicy,
      cacheTag: 'history_$peerId',
      cacheKey: 'history_${peerId}_offset_$offset',
      parser: (json) => HistoryResponse.fromJson(JsonSafe.toMap(json)),
      fallback: () => HistoryResponse.empty(),
    );

    if (res.isSuccess && res.dataOrNull != null) {
      _client.messengerStore.setHistory(
        peerId,
        res.dataOrNull!,
        append: offset > 0,
      );
      unawaited(_client.longPollService.checkAndStart());
    }

    return res;
  }

  Future<ApiResponse<Map<String, dynamic>>> getConversationMembers({
    required int peerId,
    String fields = 'photo_50,photo_100,online',
  }) async {
    return _client.call<Map<String, dynamic>>(
      'messages.getConversationMembers',
      params: {
        'v': '5.86',
        'peer_id': peerId,
        'fields': fields,
      },
      parser: (json) => JsonSafe.toMap(json),
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
      'v': '5.86',
      'peer_id': peerId,
      'random_id': randomId,
      'message': message,
      'reply_to': ?replyTo,
      if (attachment != null && attachment.isNotEmpty) 'attachment': attachment,
    };

    final result = await _client.call<int>(
      'messages.send',
      httpMethod: HttpMethod.post,
      params: params,
      parser: (json) {
        if (json is int) return json;
        if (json is num) return json.toInt();
        if (json is Map) {
          return JsonSafe.toInt(json['message_id'] ?? json['id']);
        }
        return JsonSafe.toInt(json);
      },
    );

    if (result.isSuccess) {
      final msgId = result.dataOrNull ?? 0;
      if (msgId > 0) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        _client.messengerStore.onNewMessage(
          messageId: msgId,
          flags: 2,
          peerId: peerId,
          timestamp: now,
          text: message,
          fromId: _client.messengerStore.currentUserId,
        );
      }

      await _client.cacheService.invalidateByTag(
        tag: 'history_$peerId',
        instanceId: _client.instanceId,
      );
      await _client.cacheService.invalidateByTag(
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
      'v': '5.86',
      'peer_id': peerId,
      'start_message_id': ?startMessageId,
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
      params: {
        'v': '5.86',
        'peer_id': peerId,
      },
      parser: (json) => JsonSafe.toBool(json, true),
      fallback: () => false,
    );
  }
}
