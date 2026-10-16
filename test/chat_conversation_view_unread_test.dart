import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/models/conversation.dart';
import 'package:openvk_aqua/core/models/message.dart';
import 'package:openvk_aqua/core/models/user.dart';
import 'package:openvk_aqua/ui/views/messages/chat_conversation_view.dart';

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
  testWidgets('Displays unread messages separator above the oldest unread message and debounces markAsRead', (tester) async {
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
      inRead: 100,
      outRead: 0,
      unreadCount: 2,
      isImportant: false,
      isUnanswered: false,
      lastMessage: Message.empty(),
    );

    client.messengerStore.getOrCreateConversationNotifier(conversation);

    // Read message (id: 100)
    client.messengerStore.onNewMessage(
      messageId: 100,
      flags: 0, // not unread
      peerId: 2000000001,
      timestamp: 1600000000,
      text: 'Прочитанное сообщение',
      fromId: 42,
    );

    // Unread message 1 (id: 101)
    client.messengerStore.onNewMessage(
      messageId: 101,
      flags: 1, // unread
      peerId: 2000000001,
      timestamp: 1600000010,
      text: 'Первое непрочитанное',
      fromId: 42,
    );

    // Unread message 2 (id: 102)
    client.messengerStore.onNewMessage(
      messageId: 102,
      flags: 1, // unread
      peerId: 2000000001,
      timestamp: 1600000020,
      text: 'Второе непрочитанное',
      fromId: 42,
    );

    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          client: client,
          account: _testAccount,
          conversation: conversation,
          title: 'Тестовый чат',
          currentUserId: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify unread messages separator is shown
    expect(find.text('Непрочитанные сообщения'), findsOneWidget);

    // Verify both unread messages and the read message are present
    expect(find.text('Первое непрочитанное'), findsOneWidget);
    expect(find.text('Второе непрочитанное'), findsOneWidget);
    expect(find.text('Прочитанное сообщение'), findsOneWidget);

    // Verify debounced markAsRead triggers
    await tester.pump(const Duration(milliseconds: 500));

    // inRead in store should now be updated to 102
    final conv = client.messengerStore.getConversationNotifier(2000000001)?.value;
    expect(conv, isNotNull);
    expect(conv!.inRead, 102);
    expect(conv.unreadCount, 0);
  });

  test('Event 80 updates totalUnreadCount and clears conversation badges when 0', () {
    final client = OpenVkClient();

    final conv = ConversationItem(
      peerId: 2000000005,
      peerType: 'chat',
      inRead: 10,
      outRead: 0,
      unreadCount: 3,
      isImportant: false,
      isUnanswered: false,
      lastMessage: Message.empty(),
    );

    client.messengerStore.getOrCreateConversationNotifier(conv);
    client.messengerStore.unreadConversationOrder.value = [2000000005];
    client.messengerStore.totalUnreadCount.value = 3;

    // Simulate Event 80 with count = 0
    client.messengerStore.setTotalUnreadCount(0);

    expect(client.messengerStore.totalUnreadCount.value, 0);
    expect(client.messengerStore.unreadConversationOrder.value, isEmpty);
    expect(client.messengerStore.getConversationNotifier(2000000005)?.value.unreadCount, 0);

    // Simulate Event 80 with count = 5
    client.messengerStore.setTotalUnreadCount(5);
    expect(client.messengerStore.totalUnreadCount.value, 5);
  });
}
