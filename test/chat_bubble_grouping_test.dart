import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/api/auth_handler.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/models/conversation.dart';
import 'package:openvk_flutter/core/models/history_response.dart';
import 'package:openvk_flutter/core/models/message.dart';
import 'package:openvk_flutter/core/models/user.dart';
import 'package:openvk_flutter/ui/views/messages/chat_conversation_view.dart';
import 'package:openvk_flutter/ui/views/messages/messages_view.dart';
import 'package:openvk_flutter/ui/widgets/retro_chat_avatar.dart';

const _testAccount = SavedAccount(
  id: 1,
  instanceId: 1,
  userId: 1,
  name: 'User',
  avatarUrl: '',
  accessToken: 'tok',
  isActive: true,
);

void main() {
  group('Chat Bubble Grouping Tests', () {
    testWidgets('Single message shows BOTH author name and avatar', (tester) async {
      final client = OpenVkClient();
      client.userCache.putUser(const User(
        id: 42,
        firstName: 'Даня',
        lastName: 'Вишня',
        photo50: '',
        photo100: '',
        isOnline: true,
      ));

      final singleMsg = const Message(
        id: 101,
        date: 1600000000,
        peerId: 2000000001,
        fromId: 42,
        text: 'Одиночное сообщение',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1600000000,
      );

      final conversation = ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: singleMsg,
      );

      client.messengerStore.getOrCreateConversationNotifier(conversation);
      final msgNotifier = client.messengerStore.getMessageNotifier(101);
      if (msgNotifier != null) {
        msgNotifier.value = singleMsg;
      } else {
        client.messengerStore.onNewMessage(
          messageId: 101,
          flags: 0,
          peerId: 2000000001,
          timestamp: 1600000000,
          text: 'Одиночное сообщение',
          fromId: 42,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: _testAccount,
              conversation: conversation,
              title: 'плюшевая конфа',
              avatarUrl: null,
              memberAvatars: const [],
              currentUserId: 1,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both name AND avatar should be visible for a single message
      expect(find.text('Даня Вишня'), findsOneWidget);
      // Top bar avatar + message avatar = 2
      expect(find.byType(RetroChatAvatar), findsNWidgets(2));
    });

    testWidgets('Consecutive messages show name on first (top) and avatar on last (bottom)', (tester) async {
      final client = OpenVkClient();
      client.userCache.putUser(const User(
        id: 42,
        firstName: 'Даня',
        lastName: 'Вишня',
        photo50: '',
        photo100: '',
        isOnline: true,
      ));

      final conversation = ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message.empty(),
      );

      client.messengerStore.getOrCreateConversationNotifier(conversation);

      // In reverse list: index 0 is newest (bottom), index 2 is oldest (top)
      // Top message (msg 1, oldest): 'занятой человек'
      // Middle message (msg 2): 'кстати'
      // Bottom message (msg 3, newest): 'надо как нибудь на а придумать'
      final msg1 = const Message(
        id: 1,
        date: 1600000000,
        peerId: 2000000001,
        fromId: 42,
        text: 'занятой человек',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1600000000,
      );
      final msg2 = const Message(
        id: 2,
        date: 1600000010,
        peerId: 2000000001,
        fromId: 42,
        text: 'кстати',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 2,
        updateTime: 1600000010,
      );
      final msg3 = const Message(
        id: 3,
        date: 1600000020,
        peerId: 2000000001,
        fromId: 42,
        text: 'надо как нибудь на а придумать',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 3,
        updateTime: 1600000020,
      );

      // setHistory with items from newest to oldest: [msg3, msg2, msg1]
      client.messengerStore.setHistory(
        2000000001,
        HistoryResponse(
          count: 3,
          items: [msg3, msg2, msg1],
          profiles: {},
          groups: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: _testAccount,
              conversation: conversation,
              title: 'плюшевая конфа',
              avatarUrl: null,
              memberAvatars: const [],
              currentUserId: 1,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Name should be shown ONLY ONCE (on msg1, the first message of the group)
      expect(find.text('Даня Вишня'), findsOneWidget);

      // In the message list, exactly 1 RetroChatAvatar should be rendered (for msg3, the bottom message).
      // Plus 1 RetroChatAvatar in AppBar = 2 RetroChatAvatar widgets in total
      expect(find.byType(RetroChatAvatar), findsNWidgets(2));
    });

    testWidgets('Wide chat (> 870px) aligns outgoing messages to the left with account avatar', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = OpenVkClient();
      final outMsg = const Message(
        id: 201,
        date: 1600000000,
        peerId: 100,
        fromId: 1,
        text: 'Моё исходящее сообщение',
        isOut: true,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1600000000,
      );

      final conversation = ConversationItem(
        peerId: 100,
        peerType: 'user',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: outMsg,
      );

      client.messengerStore.getOrCreateConversationNotifier(conversation);
      final msgNotifier = client.messengerStore.getMessageNotifier(201);
      if (msgNotifier != null) {
        msgNotifier.value = outMsg;
      } else {
        client.messengerStore.onNewMessage(
          messageId: 201,
          flags: 2,
          peerId: 100,
          timestamp: 1600000000,
          text: 'Моё исходящее сообщение',
          fromId: 1,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: _testAccount,
              conversation: conversation,
              title: 'Тестовый чат',
              currentUserId: 1,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Моё исходящее сообщение', findRichText: true), findsOneWidget);
      // Width is 1000 > 870: outgoing message has its avatar rendered on left
      // 1 in AppBar + 1 for outgoing message = 2
      expect(find.byType(RetroChatAvatar), findsNWidgets(2));

      // Row alignment for message is MainAxisAlignment.start
      final rowFinder = find.ancestor(
        of: find.textContaining('Моё исходящее сообщение', findRichText: true),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);
      final rows = tester.widgetList<Row>(rowFinder);
      expect(rows.any((r) => r.mainAxisAlignment == MainAxisAlignment.start), isTrue);
    });

    testWidgets('Wide screen (> 900px) shows two-pane layout with 400px sidebar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = OpenVkClient();
      final conversation = ConversationItem(
        peerId: 100,
        peerType: 'user',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message.empty(),
      );
      client.messengerStore.getOrCreateConversationNotifier(conversation);
      client.messengerStore.conversationOrder.value = [100];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesView(
              client: client,
              account: _testAccount,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sidebar with width 400 exists
      final sidebarFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 400,
      );
      expect(sidebarFinder, findsOneWidget);

      // Placeholder is shown since no chat is selected yet
      expect(find.text('Выберите диалог'), findsOneWidget);
    });
  });
}
