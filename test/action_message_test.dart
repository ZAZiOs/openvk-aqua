import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/api/auth_handler.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/cache/user_cache.dart';
import 'package:openvk_flutter/core/models/conversation.dart';
import 'package:openvk_flutter/core/models/message.dart';
import 'package:openvk_flutter/core/models/user.dart';
import 'package:openvk_flutter/ui/views/messages/chat_conversation_view.dart';
import 'package:openvk_flutter/ui/views/messages/messages_view.dart';

const _testAccount = SavedAccount(
  id: 1,
  instanceId: 1,
  userId: 100,
  name: 'Текущий Пользователь',
  avatarUrl: '',
  accessToken: 'tok',
  isActive: true,
);

void main() {
  group('MessageAction parsing and formatText', () {
    late UserCache userCache;

    setUp(() {
      userCache = UserCache();
      userCache.putUser(const User(
        id: 1,
        firstName: 'Иван',
        lastName: 'Иванов',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 2, // 2 - он/его
      ));
      userCache.putUser(const User(
        id: 2,
        firstName: 'Анна',
        lastName: 'Смирнова',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 1, // 1 - она/её
      ));
      userCache.putUser(const User(
        id: 3,
        firstName: 'Петр',
        lastName: 'Петров',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 2, // 2 - он/его
      ));
      userCache.putUser(const User(
        id: 4,
        firstName: 'Саша',
        lastName: 'Серая',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 0, // 0 - они/их (типо неуказаны)
      ));
    });

    test('chat_create formatting', () {
      final msgOther = Message.fromJson({
        'id': 1,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_create',
          'text': 'плюшевая конфа',
        },
      });

      expect(
        msgOther.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов создал беседу «плюшевая конфа»',
      );

      final msgFemale = Message.fromJson({
        'id': 2,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 2,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_create',
          'text': 'плюшевая конфа',
        },
      });

      expect(
        msgFemale.formatActionText(currentUserId: 100, userCache: userCache),
        'Анна Смирнова создала беседу «плюшевая конфа»',
      );

      final msgSelf = Message.fromJson({
        'id': 3,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 100,
        'text': '',
        'out': 1,
        'action': {
          'type': 'chat_create',
          'text': 'плюшевая конфа',
        },
      });

      expect(
        msgSelf.formatActionText(currentUserId: 100, userCache: userCache),
        'Вы создали беседу «плюшевая конфа»',
      );
    });

    test('chat_title_update formatting', () {
      final msg = Message.fromJson({
        'id': 4,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_title_update',
          'text': 'Новое название',
        },
      });

      expect(
        msg.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов изменил название беседы на «Новое название»',
      );

      final msgSelf = msg.copyWith(fromId: 100);
      expect(
        msgSelf.formatActionText(currentUserId: 100, userCache: userCache),
        'Вы изменили название беседы на «Новое название»',
      );
    });

    test('chat_photo_update and chat_photo_remove formatting', () {
      final msgPhoto = Message.fromJson({
        'id': 5,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 2,
        'text': '',
        'out': 0,
        'action': {'type': 'chat_photo_update'},
      });

      expect(
        msgPhoto.formatActionText(currentUserId: 100, userCache: userCache),
        'Анна Смирнова обновила фотографию беседы',
      );

      final msgRemove = Message.fromJson({
        'id': 6,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 100,
        'text': '',
        'out': 1,
        'action': {'type': 'chat_photo_remove'},
      });

      expect(
        msgRemove.formatActionText(currentUserId: 100, userCache: userCache),
        'Вы удалили фотографию беседы',
      );
    });

    test('chat_invite_user formatting', () {
      // 1 invites 3
      final msgInviteOther = Message.fromJson({
        'id': 7,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_invite_user',
          'member_id': 3,
        },
      });

      expect(
        msgInviteOther.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов пригласил Петр Петров',
      );

      // 1 invites current user (100)
      final msgInviteSelf = Message.fromJson({
        'id': 8,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_invite_user',
          'member_id': 100,
        },
      });

      expect(
        msgInviteSelf.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов пригласил вас',
      );

      // User returns himself (member_id == from_id)
      final msgReturn = Message.fromJson({
        'id': 9,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_invite_user',
          'member_id': 1,
        },
      });

      expect(
        msgReturn.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов вернулся в беседу',
      );
    });

    test('chat_kick_user formatting', () {
      // 1 kicks 3
      final msgKickOther = Message.fromJson({
        'id': 10,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_kick_user',
          'member_id': 3,
        },
      });

      expect(
        msgKickOther.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов исключил Петр Петров',
      );

      // User leaves chat themselves (member_id == from_id)
      final msgLeave = Message.fromJson({
        'id': 11,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_kick_user',
          'member_id': 1,
        },
      });

      expect(
        msgLeave.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов покинул беседу',
      );
    });

    test('chat_pin_message and chat_unpin_message formatting', () {
      final msgPin = Message.fromJson({
        'id': 12,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {'type': 'chat_pin_message'},
      });

      expect(
        msgPin.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов закрепил сообщение',
      );

      final msgUnpin = Message.fromJson({
        'id': 13,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 100,
        'text': '',
        'out': 1,
        'action': {'type': 'chat_unpin_message'},
      });

      expect(
        msgUnpin.formatActionText(currentUserId: 100, userCache: userCache),
        'Вы открепили сообщение',
      );
    });

    test('chat_invite_user_by_link formatting', () {
      final msgJoin = Message.fromJson({
        'id': 14,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 2,
        'text': '',
        'out': 0,
        'action': {'type': 'chat_invite_user_by_link'},
      });

      expect(
        msgJoin.formatActionText(currentUserId: 100, userCache: userCache),
        'Анна Смирнова присоединилась к беседе по ссылке',
      );
    });

    test('LongPoll onNewMessage parses source_act into MessageAction', () {
      final client = OpenVkClient(userCache: userCache);
      final store = client.messengerStore;

      store.onNewMessage(
        messageId: 999,
        flags: 0,
        peerId: 2000000001,
        timestamp: 1700000050,
        text: '...',
        extraFields: {
          'from': 1,
          'source_act': 'chat_title_update',
          'source_text': 'Новый заголовок из LP',
        },
      );

      final msg = store.getMessage(999);
      expect(msg, isNotNull);
      expect(msg!.action, isNotNull);
      expect(msg.action!.type, 'chat_title_update');
      expect(msg.action!.text, 'Новый заголовок из LP');
      expect(
        msg.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов изменил название беседы на «Новый заголовок из LP»',
      );
    });

    test('chat_moderator_add formatting', () {
      final msgAdd = Message.fromJson({
        'id': 15,
        'date': 1700000000,
        'peer_id': 2000000001,
        'from_id': 1,
        'text': '',
        'out': 0,
        'action': {
          'type': 'chat_moderator_add',
          'member_id': 3,
        },
      });

      expect(
        msgAdd.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов назначил Петр Петров администратором',
      );

      final msgAddSelf = msgAdd.copyWith(
        action: const MessageAction(type: 'chat_moderator_add', memberId: 100),
      );
      expect(
        msgAddSelf.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов назначил вас администратором',
      );

      final msgMyAction = msgAdd.copyWith(fromId: 100);
      expect(
        msgMyAction.formatActionText(currentUserId: 100, userCache: userCache),
        'Вы назначили Петр Петров администратором',
      );
    });

    test('chat_moderator_remove formatting from user getHistory payload', () {
      // Exact getHistory payload provided by user:
      final msgRemove = Message.fromJson({
        'id': 14854,
        'conversation_message_id': 47,
        'date': 1792058138,
        'peer_id': 2000000257,
        'from_id': 1,
        'out': 1,
        'text': 'снял полномочия администратора с Дмитий Владимирович',
        'attachments': [],
        'action': {
          'member_id': 2,
          'type': 'chat_moderator_remove',
          'text': '',
        },
      });

      // When from_id 1 is current user (out: 1):
      expect(
        msgRemove.formatActionText(currentUserId: 1, userCache: userCache),
        'Вы сняли полномочия администратора с Анна Смирнова',
      );

      // When from_id 1 is another user:
      expect(
        msgRemove.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов снял полномочия администратора с Анна Смирнова',
      );

      // When target is current user:
      final msgTargetMe = msgRemove.copyWith(
        action: const MessageAction(type: 'chat_moderator_remove', memberId: 100),
      );
      expect(
        msgTargetMe.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов снял полномочия администратора с вас',
      );
    });

    test('NIM LongPoll payload with chat_moderator_add parses and formats', () {
      final client = OpenVkClient(userCache: userCache);
      final store = client.messengerStore;

      // Exact NIM LongPoll payload from user:
      // index 7 has attachments Map with source_act and source_mid
      store.onNewMessage(
        messageId: 14853,
        flags: 2,
        peerId: 2000000257,
        timestamp: 1792058070,
        text: 'appointed user 5 as moderator',
        attachments: {
          'cmid': 46,
          'conversation_message_id': 46,
          'from': 1,
          'source_act': 'chat_moderator_add',
          'source_mid': '5',
        },
      );

      final msg = store.getMessage(14853);
      expect(msg, isNotNull);
      expect(msg!.action, isNotNull);
      expect(msg.action!.type, 'chat_moderator_add');
      expect(msg.action!.memberId, 5);
      expect(msg.fromId, 1);
      expect(
        msg.formatActionText(currentUserId: 100, userCache: userCache),
        'Иван Иванов назначил пользователя id5 администратором',
      );
    });
  });

  group('UI rendering for action messages', () {
    testWidgets('renders action message as a centered pill in ChatConversationView', (tester) async {
      final userCache = UserCache();
      userCache.putUser(const User(
        id: 42,
        firstName: 'Даня',
        lastName: 'Вишня',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 2,
      ));

      final actionMsg = const Message(
        id: 501,
        date: 1600000000,
        peerId: 2000000001,
        fromId: 42,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1600000000,
        action: MessageAction(
          type: 'chat_create',
          text: 'плюшевая конфа',
        ),
      );

      final client = OpenVkClient(userCache: userCache);
      final conv = ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: actionMsg,
      );

      client.messengerStore.getOrCreateConversationNotifier(conv);
      client.messengerStore.putMessage(actionMsg);
      client.messengerStore.getChatMessageOrderNotifier(2000000001).value = [501];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConversationView(
              client: client,
              account: _testAccount,
              conversation: conv,
              title: 'плюшевая конфа',
              currentUserId: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Даня Вишня создал беседу «плюшевая конфа»'),
        findsOneWidget,
      );
    });

    testWidgets('MessagesView displays action text in conversation tile subtitle without sender prefix', (tester) async {
      final userCache = UserCache();
      userCache.putUser(const User(
        id: 42,
        firstName: 'Даня',
        lastName: 'Вишня',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 2,
      ));

      final actionMsg = const Message(
        id: 502,
        date: 1600000000,
        peerId: 2000000001,
        fromId: 42,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1600000000,
        action: MessageAction(
          type: 'chat_title_update',
          text: 'Секретная конфа',
        ),
      );

      final client = OpenVkClient(userCache: userCache);
      final conv = ConversationItem(
        peerId: 2000000001,
        peerType: 'chat',
        inRead: 0,
        outRead: 0,
        unreadCount: 0,
        isImportant: false,
        isUnanswered: false,
        lastMessage: actionMsg,
      );

      client.messengerStore.getOrCreateConversationNotifier(conv);
      client.messengerStore.conversationOrder.value = [2000000001];

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

      // In the subtitle: "Даня Вишня изменил название беседы на «Секретная конфа»"
      // Without "Даня: Даня Вишня..."
      expect(
        find.textContaining('Даня Вишня изменил название беседы на «Секретная конфа»', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('OpenVK gender declensions (2=он/его, 1=она/её, 0=они/их/неизвестен)', () {
    test('User.genderType resolution from sex and pronouns', () {
      // 2 = он/его
      expect(User.resolveGenderType(sex: 2), 2);
      expect(User.resolveGenderType(pronouns: '2'), 2);
      expect(User.resolveGenderType(pronouns: 'он/его'), 2);
      expect(User.resolveGenderType(pronouns: 'he/him'), 2);

      // 1 = она/её
      expect(User.resolveGenderType(sex: 1), 1);
      expect(User.resolveGenderType(pronouns: '1'), 1);
      expect(User.resolveGenderType(pronouns: 'она/её'), 1);
      expect(User.resolveGenderType(pronouns: 'she/her'), 1);

      // 0 = они/их / неизвестен (типо неуказаны)
      expect(User.resolveGenderType(sex: 0), 0);
      expect(User.resolveGenderType(pronouns: '0'), 0);
      expect(User.resolveGenderType(pronouns: 'они/их'), 0);
      expect(User.resolveGenderType(pronouns: 'they/them'), 0);
      expect(User.resolveGenderType(), 0);
    });

    test('User.fromJson correctly parses pronouns and sex to genderType', () {
      final uMale = User.fromJson({'id': 10, 'first_name': 'Daniel', 'last_name': 'Bogdanovsky', 'sex': 2});
      expect(uMale.genderType, 2);

      final uMalePronouns = User.fromJson({'id': 11, 'first_name': 'Daniel', 'last_name': 'Bogdanovsky', 'pronouns': 'он/его'});
      expect(uMalePronouns.genderType, 2);

      final uFemale = User.fromJson({'id': 12, 'first_name': 'Anna', 'last_name': 'Smirnova', 'sex': 1});
      expect(uFemale.genderType, 1);

      final uNeutral = User.fromJson({'id': 13, 'first_name': 'Alex', 'last_name': 'Doe', 'sex': 0});
      expect(uNeutral.genderType, 0);

      final uUnspecified = User.fromJson({'id': 14, 'first_name': 'Sam', 'last_name': 'Unknown'});
      expect(uUnspecified.genderType, 0);
    });

    test('Declensions for 2 (он/его), 1 (она/её), 0 (они/их) matching Daniel Bogdanovsky actions', () {
      final userCache = UserCache();
      userCache.putUser(const User(
        id: 10,
        firstName: 'Daniel',
        lastName: 'Bogdanovsky',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 2, // он/его
      ));
      userCache.putUser(const User(
        id: 11,
        firstName: 'Анна',
        lastName: 'Смирнова',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 1, // она/её
      ));
      userCache.putUser(const User(
        id: 12,
        firstName: 'Саша',
        lastName: 'Серая',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 0, // они/их (типо неуказаны)
      ));
      userCache.putUser(const User(
        id: 20,
        firstName: 'Дмитрий',
        lastName: 'Владимирович',
        photo50: '',
        photo100: '',
        isOnline: true,
        sex: 2,
      ));

      // 1. chat_invite_user (memberId = currentUserId = 99 -> 'вас')
      final inviteMale = Message(
        id: 1,
        date: 1000,
        peerId: 2000000001,
        fromId: 10,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 1,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_invite_user', memberId: 99),
      );
      expect(
        inviteMale.formatActionText(currentUserId: 99, userCache: userCache),
        'Daniel Bogdanovsky пригласил вас',
      );

      final inviteFemale = Message(
        id: 2,
        date: 1000,
        peerId: 2000000001,
        fromId: 11,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 2,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_invite_user', memberId: 99),
      );
      expect(
        inviteFemale.formatActionText(currentUserId: 99, userCache: userCache),
        'Анна Смирнова пригласила вас',
      );

      final inviteNeutral = Message(
        id: 3,
        date: 1000,
        peerId: 2000000001,
        fromId: 12,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 3,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_invite_user', memberId: 99),
      );
      expect(
        inviteNeutral.formatActionText(currentUserId: 99, userCache: userCache),
        'Саша Серая пригласил(а) вас',
      );

      // 2. chat_moderator_add (memberId = currentUserId = 99 -> 'вас')
      final modAddMale = Message(
        id: 4,
        date: 1000,
        peerId: 2000000001,
        fromId: 10,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 4,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_moderator_add', memberId: 99),
      );
      expect(
        modAddMale.formatActionText(currentUserId: 99, userCache: userCache),
        'Daniel Bogdanovsky назначил вас администратором',
      );

      final modAddFemale = Message(
        id: 5,
        date: 1000,
        peerId: 2000000001,
        fromId: 11,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 5,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_moderator_add', memberId: 99),
      );
      expect(
        modAddFemale.formatActionText(currentUserId: 99, userCache: userCache),
        'Анна Смирнова назначила вас администратором',
      );

      final modAddNeutral = Message(
        id: 6,
        date: 1000,
        peerId: 2000000001,
        fromId: 12,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 6,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_moderator_add', memberId: 99),
      );
      expect(
        modAddNeutral.formatActionText(currentUserId: 99, userCache: userCache),
        'Саша Серая назначил(а) вас администратором',
      );

      // 3. chat_moderator_remove (memberId = 20 -> 'Дмитрий Владимирович')
      final modRemMale = Message(
        id: 7,
        date: 1000,
        peerId: 2000000001,
        fromId: 10,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 7,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_moderator_remove', memberId: 20),
      );
      expect(
        modRemMale.formatActionText(currentUserId: 99, userCache: userCache),
        'Daniel Bogdanovsky снял полномочия администратора с Дмитрий Владимирович',
      );

      final modRemFemale = Message(
        id: 8,
        date: 1000,
        peerId: 2000000001,
        fromId: 11,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 8,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_moderator_remove', memberId: 20),
      );
      expect(
        modRemFemale.formatActionText(currentUserId: 99, userCache: userCache),
        'Анна Смирнова сняла полномочия администратора с Дмитрий Владимирович',
      );

      final modRemNeutral = Message(
        id: 9,
        date: 1000,
        peerId: 2000000001,
        fromId: 12,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: [],
        fwdMessages: [],
        conversationMessageId: 9,
        updateTime: 1000,
        action: const MessageAction(type: 'chat_moderator_remove', memberId: 20),
      );
      expect(
        modRemNeutral.formatActionText(currentUserId: 99, userCache: userCache),
        'Саша Серая снял(а) полномочия администратора с Дмитрий Владимирович',
      );
    });
  });
}
