import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/cache/user_cache.dart';
import 'package:openvk_aqua/core/models/conversation.dart';
import 'package:openvk_aqua/core/models/message.dart';
import 'package:openvk_aqua/core/models/message_viewers_response.dart';
import 'package:openvk_aqua/core/models/user.dart';
import 'package:openvk_aqua/core/store/messenger_store.dart';
import 'package:openvk_aqua/ui/views/messages/chat_conversation_view.dart';
import 'package:openvk_aqua/ui/widgets/retro_message_viewers_dialog.dart';

void main() {
  group('Message Viewers & Multi-user Typing & Actions', () {
    test('MessageViewersResponse parses openvk getMessageViewers JSON sample correctly', () {
      const jsonSample = '''
{
    "response": {
        "count": 7,
        "items": [
            {
                "user_id": 162,
                "last_read_id": 20013
            },
            {
                "user_id": 7810,
                "last_read_id": 20013
            },
            {
                "user_id": 32109,
                "last_read_id": 20013
            },
            {
                "user_id": 34919,
                "last_read_id": 20013
            },
            {
                "user_id": 37299,
                "last_read_id": 20013
            },
            {
                "user_id": 42214,
                "last_read_id": 20013
            },
            {
                "user_id": 3284,
                "last_read_id": 20012
            }
        ],
        "user_ids": [
            162,
            7810,
            32109,
            34919,
            37299,
            42214,
            3284
        ],
        "profiles": [
            {
                "id": 162,
                "first_name": "Влад",
                "last_name": "Фамильный",
                "is_closed": 0,
                "can_access_closed": 1,
                "photo_50": "https://cdn.openvk.org/miniscule.gif",
                "online": 0,
                "online_mobile": 1,
                "last_seen": {
                    "platform": 4,
                    "time": 1792151436
                },
                "sex": 0
            },
            {
                "id": 7810,
                "first_name": "Даник",
                "last_name": "",
                "is_closed": 0,
                "can_access_closed": 0,
                "photo_50": "https://cdn.openvk.org/miniscule.gif",
                "online": 1,
                "online_mobile": 1,
                "last_seen": {
                    "platform": 1,
                    "time": 1792153592
                },
                "sex": 2
            }
        ]
    }
}
''';

      final Map<String, dynamic> decoded = jsonDecode(jsonSample) as Map<String, dynamic>;
      final response = MessageViewersResponse.fromJson(decoded['response'] as Map<String, dynamic>);

      expect(response.count, 7);
      expect(response.items.length, 7);
      expect(response.items[0].userId, 162);
      expect(response.items[0].lastReadId, 20013);
      expect(response.userIds, [162, 7810, 32109, 34919, 37299, 42214, 3284]);
      expect(response.profiles.length, 2);
      expect(response.profiles[0].id, 162);
      expect(response.profiles[0].firstName, 'Влад');
      expect(response.profiles[1].id, 7810);
      expect(response.profiles[1].firstName, 'Даник');
      expect(response.profiles[1].isOnline, true);
    });

    testWidgets('MessengerStore handles multi-user typing with independent 5-second timers and pluralization', (tester) async {
      final userCache = UserCache();
      final store = MessengerStore(userCache: userCache);
      final peerId = 2000000001;

      // Seed cached users
      userCache.putUsers([
        const User(id: 101, firstName: 'Алиса', lastName: 'Селезнева', photo50: '', photo100: '', isOnline: false),
        const User(id: 102, firstName: 'Боб', lastName: 'Марли', photo50: '', photo100: '', isOnline: false),
        const User(id: 103, firstName: 'Чарли', lastName: 'Чаплин', photo50: '', photo100: '', isOnline: false),
        const User(id: 104, firstName: 'Дима', lastName: 'Билан', photo50: '', photo100: '', isOnline: false),
      ]);

      final typingNotifier = store.getTypingNotifier(peerId);
      expect(typingNotifier.value, isNull);

      // 1 user typing
      store.onUserTyping(peerId: peerId, userIds: [101]);
      expect(typingNotifier.value, 'Алиса печатает...');

      // 2 users typing after 1 second
      await tester.pump(const Duration(seconds: 1));
      store.onUserTyping(peerId: peerId, userIds: [102]);
      expect(typingNotifier.value, 'Алиса и Боб печатают...');

      // 3 users typing after another 1 second
      await tester.pump(const Duration(seconds: 1));
      store.onUserTyping(peerId: peerId, userIds: [103]);
      expect(typingNotifier.value, 'Алиса, Боб и Чарли печатают...');

      // 4 users typing
      store.onUserTyping(peerId: peerId, userIds: [104]);
      expect(typingNotifier.value, 'Алиса, Боб и ещё 2 печатают...');

      // Wait 3.5 seconds: User 101 was triggered at 0s, so at 5s user 101 expires.
      // Total elapsed from 0s: 1s + 1s + 3.5s = 5.5s.
      // User 101 should expire, but 102 (triggered at 1s, expires at 6s), 103 (at 2s), 104 (at 2s) are still active!
      await tester.pump(const Duration(milliseconds: 3500));

      expect(typingNotifier.value, 'Боб, Чарли и Дима печатают...');

      // Advance past remaining expiration (3 more seconds)
      await tester.pump(const Duration(seconds: 3));
      expect(typingNotifier.value, isNull);

      store.clear();
    });

    testWidgets('Swipe message left triggers reply and opens iOS 6 reply bar', (tester) async {
      final userCache = UserCache();
      final client = OpenVkClient(baseUrl: 'https://test.openvk.su', userCache: userCache);
      final store = client.messengerStore;
      final peerId = 2000000001;

      final msg = const Message(
        id: 1001,
        date: 1700000000,
        peerId: 2000000001,
        fromId: 77,
        text: 'Привет от ретро чата!',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1700000000,
      );

      userCache.putUsers([
        const User(id: 77, firstName: 'Василий', lastName: 'Теркин', photo50: '', photo100: '', isOnline: false),
      ]);
      store.putMessage(msg);
      store.getChatMessageOrderNotifier(peerId).value = [1001];

      final conv = ConversationItem(
        peerId: peerId,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: msg,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationView(
            client: client,
            account: const SavedAccount(
              id: 1,
              instanceId: 1,
              userId: 999,
              name: 'User',
              avatarUrl: '',
              accessToken: 'tok',
              isActive: true,
            ),
            conversation: conv,
            title: 'Тестовый чат',
            currentUserId: 999,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the message
      final msgFinder = find.textContaining('Привет от ретро чата!', findRichText: true);
      expect(msgFinder, findsOneWidget);

      // Reply banner should not exist initially
      expect(find.text('Ответ для Василий Теркин'), findsNothing);

      // Swipe message to the left to trigger reply gesture
      await tester.drag(msgFinder, const Offset(-80, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      // Reply banner should now be visible above the input bar!
      expect(find.text('Ответ для: '), findsOneWidget);
      expect(find.text('Василий Теркин'), findsNWidgets(2));
      expect(find.textContaining('Привет от ретро чата!', findRichText: true), findsNWidgets(2)); // in message and in reply banner

      // Close reply banner by tapping close button
      final closeReplyBtn = find.byIcon(Icons.close_rounded);
      expect(closeReplyBtn, findsOneWidget);
      await tester.tap(closeReplyBtn);
      await tester.pumpAndSettle();

      // Reply banner is removed
      expect(find.text('Ответ для: '), findsNothing);
      expect(find.text('Василий Теркин'), findsOneWidget);
    });

    testWidgets('Long press opens iOS 6 message action dialog with message options', (tester) async {
      final userCache = UserCache();
      final client = OpenVkClient(baseUrl: 'https://test.openvk.su', userCache: userCache);
      final store = client.messengerStore;
      final peerId = 2000000001;

      final msg = const Message(
        id: 2001,
        date: 1700000000,
        peerId: 2000000001,
        fromId: 999,
        text: 'Сообщение для контекстного меню',
        isOut: true,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 2,
        updateTime: 1700000000,
      );

      userCache.putUsers([
        const User(id: 99, firstName: 'Елена', lastName: 'Прекрасная', photo50: '', photo100: '', isOnline: false),
      ]);
      store.putMessage(msg);
      store.getChatMessageOrderNotifier(peerId).value = [2001];

      final conv = ConversationItem(
        peerId: peerId,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: msg,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationView(
            client: client,
            account: const SavedAccount(
              id: 1,
              instanceId: 1,
              userId: 999,
              name: 'User',
              avatarUrl: '',
              accessToken: 'tok',
              isActive: true,
            ),
            conversation: conv,
            title: 'Чат',
            currentUserId: 999,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Long press on the message bubble
      final msgFinder = find.textContaining('Сообщение для контекстного меню', findRichText: true);
      await tester.longPress(msgFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      // Modal action sheet should appear with 'Кто посмотрел' because it's own message
      expect(find.text('Действие с сообщением'), findsOneWidget);
      expect(find.text('Ответить'), findsOneWidget);
      expect(find.text('Скопировать текст'), findsOneWidget);
      expect(find.text('Кто посмотрел'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      // Tap 'Отмена'
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Действие с сообщением'), findsNothing);
    });

    testWidgets('Long press on someone else message in chat does NOT show "Кто посмотрел"', (tester) async {
      final userCache = UserCache();
      final client = OpenVkClient(baseUrl: 'https://test.openvk.su', userCache: userCache);
      final store = client.messengerStore;
      final peerId = 2000000001;

      final msg = const Message(
        id: 2002,
        date: 1700000000,
        peerId: 2000000001,
        fromId: 99,
        text: 'Чужое сообщение в чате',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 3,
        updateTime: 1700000000,
      );

      store.putMessage(msg);
      store.getChatMessageOrderNotifier(peerId).value = [2002];

      final conv = ConversationItem(
        peerId: peerId,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: msg,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationView(
            client: client,
            account: const SavedAccount(
              id: 1,
              instanceId: 1,
              userId: 999,
              name: 'User',
              avatarUrl: '',
              accessToken: 'tok',
              isActive: true,
            ),
            conversation: conv,
            title: 'Чат',
            currentUserId: 999,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final msgFinder = find.textContaining('Чужое сообщение в чате', findRichText: true);
      await tester.longPress(msgFinder);
      await tester.pumpAndSettle();

      expect(find.text('Действие с сообщением'), findsOneWidget);
      expect(find.text('Ответить'), findsOneWidget);
      expect(find.text('Скопировать текст'), findsOneWidget);
      // 'Кто посмотрел' must NOT be available for someone else's message
      expect(find.text('Кто посмотрел'), findsNothing);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
    });

    testWidgets('showMessageViewersDialog displays message viewers modal in iOS 6 style', (tester) async {
      final userCache = UserCache();
      final client = OpenVkClient(baseUrl: 'https://test.openvk.su', userCache: userCache);

      const msg = Message(
        id: 460406,
        date: 1700000000,
        peerId: 2000055261,
        fromId: 100,
        text: 'Тест',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 20009,
        updateTime: 1700000000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showMessageViewersDialog(
                      context: ctx,
                      client: client,
                      peerId: 2000055261,
                      message: msg,
                      onUserTap: (_) {},
                    );
                  },
                  child: const Text('Показать просмотры'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open viewers dialog
      await tester.tap(find.text('Показать просмотры'));
      await tester.pump();

      // Check dialog opened with title and close button
      expect(find.text('Кто посмотрел'), findsOneWidget);
      expect(find.text('Закрыть'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();

      expect(find.text('Закрыть'), findsNothing);
    });
  });
}
