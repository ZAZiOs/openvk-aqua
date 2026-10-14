import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/cache/user_cache.dart';
import 'package:openvk_flutter/core/models/conversation.dart';
import 'package:openvk_flutter/core/models/group.dart';
import 'package:openvk_flutter/core/models/message.dart';
import 'package:openvk_flutter/core/models/user.dart';
import 'package:openvk_flutter/core/store/messenger_store.dart';

void main() {
  group('UserCache Tests', () {
    test('stores and overwrites users, groups, and chats in RAM', () {
      final cache = UserCache();

      // Put initial user
      cache.putUser(const User(
        id: 10,
        firstName: 'Иван',
        lastName: 'Иванов',
        photo50: 'http://img/50.png',
        photo100: 'http://img/100.png',
        isOnline: false,
      ));

      expect(cache.hasUser(10), isTrue);
      expect(cache.getUser(10)?.fullName, 'Иван Иванов');
      expect(cache.getSenderName(10), 'Иван');

      // Overwrite with newer info (e.g. online, updated avatar)
      cache.putUser(const User(
        id: 10,
        firstName: 'Иван',
        lastName: 'Иванов',
        photo50: 'http://img/50_new.png',
        photo100: 'http://img/100_new.png',
        isOnline: true,
      ));

      expect(cache.getUser(10)?.isOnline, isTrue);
      expect(cache.getUser(10)?.avatarUrl, 'http://img/100_new.png');

      // Put group
      cache.putGroup(const Group(
        id: 5,
        name: 'Новости OpenVK',
        screenName: 'openvk_news',
        photo50: '',
        photo100: '',
        isClosed: false,
      ));

      expect(cache.hasGroup(5), isTrue);
      expect(cache.getSenderName(-5), 'Новости OpenVK');
    });

    test('MessengerStore parses attachments {from: ID} and auto-requests missing user', () async {
      final requestedUsers = <int>[];

      final cache = UserCache(
        fetchUsersHandler: (ids) async {
          requestedUsers.addAll(ids);
          return ids
              .map(
                (id) => User(
                  id: id,
                  firstName: 'Пользователь_$id',
                  lastName: 'Тест',
                  photo50: '',
                  photo100: '',
                  isOnline: true,
                ),
              )
              .toList();
        },
      );

      final store = MessengerStore(userCache: cache);

      // LongPoll v1/v2/v3 event 4 in a group chat (peerId = 2000000001)
      // Sender is in attachments: {'from': '777'}
      store.onNewMessage(
        messageId: 501,
        flags: 1, // in, unread
        peerId: 2000000001,
        timestamp: 1600000000,
        text: 'Привет всем в беседе!',
        attachments: {
          'from': '777',
        },
      );

      final msg = store.getMessage(501);
      expect(msg, isNotNull);
      expect(msg!.fromId, 777);
      expect(msg.text, 'Привет всем в беседе!');

      // User 777 is not yet in cache immediately
      expect(cache.hasUser(777), isFalse);

      // Wait for debounce batch timer (50ms)
      await Future.delayed(const Duration(milliseconds: 100));

      expect(requestedUsers, contains(777));
      expect(cache.hasUser(777), isTrue);
      expect(cache.getSenderName(777), 'Пользователь_777');
      expect(cache.revision.value, greaterThan(0));
    });

    test('getTitle and getAvatarUrl auto-request missing users and update via revision', () async {
      final requestedUsers = <int>[];

      final cache = UserCache(
        fetchUsersHandler: (ids) async {
          requestedUsers.addAll(ids);
          return ids
              .map(
                (id) => User(
                  id: id,
                  firstName: 'Алиса',
                  lastName: 'Фоксовна',
                  photo50: 'http://img/photo_50.jpg',
                  photo100: 'http://img/photo_100.jpg',
                  isOnline: true,
                ),
              )
              .toList();
        },
      );

      final item = ConversationItem(
        peerId: 7307,
        peerType: 'user',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: Message.empty(),
      );

      // Initially not in cache: fallback title returned, auto-request triggered
      final initialTitle = cache.getTitle(item);
      expect(initialTitle, 'Пользователь #7307');
      expect(cache.getAvatarUrl(item), isNull);

      // Wait for debounce timer (30ms)
      await Future.delayed(const Duration(milliseconds: 60));

      expect(requestedUsers, contains(7307));
      expect(cache.hasUser(7307), isTrue);
      expect(cache.getTitle(item), 'Алиса Фоксовна');
      expect(cache.getAvatarUrl(item), 'http://img/photo_100.jpg');
    });

    test('clear() resets in-memory cache completely', () {
      final cache = UserCache();
      cache.putUser(const User(
        id: 1,
        firstName: 'Тест',
        lastName: '',
        photo50: '',
        photo100: '',
        isOnline: false,
      ));
      expect(cache.hasUser(1), isTrue);

      cache.clear();
      expect(cache.hasUser(1), isFalse);
      expect(cache.users.isEmpty, isTrue);
      expect(cache.revision.value, 0);
    });
  });
}
