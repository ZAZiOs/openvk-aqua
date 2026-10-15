import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/models/conversation.dart';
import 'package:openvk_aqua/core/models/message.dart';
import 'package:openvk_aqua/main.dart';
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

  group('Escape Key Navigation Tests', () {
    testWidgets('Pressing Escape in OpenVkApp pops the topmost pushed route', (tester) async {
      final client = OpenVkClient();
      final authHandler = AuthHandler(client: client);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        OpenVkApp(
          authHandler: authHandler,
          client: client,
          initialAccount: testAccount,
          navigatorKey: navKey,
        ),
      );
      await tester.pumpAndSettle();

      // Verify we are on the home screen
      expect(find.byType(OpenVkApp), findsOneWidget);

      // Push a new route
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Второй экран')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Второй экран'), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Verify second route popped
      expect(find.text('Второй экран'), findsNothing);
    });

    testWidgets('Pressing Escape in ChatConversationView pops route when pushed', (tester) async {
      final client = OpenVkClient();
      final conv = const ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message(
          id: 1,
          date: 1000,
          peerId: 2000000001,
          fromId: 100,
          text: 'Привет',
          isOut: true,
          isImportant: false,
          attachments: [],
          fwdMessages: [],
          conversationMessageId: 1,
          updateTime: 1000,
        ),
      );

      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatConversationView(
                        client: client,
                        account: testAccount,
                        conversation: conv,
                        title: 'Беседа',
                        currentUserId: 100,
                      ),
                    ),
                  );
                },
                child: const Text('Открыть чат'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть чат'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatConversationView), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Chat should be popped
      expect(find.byType(ChatConversationView), findsNothing);
      expect(find.text('Открыть чат'), findsOneWidget);
    });

    testWidgets('Pressing Escape in embedded ChatConversationView calls onClose', (tester) async {
      final client = OpenVkClient();
      final conv = const ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message(
          id: 1,
          date: 1000,
          peerId: 2000000001,
          fromId: 100,
          text: 'Привет',
          isOut: true,
          isImportant: false,
          attachments: [],
          fwdMessages: [],
          conversationMessageId: 1,
          updateTime: 1000,
        ),
      );

      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: testAccount,
              conversation: conv,
              title: 'Беседа в 2-pane',
              currentUserId: 100,
              isEmbedded: true,
              onClose: () {
                closed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(closed, isFalse);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}
