import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/cache/user_cache.dart';
import 'package:openvk_aqua/core/models/conversation.dart';
import 'package:openvk_aqua/core/models/message.dart';
import 'package:openvk_aqua/core/models/user.dart';
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

  group('Date Separator Tests', () {
    test('formatDateSeparator formats day and month in Russian genitive case', () {
      final now = DateTime.now();

      // Same year
      final dt1 = DateTime(now.year, 10, 16, 12, 0);
      final ts1 = dt1.millisecondsSinceEpoch ~/ 1000;
      expect(ChatConversationView.formatDateSeparator(ts1), '16 октября');

      final dt2 = DateTime(now.year, 10, 6, 8, 30);
      final ts2 = dt2.millisecondsSinceEpoch ~/ 1000;
      expect(ChatConversationView.formatDateSeparator(ts2), '6 октября');

      // Different year
      final dtPast = DateTime(2023, 5, 9, 10, 0);
      final tsPast = dtPast.millisecondsSinceEpoch ~/ 1000;
      expect(ChatConversationView.formatDateSeparator(tsPast), '9 мая 2023');

      // Zero or negative timestamp
      expect(ChatConversationView.formatDateSeparator(0), '');
    });

    test('isSameDay correctly detects same day vs different day', () {
      final dt1 = DateTime(2026, 10, 15, 12, 0);
      final dt2 = DateTime(2026, 10, 15, 23, 59);
      final dt3 = DateTime(2026, 10, 16, 0, 1);

      final ts1 = dt1.millisecondsSinceEpoch ~/ 1000;
      final ts2 = dt2.millisecondsSinceEpoch ~/ 1000;
      final ts3 = dt3.millisecondsSinceEpoch ~/ 1000;

      expect(ChatConversationView.isSameDay(ts1, ts2), isTrue);
      expect(ChatConversationView.isSameDay(ts1, ts3), isFalse);
    });

    testWidgets('ChatConversationView renders date separators above first message of each day', (tester) async {
      final userCache = UserCache();
      userCache.putUser(const User(
        id: 42,
        firstName: 'Даня',
        lastName: 'Вишня',
        photo50: '',
        photo100: '',
        isOnline: true,
      ));

      final client = OpenVkClient(userCache: userCache);

      // Create 3 messages across 2 different days
      // Day 1: 15 октября 2026
      final d1m1 = DateTime(DateTime.now().year, 10, 15, 12, 18).millisecondsSinceEpoch ~/ 1000;
      final d1m2 = DateTime(DateTime.now().year, 10, 15, 13, 0).millisecondsSinceEpoch ~/ 1000;
      // Day 2: 16 октября 2026
      final d2m1 = DateTime(DateTime.now().year, 10, 16, 0, 45).millisecondsSinceEpoch ~/ 1000;

      final msg1 = Message(
        id: 1,
        date: d1m1,
        peerId: 2000000001,
        fromId: 42,
        text: 'ага првиет',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: d1m1,
      );

      final msg2 = Message(
        id: 2,
        date: d1m2,
        peerId: 2000000001,
        fromId: 42,
        text: 'как дела?',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 2,
        updateTime: d1m2,
      );

      final msg3 = Message(
        id: 3,
        date: d2m1,
        peerId: 2000000001,
        fromId: 42,
        text: 'О нифига',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 3,
        updateTime: d2m1,
      );

      final conv = const ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message(
          id: 3,
          date: 0,
          peerId: 2000000001,
          fromId: 42,
          text: '',
          isOut: false,
          isImportant: false,
          attachments: [],
          fwdMessages: [],
          conversationMessageId: 3,
          updateTime: 0,
        ),
      );

      client.messengerStore.getOrCreateConversationNotifier(conv);
      client.messengerStore.putMessage(msg1);
      client.messengerStore.putMessage(msg2);
      client.messengerStore.putMessage(msg3);

      // Descending order: msg3 (newest), msg2, msg1 (oldest)
      client.messengerStore.getChatMessageOrderNotifier(2000000001).value = [3, 2, 1];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: testAccount,
              conversation: conv,
              title: 'плюшевая конфа',
              currentUserId: 100,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Day 1 header should be present
      expect(find.text('15 октября'), findsOneWidget);
      // Day 2 header should be present
      expect(find.text('16 октября'), findsOneWidget);

      // Verify that date text is bold and non-italic
      final textWidget = tester.widget<Text>(find.text('16 октября'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.fontStyle, isNot(FontStyle.italic));
      expect(textWidget.style?.color, const Color(0xFF6B7B8D));
      expect(textWidget.textAlign, TextAlign.center);
    });
  });
}
