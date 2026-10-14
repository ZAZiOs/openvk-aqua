import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvk_flutter/core/api/longpoll/longpoll_service.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/cache/cache_service.dart';
import 'package:openvk_flutter/core/db/app_database.dart';
import 'package:openvk_flutter/core/models/conversation.dart';
import 'package:openvk_flutter/core/models/conversations_response.dart';
import 'package:openvk_flutter/core/models/history_response.dart';
import 'package:openvk_flutter/core/models/message.dart';
import 'package:openvk_flutter/core/store/messenger_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MessengerStore', () {
    late MessengerStore store;

    setUp(() {
      store = MessengerStore();
      store.currentUserId = 100;
    });

    test('populates conversations and order correctly', () {
      final response = ConversationsResponse(
        count: 2,
        unreadCount: 1,
        items: [
          ConversationItem(
            peerId: 1,
            peerType: 'user',
            inRead: 5,
            outRead: 5,
            unreadCount: 0,
            isImportant: false,
            isUnanswered: false,
            lastMessage: const Message(
              id: 5,
              date: 1000,
              peerId: 1,
              fromId: 1,
              text: 'Сообщение 1',
              isOut: false,
              isImportant: false,
              attachments: [],
              fwdMessages: [],
              conversationMessageId: 1,
              updateTime: 1000,
            ),
          ),
          ConversationItem(
            peerId: 2,
            peerType: 'user',
            inRead: 10,
            outRead: 10,
            unreadCount: 2,
            isImportant: false,
            isUnanswered: false,
            lastMessage: const Message(
              id: 12,
              date: 1100,
              peerId: 2,
              fromId: 2,
              text: 'Непрочитанное',
              isOut: false,
              isImportant: false,
              attachments: [],
              fwdMessages: [],
              conversationMessageId: 2,
              updateTime: 1100,
            ),
          ),
        ],
        profiles: {},
        groups: {},
      );

      store.setConversations(response);

      expect(store.conversationOrder.value, [1, 2]);
      expect(store.unreadConversationOrder.value, [2]);
      expect(store.totalUnreadCount.value, 1);

      final conv1 = store.getConversationNotifier(1);
      final conv2 = store.getConversationNotifier(2);
      expect(conv1, isNotNull);
      expect(conv2, isNotNull);
      expect(conv1!.value.lastMessage.text, 'Сообщение 1');
      expect(conv2!.value.unreadCount, 2);
    });

    test('granular updates: onNewMessage notifies ONLY the affected conversation and moves it to top', () {
      final conv1 = ConversationItem(
        peerId: 1,
        peerType: 'user',
        inRead: 5,
        outRead: 5,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message.empty(),
      );
      final conv2 = ConversationItem(
        peerId: 2,
        peerType: 'user',
        inRead: 10,
        outRead: 10,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message.empty(),
      );

      store.setConversations(
        ConversationsResponse(
          count: 2,
          unreadCount: 0,
          items: [conv1, conv2],
          profiles: {},
          groups: {},
        ),
      );

      expect(store.conversationOrder.value, [1, 2]);

      int conv1Notifications = 0;
      int conv2Notifications = 0;
      store.getConversationNotifier(1)!.addListener(() => conv1Notifications++);
      store.getConversationNotifier(2)!.addListener(() => conv2Notifications++);

      // New incoming message for peer 2 (flags: 1 = unread)
      store.onNewMessage(
        messageId: 25,
        flags: 1,
        peerId: 2,
        timestamp: 1600000000,
        text: 'Привет от собеседника!',
      );

      // conv2 must notify, conv1 must NOT notify!
      expect(conv2Notifications, 1);
      expect(conv1Notifications, 0);

      // conv2 must now be at index 0 of conversationOrder!
      expect(store.conversationOrder.value, [2, 1]);
      expect(store.unreadConversationOrder.value, [2]);

      // conv2 last message updated
      expect(store.getConversationNotifier(2)!.value.lastMessage.text, 'Привет от собеседника!');
      expect(store.getConversationNotifier(2)!.value.unreadCount, 1);
    });

    test('onReadIncoming marks unread messages as read', () {
      final msg1 = const Message(
        id: 10,
        date: 100,
        peerId: 5,
        fromId: 5,
        text: '1',
        isOut: false,
        isImportant: false,
        isUnread: true,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 100,
      );
      final msg2 = const Message(
        id: 15,
        date: 200,
        peerId: 5,
        fromId: 5,
        text: '2',
        isOut: false,
        isImportant: false,
        isUnread: true,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 2,
        updateTime: 200,
      );

      store.setHistory(
        5,
        HistoryResponse(
          count: 2,
          items: [msg2, msg1],
          profiles: {},
          groups: {},
        ),
      );

      expect(store.getMessage(10)?.isUnread, true);
      expect(store.getMessage(15)?.isUnread, true);

      store.onReadIncoming(5, 10);

      expect(store.getMessage(10)?.isUnread, false);
      expect(store.getMessage(15)?.isUnread, true);
    });
  });

  group('LongPollService Start Condition & Lifecycle', () {
    late AppDatabase db;
    late CacheService cacheService;
    late OpenVkClient client;
    late MessengerStore store;

    setUp(() async {
      db = AppDatabase.instance;
      await db.init(inMemory: true);
      cacheService = CacheService(dbManager: db);
      store = MessengerStore();
      client = OpenVkClient(
        baseUrl: 'https://openvk.su',
        cacheService: cacheService,
        accessToken: 'test_token',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('does NOT start LongPoll when cache has NO chats/messages', () async {
      final lpService = LongPollService(
        client: client,
        store: store,
      );

      expect(lpService.isRunning, false);
      await lpService.checkAndStart();
      expect(lpService.isRunning, false);
    });

    test('DOES start LongPoll when cache has cached conversations or messages', () async {
      // Put a conversation in cache
      await cacheService.put(
        key: 'conversations_all_offset_0_count_30',
        data: {'items': []},
        instanceId: client.instanceId,
        tag: 'messages_conversations',
      );

      final hasCache = await cacheService.hasAnyCachedMessagesOrConversations(client.instanceId);
      expect(hasCache, true);

      final lpService = LongPollService(
        client: client,
        store: store,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('getLongPollServer')) {
            return http.Response(
              jsonEncode({
                'response': {
                  'key': 'mock_key',
                  'server': 'lp.openvk.su',
                  'ts': 12345,
                }
              }),
              200,
            );
          }
          // Long poll check
          return http.Response(
            jsonEncode({
              'ts': 12346,
              'updates': [],
            }),
            200,
          );
        }),
      );

      expect(lpService.isRunning, false);
      await lpService.checkAndStart();
      expect(lpService.isRunning, true);

      lpService.stop();
      expect(lpService.isRunning, false);
    });

    test('processes event 4 (new message) and dispatches notification', () async {
      final notificationCompleter = Completer<LongPollNotificationEvent>();

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('getLongPollServer')) {
          return http.Response(
            jsonEncode({
              'response': {
                'key': 'mock_key',
                'server': 'lp.openvk.su',
                'ts': 100,
              }
            }),
            200,
          );
        }
        if (request.url.queryParameters['act'] == 'a_check') {
          final data = jsonEncode({
            'ts': 101,
            'updates': [
              [
                4,
                999, // message_id
                1, // flags: 1 = unread incoming
                42, // peer_id
                1600000000, // timestamp
                'Секретное сообщение', // text
                {'from': 42}, // extra
                {}, // attachments
                0,
                10,
              ],
            ],
          });
          return http.Response.bytes(
            utf8.encode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });

      final testClient = OpenVkClient(
        baseUrl: 'https://openvk.su',
        cacheService: cacheService,
        accessToken: 'valid_token',
        httpClient: mockClient,
      );

      final lpService = LongPollService(
        client: testClient,
        store: store,
        httpClient: mockClient,
      );

      lpService.notifications.listen((event) {
        if (!notificationCompleter.isCompleted) {
          notificationCompleter.complete(event);
        }
      });

      lpService.start();

      final event = await notificationCompleter.future.timeout(
        const Duration(seconds: 3),
      );

      expect(event.peerId, 42);
      expect(event.messageId, 999);
      expect(event.text, 'Секретное сообщение');
      expect(event.isOut, false);

      // Verify store was updated
      expect(store.conversationOrder.value.contains(42), true);
      expect(store.getMessage(999)?.text, 'Секретное сообщение');

      lpService.stop();
    });
  });
}
