import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/core.dart';
import 'package:openvk_flutter/ui/widgets/retro_chat_avatar.dart';

void main() {
  group('RetroChatAvatar Widget Tests', () {
    testWidgets('renders placeholder when no avatarUrl and no members', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroChatAvatar(
              avatarUrl: null,
              members: null,
              fallbackText: '?',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
    });

    testWidgets('renders 4 member initials when no images and 4 members provided', (
      WidgetTester tester,
    ) async {
      const members = [
        ChatMemberAvatarInfo(url: null, fallbackText: 'Анна'),
        ChatMemberAvatarInfo(url: null, fallbackText: 'Борис'),
        ChatMemberAvatarInfo(url: null, fallbackText: 'Виктор'),
        ChatMemberAvatarInfo(url: null, fallbackText: 'Дарья'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroChatAvatar(
              avatarUrl: null,
              members: members,
            ),
          ),
        ),
      );

      expect(find.text('А'), findsOneWidget);
      expect(find.text('Б'), findsOneWidget);
      expect(find.text('В'), findsOneWidget);
      expect(find.text('Д'), findsOneWidget);
    });

    testWidgets('renders 2 member initials when 2 members provided', (
      WidgetTester tester,
    ) async {
      const members = [
        ChatMemberAvatarInfo(url: null, fallbackText: 'Иван'),
        ChatMemberAvatarInfo(url: null, fallbackText: 'Ольга'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroChatAvatar(
              avatarUrl: null,
              members: members,
            ),
          ),
        ),
      );

      expect(find.text('И'), findsOneWidget);
      expect(find.text('О'), findsOneWidget);
    });

    testWidgets('renders 3 member initials when 3 members provided', (
      WidgetTester tester,
    ) async {
      const members = [
        ChatMemberAvatarInfo(url: null, fallbackText: 'Павел'),
        ChatMemberAvatarInfo(url: null, fallbackText: 'Николай'),
        ChatMemberAvatarInfo(url: null, fallbackText: 'Елена'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroChatAvatar(
              avatarUrl: null,
              members: members,
            ),
          ),
        ),
      );

      expect(find.text('П'), findsOneWidget);
      expect(find.text('Н'), findsOneWidget);
      expect(find.text('Е'), findsOneWidget);
    });

    testWidgets('renders single fallback letter when 1 member provided', (
      WidgetTester tester,
    ) async {
      const members = [
        ChatMemberAvatarInfo(url: null, fallbackText: 'Сергей'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroChatAvatar(
              avatarUrl: null,
              members: members,
            ),
          ),
        ),
      );

      expect(find.text('С'), findsOneWidget);
    });

    testWidgets('renders online dot when isOnline is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroChatAvatar(
              avatarUrl: null,
              fallbackText: 'Алексей',
              isOnline: true,
            ),
          ),
        ),
      );

      expect(find.byType(Positioned), findsOneWidget);
    });
  });

  group('ConversationsResponse Model Tests', () {
    test('extracts up to 4 participant avatars for chat without photo', () {
      final json = {
        'count': 1,
        'unread_count': 0,
        'items': [
          {
            'conversation': {
              'peer': {'id': 2000000001, 'type': 'chat'},
              'in_read': 1,
              'out_read': 1,
              'unread_count': 0,
              'chat_settings': {
                'title': 'Тестовая беседа',
                'members_count': 5,
                'active_ids': [101, 102, 103, 104, 105],
                'photo': {},
              },
            },
            'last_message': {
              'id': 1,
              'date': 1700000000,
              'peer_id': 2000000001,
              'from_id': 101,
              'text': 'Привет!',
            },
          }
        ],
        'profiles': [
          {'id': 101, 'first_name': 'Алиса', 'last_name': 'Селезнева', 'photo_100': 'http://img/101.jpg'},
          {'id': 102, 'first_name': 'Боб', 'last_name': 'Марли', 'photo_100': 'http://img/102.jpg'},
          {'id': 103, 'first_name': 'Вова', 'last_name': 'Сидоров', 'photo_100': 'http://img/103.jpg'},
          {'id': 104, 'first_name': 'Галя', 'last_name': 'Иванова', 'photo_100': 'http://img/104.jpg'},
          {'id': 105, 'first_name': 'Дима', 'last_name': 'Петров', 'photo_100': 'http://img/105.jpg'},
        ],
        'groups': [],
      };

      final response = ConversationsResponse.fromJson(json);
      final item = response.items.first;

      expect(item.isChat, isTrue);
      expect(response.getAvatarUrl(item), isNull);

      final memberAvatars = response.getChatMemberAvatars(item, maxCount: 4);
      expect(memberAvatars.length, 4);
      expect(memberAvatars[0].url, 'http://img/101.jpg');
      expect(memberAvatars[0].fallbackText, 'Алиса');
      expect(memberAvatars[1].url, 'http://img/102.jpg');
      expect(memberAvatars[1].fallbackText, 'Боб');
      expect(memberAvatars[2].url, 'http://img/103.jpg');
      expect(memberAvatars[2].fallbackText, 'Вова');
      expect(memberAvatars[3].url, 'http://img/104.jpg');
      expect(memberAvatars[3].fallbackText, 'Галя');
    });
  });
}
