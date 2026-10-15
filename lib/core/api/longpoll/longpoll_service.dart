import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../store/messenger_store.dart';
import '../../utils/json_safe.dart';
import '../openvk_client.dart';

class LongPollNotificationEvent {
  final int peerId;
  final int messageId;
  final int fromId;
  final String title;
  final String text;
  final int timestamp;
  final bool isOut;

  const LongPollNotificationEvent({
    required this.peerId,
    required this.messageId,
    required this.fromId,
    required this.title,
    required this.text,
    required this.timestamp,
    required this.isOut,
  });
}

class LongPollService {
  final OpenVkClient client;
  final MessengerStore store;
  final http.Client _httpClient;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _server;
  String? _key;
  int? _ts;
  int? _pts;

  final StreamController<LongPollNotificationEvent> _notificationsController =
      StreamController<LongPollNotificationEvent>.broadcast();

  Stream<LongPollNotificationEvent> get notifications =>
      _notificationsController.stream;

  LongPollService({
    required this.client,
    required this.store,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Starts LongPoll if there are active chats in runtime store or cached in database.
  /// If neither is present, it stays idle until the first chats are loaded.
  Future<void> checkAndStart() async {
    if (_isRunning) return;
    if (client.accessToken == null || client.accessToken!.isEmpty) return;

    final hasRuntimeChats = store.hasAnyConversations;
    final hasCache = hasRuntimeChats ||
        await client.cacheService.hasAnyCachedMessagesOrConversations(client.instanceId);
    if (hasCache) {
      start();
    } else {
      debugPrint('[LongPollService] Кэш пуст — LongPoll ожидает первого запроса сообщений');
    }
  }

  void start() {
    if (_isRunning) return;
    if (client.accessToken == null || client.accessToken!.isEmpty) return;

    _isRunning = true;
    debugPrint('[LongPollService] Запуск сервиса LongPoll в фоне');
    _runLoop();
  }

  void stop() {
    if (!_isRunning) return;
    debugPrint('[LongPollService] Остановка сервиса LongPoll');
    _isRunning = false;
  }

  Future<bool> _fetchServerData() async {
    try {
      final res = await client.call<Map<String, dynamic>>(
        'messages.getLongPollServer',
        params: {
          'v': '5.86',
          'need_pts': 1,
          'lp_version': 3,
        },
        parser: (json) => JsonSafe.toMap(json),
      );

      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull!;
        _server = JsonSafe.toStr(data['server']);
        _key = JsonSafe.toStr(data['key']);
        _ts = JsonSafe.toInt(data['ts']);
        _pts = JsonSafe.toInt(data['pts']);
        return _server != null && _server!.isNotEmpty && _key != null && _key!.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('[LongPollService] Ошибка getLongPollServer: $e');
      return false;
    }
  }

  Future<void> _runLoop() async {
    while (_isRunning) {
      if (_server == null || _key == null || _ts == null) {
        final ok = await _fetchServerData();
        if (!ok || !_isRunning) {
          await Future.delayed(const Duration(seconds: 4));
          continue;
        }
      }

      final normalizedServer = _server!.startsWith('http')
          ? _server!
          : 'https://$_server';

      final uri = Uri.parse(
        '$normalizedServer?act=a_check&key=$_key&ts=$_ts&wait=25&mode=2&version=3',
      );

      try {
        final response = await _httpClient
            .get(uri)
            .timeout(const Duration(seconds: 35));

        if (!_isRunning) break;

        final bodyStr = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(bodyStr);
        if (decoded is! Map) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final map = Map<String, dynamic>.from(decoded);

        if (map.containsKey('failed')) {
          final failedCode = JsonSafe.toInt(map['failed']);
          debugPrint('[LongPollService] LongPoll failed code: $failedCode');
          if (failedCode == 1) {
            _ts = JsonSafe.toInt(map['ts'], _ts ?? 0);
          } else if (failedCode == 2 || failedCode == 3) {
            _server = null;
            _key = null;
          }
          continue;
        }

        if (map.containsKey('ts')) {
          _ts = JsonSafe.toInt(map['ts'], _ts ?? 0);
        }

        if (map.containsKey('pts')) {
          _pts = JsonSafe.toInt(map['pts'], _pts ?? 0);
        }

        final updates = map['updates'];
        if (updates is List) {
          if (updates.isNotEmpty) {
            debugPrint('[LongPollService] Получено событий: ${updates.length} (ts: ${map['ts']})');
          }
          _processUpdates(updates);
        }
      } on TimeoutException {
        // Normal LongPoll timeout when no events occurred during wait=25
        continue;
      } on SocketException catch (e) {
        debugPrint('[LongPollService] Ошибка сети LongPoll: $e');
        if (_isRunning) {
          await Future.delayed(const Duration(seconds: 3));
        }
      } catch (e) {
        debugPrint('[LongPollService] Непредвиденная ошибка в цикле LongPoll: $e');
        if (_isRunning) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }
  }

  void _processUpdates(List updates) {
    for (final rawUpdate in updates) {
      if (rawUpdate is! List || rawUpdate.isEmpty) continue;
      final code = JsonSafe.toInt(rawUpdate[0]);

      debugPrint('[LongPollService] Raw Update [$code]: $rawUpdate');

      switch (code) {
        case 4:
          // [4, $message_id, $flags, $peer_id, $timestamp, $text, $extra_fields, $attachments, $random_id, $conversation_message_id]
          if (rawUpdate.length > 5) {
            final messageId = JsonSafe.toInt(rawUpdate[1]);
            final flags = JsonSafe.toInt(rawUpdate[2]);
            final peerId = JsonSafe.toInt(rawUpdate[3]);
            final timestamp = JsonSafe.toInt(rawUpdate[4]);

            String text = '';
            Map<String, dynamic>? extraFields;
            Map<String, dynamic>? attachments;
            int? randomId;
            int? convMsgId;

            // Check if LP server sends v1/v2 format (where index 5 is subject and index 6 is text String)
            // or v3 format (where index 5 is text and index 6 is extra_fields Map)
            if (rawUpdate.length > 6 && rawUpdate[6] is String) {
              final subject = JsonSafe.toStr(rawUpdate[5]);
              final body = JsonSafe.toStr(rawUpdate[6]);
              text = body.isNotEmpty && body != ' ... ' && body != '...' ? body : subject;
              if (rawUpdate.length > 7 && rawUpdate[7] is Map) {
                attachments = JsonSafe.toMap(rawUpdate[7]);
              }
              if (rawUpdate.length > 8) {
                randomId = JsonSafe.toInt(rawUpdate[8]);
              }
              if (rawUpdate.length > 9) {
                convMsgId = JsonSafe.toInt(rawUpdate[9]);
              }
            } else {
              text = JsonSafe.toStr(rawUpdate[5]);
              if (rawUpdate.length > 6 && rawUpdate[6] is Map) {
                extraFields = JsonSafe.toMap(rawUpdate[6]);
              }
              if (rawUpdate.length > 7 && rawUpdate[7] is Map) {
                attachments = JsonSafe.toMap(rawUpdate[7]);
              }
              if (rawUpdate.length > 8) {
                randomId = JsonSafe.toInt(rawUpdate[8]);
              }
              if (rawUpdate.length > 9) {
                convMsgId = JsonSafe.toInt(rawUpdate[9]);
              }
            }

            // Fallback: If text is '...' or empty, check if extraFields has message/text
            if ((text.trim() == '...' || text.trim() == '... ' || text.isEmpty) && extraFields != null) {
              if (extraFields.containsKey('message') && extraFields['message'] != null) {
                text = extraFields['message'].toString();
              } else if (extraFields.containsKey('text') && extraFields['text'] != null) {
                text = extraFields['text'].toString();
              }
            }

            if (convMsgId == null || convMsgId == 0) {
              convMsgId = JsonSafe.toInt(
                attachments?['conversation_message_id'] ??
                    attachments?['cmid'] ??
                    extraFields?['conversation_message_id'] ??
                    extraFields?['cmid'],
              );
            }

            final isOut = (flags & 2) != 0;
            final isUnread = (flags & 1) != 0;

            debugPrint('[LongPollService] Новое сообщение (#$messageId):');
            debugPrint('                  peer_id: $peerId, flags: $flags (out=$isOut, unread=$isUnread)');
            debugPrint('                  text: "$text" (длина: ${text.length})');
            debugPrint('                  extra: $extraFields');
            debugPrint('                  attachments: $attachments');

            store.onNewMessage(
              messageId: messageId,
              flags: flags,
              peerId: peerId,
              timestamp: timestamp,
              text: text,
              attachments: attachments,
              randomId: randomId,
              conversationMessageId: convMsgId,
              extraFields: extraFields,
            );

            if (!isOut) {
              final conv = store.getConversationNotifier(peerId)?.value;
              final title = conv != null ? store.getTitle(conv) : 'Новое сообщение';
              final fromId = (extraFields != null && extraFields.containsKey('from'))
                  ? JsonSafe.toInt(extraFields['from'])
                  : (attachments != null && attachments.containsKey('from')
                      ? JsonSafe.toInt(attachments['from'])
                      : peerId);

              _notificationsController.add(
                LongPollNotificationEvent(
                  peerId: peerId,
                  messageId: messageId,
                  fromId: fromId,
                  title: title,
                  text: text.isNotEmpty ? text : '[Вложение]',
                  timestamp: timestamp,
                  isOut: false,
                ),
              );
            }
          }
          break;

        case 2:
          // [2, $message_id, $mask, $peer_id]
          if (rawUpdate.length > 3) {
            final messageId = JsonSafe.toInt(rawUpdate[1]);
            final mask = JsonSafe.toInt(rawUpdate[2]);
            final peerId = JsonSafe.toInt(rawUpdate[3]);
            debugPrint('[LongPollService] Событие 2 (Установка флагов): msgId=$messageId, mask=$mask, peerId=$peerId');
            store.onMessageFlagsUpdated(messageId, mask, peerId, true);
          }
          break;

        case 3:
          // [3, $message_id, $mask, $peer_id]
          if (rawUpdate.length > 3) {
            final messageId = JsonSafe.toInt(rawUpdate[1]);
            final mask = JsonSafe.toInt(rawUpdate[2]);
            final peerId = JsonSafe.toInt(rawUpdate[3]);
            debugPrint('[LongPollService] Событие 3 (Сброс флагов): msgId=$messageId, mask=$mask, peerId=$peerId');
            store.onMessageFlagsUpdated(messageId, mask, peerId, false);
          }
          break;

        case 5:
          // [5, $message_id, $mask, $peer_id, $timestamp, $new_text, $attachments]
          if (rawUpdate.length > 5) {
            final messageId = JsonSafe.toInt(rawUpdate[1]);
            final peerId = JsonSafe.toInt(rawUpdate[3]);
            final newText = JsonSafe.toStr(rawUpdate[5]);
            debugPrint('[LongPollService] Событие 5 (Редактирование): msgId=$messageId, peerId=$peerId, newText="$newText"');
            store.onEditMessage(messageId, peerId, newText);
          }
          break;

        case 6:
          // [6, $peer_id, $local_id]
          if (rawUpdate.length > 2) {
            final peerId = JsonSafe.toInt(rawUpdate[1]);
            final localId = JsonSafe.toInt(rawUpdate[2]);
            debugPrint('[LongPollService] Событие 6 (Прочтение входящих): peerId=$peerId, localId=$localId');
            store.onReadIncoming(peerId, localId);
          }
          break;

        case 7:
          // [7, $peer_id, $local_id]
          if (rawUpdate.length > 2) {
            final peerId = JsonSafe.toInt(rawUpdate[1]);
            final localId = JsonSafe.toInt(rawUpdate[2]);
            debugPrint('[LongPollService] Событие 7 (Прочтение исходящих): peerId=$peerId, localId=$localId');
            store.onReadOutgoing(peerId, localId);
          }
          break;

        case 80:
          // [80, $count]
          if (rawUpdate.length > 1) {
            final count = JsonSafe.toInt(rawUpdate[1]);
            debugPrint('[LongPollService] Событие 80 (Непрочитанные): count=$count');
            store.setTotalUnreadCount(count);
          }
          break;

        case 61:
          // [61, $user_id, $flags]
          if (rawUpdate.length > 1) {
            final userId = JsonSafe.toInt(rawUpdate[1]);
            debugPrint('[LongPollService] Событие 61 (Печатание в диалоге): userId=$userId');
            store.onUserTyping(
              peerId: userId,
              userIds: [userId],
              totalCount: 1,
            );
          }
          break;

        case 62:
          // [62, $user_id, $chat_id]
          if (rawUpdate.length > 2) {
            final userId = JsonSafe.toInt(rawUpdate[1]);
            final chatId = JsonSafe.toInt(rawUpdate[2]);
            final peerId = 2000000000 + chatId;
            debugPrint('[LongPollService] Событие 62 (Печатание в беседе): userId=$userId, chatId=$chatId, peerId=$peerId');
            store.onUserTyping(
              peerId: peerId,
              userIds: [userId],
              totalCount: 1,
            );
          }
          break;

        case 63:
          // [63, $peer_id, $user_ids, $total_count, $ts]
          if (rawUpdate.length > 2) {
            final peerId = JsonSafe.toInt(rawUpdate[1]);
            final rawUserIds = rawUpdate[2];
            final List<int> userIds = [];
            if (rawUserIds is List) {
              for (final item in rawUserIds) {
                final id = JsonSafe.toInt(item);
                if (id != 0) userIds.add(id);
              }
            } else {
              final id = JsonSafe.toInt(rawUserIds);
              if (id != 0) userIds.add(id);
            }
            final totalCount = rawUpdate.length > 3
                ? JsonSafe.toInt(rawUpdate[3])
                : userIds.length;
            debugPrint(
                '[LongPollService] Событие 63 (Печатание в чате): peerId=$peerId, userIds=$userIds, totalCount=$totalCount');
            store.onUserTyping(
              peerId: peerId,
              userIds: userIds,
              totalCount: totalCount,
            );
          }
          break;

        case 64:
          // [64, $peer_id, $user_ids, $total_count, $ts]
          if (rawUpdate.length > 2) {
            final peerId = JsonSafe.toInt(rawUpdate[1]);
            final rawUserIds = rawUpdate[2];
            final List<int> userIds = [];
            if (rawUserIds is List) {
              for (final item in rawUserIds) {
                final id = JsonSafe.toInt(item);
                if (id != 0) userIds.add(id);
              }
            } else {
              final id = JsonSafe.toInt(rawUserIds);
              if (id != 0) userIds.add(id);
            }
            final totalCount = rawUpdate.length > 3
                ? JsonSafe.toInt(rawUpdate[3])
                : userIds.length;
            debugPrint(
                '[LongPollService] Событие 64 (Запись аудио/печатание): peerId=$peerId, userIds=$userIds, totalCount=$totalCount');
            store.onUserTyping(
              peerId: peerId,
              userIds: userIds,
              totalCount: totalCount,
            );
          }
          break;

        default:
          debugPrint('[LongPollService] Событие $code: $rawUpdate');
          break;
      }
    }
  }

  void dispose() {
    stop();
    _notificationsController.close();
  }
}
