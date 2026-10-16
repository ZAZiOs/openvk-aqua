import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvk_aqua/core/api/auth_handler.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/models/post.dart';
import 'package:openvk_aqua/core/models/post_comment.dart';
import 'package:openvk_aqua/core/models/user.dart';
import 'package:openvk_aqua/core/models/wall_comments_response.dart';
import 'package:openvk_aqua/ui/views/wall/post_view.dart';
import 'package:openvk_aqua/ui/views/wall/widgets/wall_post_card.dart';

void main() {
  group('PostComment & WallCommentsResponse Models Tests', () {
    test('PostComment.fromJson parses comment correctly', () {
      final json = {
        'id': 42,
        'from_id': 100,
        'date': 1696000000,
        'text': 'Отличный ретро-стиль!',
        'likes': {
          'count': 5,
          'user_likes': 1,
          'can_like': 1,
        },
      };

      final Map<int, User> usersMap = {
        100: const User(
          id: 100,
          firstName: 'Мику',
          lastName: 'Хацунэ',
          photo50: '',
          photo100: '',
          isOnline: true,
        ),
      };

      final comment = PostComment.fromJson(json, usersMap: usersMap);
      expect(comment.id, 42);
      expect(comment.fromId, 100);
      expect(comment.text, 'Отличный ретро-стиль!');
      expect(comment.likesCount, 5);
      expect(comment.userLikes, isTrue);
      expect(comment.authorName, 'Мику Хацунэ');
    });

    test('WallCommentsResponse.fromJson parses list and resolved profiles', () {
      final json = {
        'count': 1,
        'items': [
          {
            'id': 1,
            'from_id': 200,
            'date': 1696000000,
            'text': 'Тестовый комментарий',
          },
        ],
        'profiles': [
          {
            'id': 200,
            'first_name': 'Дмитрий',
            'last_name': 'Иванов',
          },
        ],
        'groups': <dynamic>[],
        'can_post': 1,
      };

      final response = WallCommentsResponse.fromJson(json);
      expect(response.count, 1);
      expect(response.items.length, 1);
      expect(response.items.first.authorName, 'Дмитрий Иванов');
      expect(response.canPost, isTrue);
    });
  });

  group('WallPostCard Interaction Tests', () {
    testWidgets('Tapping on comment button invokes onCommentsTap', (tester) async {
      bool commentsTapped = false;
      final post = Post(
        id: 1,
        ownerId: 10,
        fromId: 10,
        date: 1696000000,
        text: 'Тест поста',
        commentsCount: 3,
        author: const User(
          id: 10,
          firstName: 'User',
          lastName: 'Name',
          photo50: '',
          photo100: '',
          isOnline: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallPostCard(
              post: post,
              onCommentsTap: () => commentsTapped = true,
            ),
          ),
        ),
      );

      // Find comment icon and tap
      await tester.tap(find.byIcon(Icons.mode_comment_outlined));
      await tester.pumpAndSettle();

      expect(commentsTapped, isTrue);
    });

    testWidgets('Tapping on repost zone invokes onRepostContentTap', (tester) async {
      Post? tappedRepost;
      final repost = Post(
        id: 99,
        ownerId: 20,
        fromId: 20,
        date: 1695000000,
        text: 'Оригинальный пост',
        author: const User(
          id: 20,
          firstName: 'Repost',
          lastName: 'Author',
          photo50: '',
          photo100: '',
          isOnline: true,
        ),
      );

      final post = Post(
        id: 1,
        ownerId: 10,
        fromId: 10,
        date: 1696000000,
        text: 'Мой репост',
        copyHistory: [repost],
        author: const User(
          id: 10,
          firstName: 'User',
          lastName: 'Name',
          photo50: '',
          photo100: '',
          isOnline: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallPostCard(
              post: post,
              onRepostContentTap: (r) => tappedRepost = r,
            ),
          ),
        ),
      );

      expect(find.text('Оригинальный пост'), findsOneWidget);
      await tester.tap(find.text('Оригинальный пост'));
      await tester.pumpAndSettle();

      expect(tappedRepost, isNotNull);
      expect(tappedRepost!.id, 99);
      expect(tappedRepost!.text, 'Оригинальный пост');
    });
  });

  group('PostView Widget Tests', () {
    testWidgets('Renders post and comments, and can submit new comment', (tester) async {
      final post = Post(
        id: 123,
        ownerId: 456,
        fromId: 456,
        date: 1696000000,
        text: 'Главный пост для просмотра',
        commentsCount: 1,
        author: const User(
          id: 456,
          firstName: 'Мику',
          lastName: 'Хацунэ',
          photo50: '',
          photo100: '',
          isOnline: true,
        ),
      );

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('wall.getById')) {
          return http.Response(
            '{"response": [{"id": 123, "owner_id": 456, "from_id": 456, "date": 1696000000, "text": "Главный пост для просмотра", "comments": {"count": 1}}]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('wall.getComments')) {
          return http.Response(
            '{"response": {"count": 1, "items": [{"id": 10, "from_id": 789, "date": 1696000000, "text": "Первый комментарий"}], "profiles": [{"id": 789, "first_name": "Рин", "last_name": "Кагамине"}]}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('wall.createComment')) {
          return http.Response(
            '{"response": {"comment_id": 11}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"response": 1}', 200,
            headers: {'content-type': 'application/json'});
      });

      final client = OpenVkClient(
        baseUrl: 'https://openvk.su',
        httpClient: mockClient,
        enableLogging: false,
      );

      const account = SavedAccount(
        id: 1,
        instanceId: 1,
        userId: 456,
        accessToken: 'valid_token',
        name: 'Мику Хацунэ',
        avatarUrl: '',
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PostView(
            client: client,
            account: account,
            post: post,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that post text and header are displayed
      expect(find.text('Запись'), findsOneWidget);
      expect(find.text('Главный пост для просмотра'), findsOneWidget);
      expect(find.text('Первый комментарий'), findsOneWidget);
      expect(find.text('Рин Кагамине'), findsOneWidget);

      // Enter comment text into input bar and click "Отправить"
      await tester.enterText(find.byType(TextField), 'Мой новый комментарий!');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Verify that the text field is cleared after sending
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);

      // Verify tapping on comment opens the iOS 6 actions modal
      await tester.tap(find.text('Первый комментарий'));
      await tester.pumpAndSettle();

      expect(find.text('Ответить'), findsOneWidget);
      expect(find.text('Скопировать текст'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
    });
  });
}
