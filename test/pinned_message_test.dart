import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/models/conversation.dart';
import 'package:openvk_aqua/core/models/message.dart';
import 'package:openvk_aqua/ui/views/messages/chat_conversation_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const testAccount = SavedAccount(
    id: 1,
    instanceId: 1,
    userId: 100,
    name: 'Тест Пользователь',
    avatarUrl: '',
    accessToken: 'test_token',
    isActive: true,
  );

  group('Pinned message model and store tests', () {
    test('ConversationItem.fromJson parses pinned_message from chat_settings', () {
      final json = {
        'conversation': {
          'peer': {'id': 2000000001, 'type': 'chat'},
          'in_read': 10,
          'out_read': 10,
          'unread_count': 0,
          'important': false,
          'unanswered': false,
          'chat_settings': {
            'title': 'Тестовый чат',
            'members_count': 5,
            'pinned_message': {
              'id': 777,
              'date': 1700000000,
              'peer_id': 2000000001,
              'from_id': 101,
              'text': 'Важное закреплённое сообщение!',
              'out': 0,
              'important': false,
              'conversation_message_id': 50,
            },
          },
        },
        'last_message': {
          'id': 888,
          'date': 1700000100,
          'peer_id': 2000000001,
          'from_id': 100,
          'text': 'Последнее сообщение',
          'out': 1,
          'important': false,
          'conversation_message_id': 51,
        },
      };

      final conv = ConversationItem.fromJson(json);
      expect(conv.activePinnedMessage, isNotNull);
      expect(conv.activePinnedMessage!.id, 777);
      expect(conv.activePinnedMessage!.text, 'Важное закреплённое сообщение!');
    });

    test('ConversationItem.fromJson parses pinned_message directly in conversation', () {
      final json = {
        'conversation': {
          'peer': {'id': 2000000002, 'type': 'chat'},
          'in_read': 5,
          'out_read': 5,
          'unread_count': 0,
          'important': false,
          'unanswered': false,
          'pinned_message': {
            'id': 999,
            'date': 1700000000,
            'peer_id': 2000000002,
            'from_id': 102,
            'text': 'Прямой пин',
            'out': 0,
            'important': false,
            'conversation_message_id': 10,
          },
        },
        'last_message': {
          'id': 1000,
          'date': 1700000100,
          'peer_id': 2000000002,
          'from_id': 100,
          'text': 'Последнее',
          'out': 1,
          'important': false,
          'conversation_message_id': 11,
        },
      };

      final conv = ConversationItem.fromJson(json);
      expect(conv.activePinnedMessage, isNotNull);
      expect(conv.activePinnedMessage!.id, 999);
      expect(conv.activePinnedMessage!.text, 'Прямой пин');
    });

    test('MessengerStore unpinMessage removes pinned message from active notifier', () {
      final client = OpenVkClient();
      final store = client.messengerStore;

      const pinned = Message(
        id: 555,
        date: 1700000000,
        peerId: 2000000003,
        fromId: 100,
        text: 'Закреп',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 0,
      );

      const conv = ConversationItem(
        peerId: 2000000003,
        peerType: 'chat',
        inRead: 1,
        outRead: 1,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        pinnedMessage: pinned,
        lastMessage: Message(
          id: 556,
          date: 1700000010,
          peerId: 2000000003,
          fromId: 100,
          text: 'Свежее',
          isOut: false,
          isImportant: false,
          attachments: [],
          fwdMessages: [],
          conversationMessageId: 2,
          updateTime: 0,
        ),
      );

      final notifier = store.getOrCreateConversationNotifier(conv);
      expect(notifier.value.activePinnedMessage, isNotNull);

      store.unpinMessage(2000000003);
      expect(notifier.value.activePinnedMessage, isNull);
    });
  });

  group('ChatConversationView pinned bar & iOS 6 confirm dialog tests', () {
    testWidgets('Header close button is removed and pinned banner is shown', (tester) async {
      final client = OpenVkClient();
      const pinned = Message(
        id: 1234,
        date: 1700000000,
        peerId: 2000000004,
        fromId: 100,
        text: 'Пин-сообщение в шапке',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 5,
        updateTime: 0,
      );

      const conv = ConversationItem(
        peerId: 2000000004,
        peerType: 'chat',
        inRead: 1,
        outRead: 1,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        pinnedMessage: pinned,
        lastMessage: Message(
          id: 1235,
          date: 1700000010,
          peerId: 2000000004,
          fromId: 100,
          text: 'Привет',
          isOut: false,
          isImportant: false,
          attachments: [],
          fwdMessages: [],
          conversationMessageId: 6,
          updateTime: 0,
        ),
      );

      client.messengerStore.getOrCreateConversationNotifier(conv);

      bool closeChatCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: testAccount,
              conversation: conv,
              title: 'Тестовый Чат',
              currentUserId: 100,
              isEmbedded: true,
              onClose: () => closeChatCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify the close chat button is removed
      expect(find.byTooltip('Закрыть чат'), findsNothing);
      expect(closeChatCalled, isFalse);

      // Verify pinned message bar is shown
      expect(find.text('Закреплённое сообщение'), findsOneWidget);
      expect(find.text('Пин-сообщение в шапке'), findsOneWidget);
      expect(find.byTooltip('Открепить сообщение'), findsOneWidget);

      // Tap unpin icon to trigger iOS 6 confirm dialog
      await tester.tap(find.byTooltip('Открепить сообщение'));
      await tester.pumpAndSettle();

      // Verify iOS 6 dialog appears
      expect(find.text('Открепить сообщение'), findsWidgets); // Title and bar
      expect(find.text('Вы действительно хотите открепить это сообщение?'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Открепить'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // Dialog closed and pinned message is still there
      expect(find.text('Вы действительно хотите открепить это сообщение?'), findsNothing);
      expect(find.text('Пин-сообщение в шапке'), findsOneWidget);
    });
  });
}
