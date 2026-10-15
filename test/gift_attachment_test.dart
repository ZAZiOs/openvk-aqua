import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/api/auth_handler.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/models/attachment.dart';
import 'package:openvk_flutter/core/models/conversation.dart';
import 'package:openvk_flutter/core/models/message.dart';
import 'package:openvk_flutter/ui/views/messages/chat_conversation_view.dart';
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

  group('Gift Attachment Model Tests', () {
    test('Attachment.fromJson parses gift attachment correctly', () {
      final json = {
        'type': 'gift',
        'gift': {
          'id': 13,
          'message': 'С праздником!',
          'date': 1791795183,
          'privacy': 0,
          'gift': {
            'id': 1,
            'stickers_product_id': null,
            'thumb_256': 'https://ovk.zazios.ru/images/gift/1/256.png',
            'thumb_96': 'https://ovk.zazios.ru/images/gift/1/96.png',
            'thumb_48': 'https://ovk.zazios.ru/images/gift/1/48.png',
          },
        },
      };

      final attachment = Attachment.fromJson(json);
      expect(attachment.type, 'gift');
      expect(attachment.gift, isNotNull);
      expect(attachment.summaryText, '[Подарок]');

      final gift = attachment.gift!;
      expect(gift.id, 13);
      expect(gift.message, 'С праздником!');
      expect(gift.giftId, 1);
      expect(gift.bestThumb, 'https://ovk.zazios.ru/images/gift/1/256.png');
    });

    test('Message getters for gift attachment work as expected', () {
      final giftAtt = Attachment.fromJson({
        'type': 'gift',
        'gift': {
          'id': 13,
          'message': 'Подарок для тебя',
          'date': 1791795183,
          'privacy': 0,
          'gift': {
            'id': 5,
            'thumb_256': 'https://ovk.zazios.ru/images/gift/5/256.png',
          },
        },
      });

      final message = Message(
        id: 14787,
        date: 1791795183,
        peerId: 5,
        fromId: 1,
        text: '',
        isOut: true,
        isImportant: false,
        attachments: [giftAtt],
        fwdMessages: const [],
        conversationMessageId: 8,
        updateTime: 0,
      );

      expect(message.hasGift, isTrue);
      expect(message.giftAttachment, isNotNull);
      expect(message.giftAttachment!.giftId, 5);
      expect(message.previewText, 'Подарок для тебя');
    });
  });

  group('Gift Widget Display Tests', () {
    testWidgets('Renders golden bubble and text under gift image', (tester) async {
      final client = OpenVkClient();
      final giftAtt = Attachment.fromJson({
        'type': 'gift',
        'gift': {
          'id': 13,
          'message': 'Теплые пожелания',
          'date': 1791795183,
          'privacy': 0,
          'gift': {
            'id': 1,
            'thumb_256': 'https://ovk.zazios.ru/images/gift/1/256.png',
          },
        },
      });

      final giftMessage = Message(
        id: 14787,
        date: 1791795183,
        peerId: 5,
        fromId: 1,
        text: 'Держи подарок!',
        isOut: false,
        isImportant: false,
        attachments: [giftAtt],
        fwdMessages: const [],
        conversationMessageId: 8,
        updateTime: 0,
      );

      const conv = ConversationItem(
        peerId: 5,
        peerType: 'user',
        inRead: 14787,
        outRead: 14787,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message(
          id: 14787,
          date: 1791795183,
          peerId: 5,
          fromId: 1,
          text: 'Держи подарок!',
          isOut: false,
          isImportant: false,
          attachments: [],
          fwdMessages: [],
          conversationMessageId: 8,
          updateTime: 0,
        ),
      );

      client.messengerStore.getOrCreateConversationNotifier(conv);
      final orderNotifier = client.messengerStore.getChatMessageOrderNotifier(5);
      orderNotifier.value = [14787];
      client.messengerStore.putMessage(giftMessage);
      client.messengerStore.getChatMessageOrderNotifier(5).value = [14787];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: testAccount,
              conversation: conv,
              title: 'Собеседник',
              currentUserId: 100,
              isEmbedded: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the header above the gift image
      expect(find.textContaining('вам подарок'), findsOneWidget);

      // Find the text under the gift image
      expect(find.textContaining('Держи подарок!'), findsOneWidget);
      expect(find.textContaining('Теплые пожелания'), findsOneWidget);

      // Verify golden speech bubble decoration
      final container = tester.widget<Container>(
        find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final box = widget.decoration as BoxDecoration;
            if (box.gradient is LinearGradient) {
              final g = box.gradient as LinearGradient;
              // Check for golden colors
              return g.colors.contains(const Color(0xFFFFF9DB)) ||
                  g.colors.contains(const Color(0xFFFFDF7D));
            }
          }
          return false;
        }),
      );

      expect(container, isNotNull);
      final box = container.decoration as BoxDecoration;
      final border = box.border as Border;
      expect(border.top.color, const Color(0xFFE0B445));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
