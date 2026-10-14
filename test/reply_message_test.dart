import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/cache/user_cache.dart';
import 'package:openvk_flutter/core/models/conversation.dart';
import 'package:openvk_flutter/core/models/history_response.dart';
import 'package:openvk_flutter/core/models/message.dart';
import 'package:openvk_flutter/core/models/user.dart';
import 'package:openvk_flutter/core/store/messenger_store.dart';
import 'package:openvk_flutter/ui/views/messages/chat_conversation_view.dart';

void main() {
  group('Reply Message and getById Store integration', () {
    test('Message.fromJson parses reply_to and reply_message correctly', () {
      final msgWithReplyTo = Message.fromJson({
        'id': 101,
        'date': 1700000000,
        'peer_id': 123,
        'from_id': 456,
        'text': 'Reply text',
        'out': 0,
        'reply_to': 446694,
      });

      expect(msgWithReplyTo.replyMessageId, 446694);
      expect(msgWithReplyTo.replyMessage, isNull);

      final msgWithReplyMap = Message.fromJson({
        'id': 102,
        'date': 1700000010,
        'peer_id': 123,
        'from_id': 456,
        'text': 'Another reply',
        'out': 0,
        'reply_message': {
          'id': 446694,
          'date': 1699999000,
          'peer_id': 123,
          'from_id': 789,
          'text': 'Original quoted message',
          'out': 0,
        },
      });

      expect(msgWithReplyMap.replyMessageId, 446694);
      expect(msgWithReplyMap.replyMessage, isNotNull);
      expect(msgWithReplyMap.replyMessage!.text, 'Original quoted message');
      expect(msgWithReplyMap.replyMessage!.fromId, 789);
    });

    test('LongPoll attachments reply parsing and automated getById batch resolution', () async {
      final requestedIds = <int>[];
      final store = MessengerStore(
        userCache: UserCache(),
        fetchMessagesHandler: (ids) async {
          requestedIds.addAll(ids);
          return [
            const Message(
              id: 446694,
              date: 1699999000,
              peerId: 1000,
              fromId: 9827,
              text: 'Сообщение на которое ответили',
              isOut: false,
              isImportant: false,
              isUnread: false,
              attachments: [],
              fwdMessages: [],
              conversationMessageId: 1,
              updateTime: 1699999000,
            ),
          ];
        },
      );

      // LongPoll event 4 payload with reply in attachments
      store.onNewMessage(
        messageId: 500,
        flags: 0,
        peerId: 1000,
        timestamp: 1700000020,
        text: 'Тест ответа',
        attachments: {
          'from': 9827,
          'muted': 1,
          'reply': 446694,
          'reply_to': 446694,
        },
      );

      final msgBeforeFetch = store.getMessage(500);
      expect(msgBeforeFetch, isNotNull);
      expect(msgBeforeFetch!.replyMessageId, 446694);
      expect(msgBeforeFetch.replyMessage, isNull);

      // Allow the 30ms batch debounce timer to trigger and resolve
      for (int i = 0; i < 25; i++) {
        await Future.delayed(const Duration(milliseconds: 20));
        if (store.getMessage(500)?.replyMessage != null) break;
      }

      expect(requestedIds, contains(446694));

      final msgAfterFetch = store.getMessage(500);
      expect(msgAfterFetch, isNotNull);
      expect(msgAfterFetch!.replyMessage, isNotNull);
      expect(msgAfterFetch.replyMessage!.id, 446694);
      expect(msgAfterFetch.replyMessage!.text, 'Сообщение на которое ответили');
    });

    test('setHistory with merge: true preserves and sorts messages descending by timestamp', () {
      final store = MessengerStore(userCache: UserCache());

      final initialSlice = HistoryResponse(
        count: 100,
        items: [
          const Message(
            id: 200,
            date: 1700000200,
            peerId: 100,
            fromId: 1,
            text: 'Latest message in chat',
            isOut: true,
            isImportant: false,
            attachments: [],
            fwdMessages: [],
            conversationMessageId: 20,
            updateTime: 1700000200,
          ),
          const Message(
            id: 199,
            date: 1700000199,
            peerId: 100,
            fromId: 2,
            text: 'Second message',
            isOut: false,
            isImportant: false,
            attachments: [],
            fwdMessages: [],
            conversationMessageId: 19,
            updateTime: 1700000199,
          ),
        ],
        profiles: {},
        groups: {},
      );

      store.setHistory(100, initialSlice);

      final orderNotifier = store.getChatMessageOrderNotifier(100);
      expect(orderNotifier.value, [200, 199]);

      // Jump to message 50 and load history around it with offset -20
      final jumpedSlice = HistoryResponse(
        count: 100,
        items: [
          const Message(
            id: 52,
            date: 1700000052,
            peerId: 100,
            fromId: 1,
            text: 'Jumped newer',
            isOut: true,
            isImportant: false,
            attachments: [],
            fwdMessages: [],
            conversationMessageId: 5,
            updateTime: 1700000052,
          ),
          const Message(
            id: 50,
            date: 1700000050,
            peerId: 100,
            fromId: 2,
            text: 'Target jumped message',
            isOut: false,
            isImportant: false,
            attachments: [],
            fwdMessages: [],
            conversationMessageId: 4,
            updateTime: 1700000050,
          ),
          const Message(
            id: 48,
            date: 1700000048,
            peerId: 100,
            fromId: 2,
            text: 'Jumped older',
            isOut: false,
            isImportant: false,
            attachments: [],
            fwdMessages: [],
            conversationMessageId: 3,
            updateTime: 1700000048,
          ),
        ],
        profiles: {},
        groups: {},
      );

      store.setHistory(100, jumpedSlice, merge: true);

      // Verify all items are merged and strictly descending by timestamp
      expect(orderNotifier.value, [200, 199, 52, 50, 48]);
    });
  });

  group('Reply Quote UI in ChatConversationView', () {
    testWidgets('renders reply quote with author name and preview snippet', (tester) async {
      final userCache = UserCache();
      userCache.putUser(const User(
        id: 777,
        firstName: 'Иван',
        lastName: 'Иванов',
        photo50: '',
        photo100: '',
        isOnline: true,
      ));

      final client = OpenVkClient(baseUrl: 'https://test.openvk.su', userCache: userCache);
      final store = client.messengerStore;

      final replyMsg = const Message(
        id: 446694,
        date: 1700000000,
        peerId: 100,
        fromId: 777,
        text: 'Привет, это цитируемое сообщение!',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1700000000,
      );

      final mainMsg = Message(
        id: 446695,
        date: 1700000010,
        peerId: 100,
        fromId: 888,
        text: 'А это ответ на твоё сообщение',
        isOut: false,
        isImportant: false,
        attachments: const [],
        fwdMessages: const [],
        replyMessage: replyMsg,
        replyMessageId: 446694,
        conversationMessageId: 2,
        updateTime: 1700000010,
      );

      store.putMessage(replyMsg);
      store.putMessage(mainMsg);

      final orderNotifier = store.getChatMessageOrderNotifier(100);
      orderNotifier.value = [446695, 446694];

      final conv = ConversationItem(
        peerId: 100,
        peerType: 'user',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: mainMsg,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationView(
            client: client,
            conversation: conv,
            title: 'Тестовый чат',
            currentUserId: 999,
          ),
        ),
      );

      await tester.pump();

      // Find the reply quote author name and preview text
      // The text appears twice: once in the quote snippet, once in the original message bubble
      expect(find.text('Привет, это цитируемое сообщение!'), findsNWidgets(2));
      expect(find.text('А это ответ на твоё сообщение'), findsOneWidget);

      // Verify reply quote is clickable
      await tester.tap(find.text('Иван Иванов'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    });
  });
}
