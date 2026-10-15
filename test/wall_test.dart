import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/models/post.dart';
import 'package:openvk_aqua/core/models/user.dart';
import 'package:openvk_aqua/core/models/wall_response.dart';
import 'package:openvk_aqua/ui/views/wall/wall_view.dart';
import 'package:openvk_aqua/ui/views/wall/widgets/dotted_leader_row.dart';
import 'package:openvk_aqua/ui/views/wall/widgets/wall_counters_grid.dart';
import 'package:openvk_aqua/ui/views/wall/widgets/wall_post_card.dart';

void main() {
  group('Wall & Post Models Tests', () {
    test('User.fromJson parses extended profile fields and counters', () {
      final json = {
        'id': 100,
        'first_name': 'Александр',
        'last_name': 'Сасискович',
        'nickname': 'sasikqq',
        'photo_50': 'https://example.com/50.jpg',
        'photo_100': 'https://example.com/100.jpg',
        'online': 1,
        'status': 'Абсолютный гений',
        'counters': {
          'friends': 31,
          'groups': 17,
          'followers': 1,
          'photos': 20,
          'videos': 2,
          'audios': 17,
        },
        'pronouns': 'он/его',
        'relation': 4,
        'relation_partner': {
          'id': 200,
          'first_name': 'Дмитрий',
          'last_name': 'Иванов',
        },
        'registration_date': '5 мая в 04:02',
        'home_town': 'Новослобідка',
        'political': 9,
        'bdate': '15 Сентября',
        'telegram': '@alexqndrrqq',
        'site': 'https://bento.me/sasik',
        'city': {'title': 'Люберцы'},
        'interests': 'Гадости писать в интернете',
        'music': 'Noize MC, Монеточка',
      };

      final user = User.fromJson(json);

      expect(user.id, 100);
      expect(user.firstName, 'Александр');
      expect(user.lastName, 'Сасискович');
      expect(user.nickname, 'sasikqq');
      expect(user.displayNameWithNickname, 'Александр (sasikqq) Сасискович');
      expect(user.status, 'Абсолютный гений');
      expect(user.isOnline, isTrue);
      expect(user.pronouns, 'он/его');
      expect(user.relation, 'В браке с Дмитрий Иванов');
      expect(user.registrationDate, '5 мая в 04:02');
      expect(user.homeTown, 'Новослобідка');
      expect(user.political, 'Либертарианские');
      expect(user.bdate, '15 Сентября');
      expect(user.telegram, '@alexqndrrqq');
      expect(user.site, 'https://bento.me/sasik');
      expect(user.city, 'Люберцы');
      expect(user.interests, 'Гадости писать в интернете');
      expect(user.music, 'Noize MC, Монеточка');

      expect(user.counters.friends, 31);
      expect(user.counters.groups, 17);
      expect(user.counters.followers, 1);
      expect(user.counters.photos, 20);
      expect(user.counters.videos, 2);
      expect(user.counters.audios, 17);
    });

    test('Post.fromJson parses post and resolves author', () {
      final postJson = {
        'id': 555,
        'owner_id': 100,
        'from_id': 100,
        'date': 1715000000,
        'text': 'Всем привет, только что гулял и купил себе доктор пепер :D',
        'comments': {'count': 5, 'can_post': 1},
        'likes': {'count': 12, 'user_likes': 1, 'can_like': 1},
        'reposts': {'count': 2, 'user_reposted': 0},
        'attachments': [
          {
            'type': 'photo',
            'photo': {
              'id': 1,
              'owner_id': 100,
              'photo_604': 'https://example.com/photo.jpg',
              'width': 604,
              'height': 400,
            },
          },
        ],
      };

      final author = User(
        id: 100,
        firstName: 'Александр',
        lastName: 'Сасискович',
        photo50: '',
        photo100: '',
        isOnline: true,
      );

      final post = Post.fromJson(postJson, usersMap: {100: author});

      expect(post.id, 555);
      expect(post.ownerId, 100);
      expect(post.fromId, 100);
      expect(post.authorName, 'Александр Сасискович');
      expect(post.text, contains('доктор пепер'));
      expect(post.likesCount, 12);
      expect(post.userLikes, isTrue);
      expect(post.commentsCount, 5);
      expect(post.repostsCount, 2);
      expect(post.attachments.length, 1);
      expect(post.attachments.first.type, 'photo');
    });

    test('WallResponse.fromJson parses items and profiles', () {
      final json = {
        'count': 1,
        'items': [
          {
            'id': 10,
            'owner_id': 100,
            'from_id': 100,
            'date': 1715000000,
            'text': 'Запись на стене',
          },
        ],
        'profiles': [
          {
            'id': 100,
            'first_name': 'Тест',
            'last_name': 'Юзер',
            'photo_50': '',
            'photo_100': '',
            'online': 1,
          },
        ],
      };

      final wall = WallResponse.fromJson(json);
      expect(wall.count, 1);
      expect(wall.items.length, 1);
      expect(wall.items.first.authorName, 'Тест Юзер');
    });
  });

  group('Wall UI Widgets Tests', () {
    testWidgets('WallCountersGrid displays numbers and plural labels', (tester) async {
      const counters = UserCounters(
        friends: 31,
        groups: 17,
        followers: 1,
        photos: 20,
        videos: 2,
        audios: 17,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WallCountersGrid(counters: counters),
          ),
        ),
      );

      expect(find.text('31'), findsOneWidget);
      expect(find.text('Друг'), findsOneWidget);
      expect(find.text('17'), findsNWidgets(2)); // groups and audios
      expect(find.text('Групп'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Подписчик'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('Фотографий'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Видеозаписи'), findsOneWidget);
      expect(find.text('Аудиозаписей'), findsOneWidget);
    });

    testWidgets('DottedLeaderRow renders label and value with dotted line', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DottedLeaderRow(
              label: 'Местоимения',
              value: 'он/его',
            ),
          ),
        ),
      );

      expect(find.text('Местоимения'), findsOneWidget);
      expect(find.text('он/его'), findsOneWidget);
    });

    testWidgets('WallPostCard renders author name, post text and action counts', (tester) async {
      final post = Post(
        id: 1,
        ownerId: 100,
        fromId: 100,
        date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        text: 'Привет всем!',
        likesCount: 15,
        commentsCount: 3,
        repostsCount: 1,
        author: const User(
          id: 100,
          firstName: 'Александр',
          lastName: 'Сасискович',
          photo50: '',
          photo100: '',
          isOnline: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallPostCard(post: post),
          ),
        ),
      );

      expect(find.text('Александр Сасискович'), findsOneWidget);
      expect(find.text('Привет всем!'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('WallView renders profile card with header info and composer', (tester) async {
      final client = OpenVkClient();
      const account = SavedAccount(
        id: 1,
        instanceId: 1,
        userId: 100,
        name: 'Александр Сасискович',
        avatarUrl: '',
        accessToken: 'token',
        isActive: true,
      );

      // Prepopulate cache
      client.userCache.putUsers([
        const User(
          id: 100,
          firstName: 'Александр',
          lastName: 'Сасискович',
          nickname: 'sasikqq',
          photo50: '',
          photo100: '',
          isOnline: true,
          status: 'Абсолютный гений',
          counters: UserCounters(friends: 31, photos: 20),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WallView(
            client: client,
            account: account,
          ),
        ),
      );

      await tester.pump();

      // Check header info
      expect(find.text('Александр (sasikqq)'), findsOneWidget);
      expect(find.text('Сасискович'), findsOneWidget);
      expect(find.text('Абсолютный гений'), findsOneWidget);
      expect(find.text('Онлайн'), findsOneWidget);

      // Check filter pills
      expect(find.text('Все записи'), findsOneWidget);
      expect(find.text('Мои записи'), findsOneWidget);

      // Check composer hint
      expect(find.text('Что нового?'), findsOneWidget);

      // Check expandable info section header
      expect(find.text('Информация'), findsOneWidget);

      // On own wall, friend and message buttons must not be present
      expect(find.text('Добавить в друзья'), findsNothing);
      expect(find.text('Сообщение'), findsNothing);
    });

    testWidgets('WallView renders iOS 6 action buttons for other user wall', (tester) async {
      final client = OpenVkClient();
      const account = SavedAccount(
        id: 1,
        instanceId: 1,
        userId: 100,
        name: 'Мой Профиль',
        avatarUrl: '',
        accessToken: 'token',
        isActive: true,
      );

      client.userCache.putUsers([
        const User(
          id: 200,
          firstName: 'Павел',
          lastName: 'Дуров',
          photo50: '',
          photo100: '',
          isOnline: true,
          status: 'ВКонтакте',
          counters: UserCounters(friends: 100, photos: 50),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WallView(
            client: client,
            account: account,
            ownerId: 200,
          ),
        ),
      );

      await tester.pump();

      // Check iOS 6 friend and message action buttons are rendered
      expect(find.text('Добавить в друзья'), findsOneWidget);
      expect(find.text('Сообщение'), findsOneWidget);
    });

    testWidgets('WallView renders darker "В друзьях" button and shows confirmation modal on tap', (tester) async {
      final client = OpenVkClient();
      const account = SavedAccount(
        id: 1,
        instanceId: 1,
        userId: 100,
        name: 'Мой Профиль',
        avatarUrl: '',
        accessToken: 'token',
        isActive: true,
      );

      client.userCache.putUsers([
        const User(
          id: 200,
          firstName: 'Павел',
          lastName: 'Дуров',
          photo50: '',
          photo100: '',
          isOnline: true,
          status: 'ВКонтакте',
          counters: UserCounters(friends: 100, photos: 50),
          friendStatus: 3,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WallView(
            client: client,
            account: account,
            ownerId: 200,
          ),
        ),
      );

      await tester.pump();

      // Check "В друзьях" button is rendered
      expect(find.text('В друзьях'), findsOneWidget);
      expect(find.text('Сообщение'), findsOneWidget);

      // Tap on "В друзьях"
      await tester.tap(find.text('В друзьях'));
      await tester.pumpAndSettle();

      // Confirm modal dialog should open
      expect(find.text('Удаление из друзей'), findsOneWidget);
      expect(find.text('Вы действительно хотите удалить Павел Дуров из списка друзей?'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      // Tap 'Отмена'
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // Dialog closed, still in friends
      expect(find.text('Удаление из друзей'), findsNothing);
      expect(find.text('В друзьях'), findsOneWidget);
    });
  });
}

