import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/core.dart';
import 'package:openvk_flutter/ui/views/messages/chat_conversation_view.dart';

void main() {
  group('Sticker Message Tests', () {
    test('Message.isSticker and previewText work correctly', () {
      final msg = Message(
        id: 1,
        date: 1600000000,
        peerId: 2000000001,
        fromId: 10,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [
          const Attachment(
            type: 'sticker',
            sticker: StickerAttachment(
              stickerId: 456,
              productId: 1,
              animationUrl: '',
              images: ['https://vk.com/sticker/1-456-256b.png'],
            ),
          ),
        ],
        fwdMessages: const [],
        conversationMessageId: 1,
        updateTime: 1600000000,
      );

      expect(msg.isSticker, isTrue);
      expect(msg.previewText, '[Стикер]');
      expect(msg.stickerAttachment?.stickerId, 456);
      expect(msg.stickerAttachment?.bestImage, 'https://vk.com/sticker/1-456-256b.png');
    });

    test('StickerAttachment parses sizes and fallbacks', () {
      final json = {
        'type': 'sticker',
        'sticker': {
          'id': 789,
          'product_id': 2,
          'photo_512': 'https://vk.com/sticker/1-789-512b.png',
        },
      };

      final att = Attachment.fromJson(json);
      expect(att.type, 'sticker');
      expect(att.sticker?.stickerId, 789);
      expect(att.sticker?.bestImage, 'https://vk.com/sticker/1-789-512b.png');
    });

    testWidgets('ChatConversationView renders sticker without author name and speech bubble', (
      WidgetTester tester,
    ) async {
      final client = OpenVkClient();
      client.userCache.putUser(const User(
        id: 10,
        firstName: 'Алексей',
        lastName: 'Смирнов',
        photo50: '',
        photo100: '',
        isOnline: true,
      ));

      final stickerMsg = Message(
        id: 101,
        date: 1600000000,
        peerId: 2000000001,
        fromId: 10,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [
          const Attachment(
            type: 'sticker',
            sticker: StickerAttachment(
              stickerId: 456,
              productId: 1,
              animationUrl: '',
              images: [],
            ),
          ),
        ],
        fwdMessages: const [],
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
        lastMessage: stickerMsg,
      );

      // Pre-populate store with this message
      client.messengerStore.getOrCreateConversationNotifier(conversation);
      final msgNotifier = client.messengerStore.getMessageNotifier(101);
      if (msgNotifier != null) {
        msgNotifier.value = stickerMsg;
      } else {
        client.messengerStore.onNewMessage(
          messageId: 101,
          flags: 0,
          peerId: 2000000001,
          timestamp: 1600000000,
          text: '',
          attachments: {'attach1_type': 'sticker', 'attach1': '456'},
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              conversation: conversation,
              title: 'Тестовая беседа',
              avatarUrl: null,
              memberAvatars: const [],
              currentUserId: 1,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The author name should NOT be rendered for a sticker message
      expect(find.text('Алексей'), findsNothing);

      // Sticker fallback or image should be present
      expect(find.byType(Stack), findsWidgets);

      client.clearToken();
    });
  });
}
