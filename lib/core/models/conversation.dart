import '../utils/json_safe.dart';
import 'message.dart';

class ConversationItem {
  final int peerId;
  final String peerType;
  final int inRead;
  final int outRead;
  final int unreadCount;
  final bool isImportant;
  final bool isUnanswered;
  final ChatSettings? chatSettings;
  final Message lastMessage;
  final Message? pinnedMessage;

  const ConversationItem({
    required this.peerId,
    required this.peerType,
    required this.inRead,
    required this.outRead,
    required this.unreadCount,
    required this.isImportant,
    required this.isUnanswered,
    this.chatSettings,
    required this.lastMessage,
    this.pinnedMessage,
  });

  bool get isChat => peerType == 'chat' || peerId > 2000000000;
  bool get isUser => peerType == 'user' && peerId > 0;
  bool get isGroup => peerType == 'group' || peerId < 0;

  bool get isOutRead => lastMessage.isOut && lastMessage.id <= outRead;

  Message? get activePinnedMessage => pinnedMessage ?? chatSettings?.pinnedMessage;

  ConversationItem copyWith({
    int? peerId,
    String? peerType,
    int? inRead,
    int? outRead,
    int? unreadCount,
    bool? isImportant,
    bool? isUnanswered,
    ChatSettings? chatSettings,
    Message? lastMessage,
    Message? pinnedMessage,
    bool clearPinnedMessage = false,
  }) {
    return ConversationItem(
      peerId: peerId ?? this.peerId,
      peerType: peerType ?? this.peerType,
      inRead: inRead ?? this.inRead,
      outRead: outRead ?? this.outRead,
      unreadCount: unreadCount ?? this.unreadCount,
      isImportant: isImportant ?? this.isImportant,
      isUnanswered: isUnanswered ?? this.isUnanswered,
      chatSettings: chatSettings ?? this.chatSettings,
      lastMessage: lastMessage ?? this.lastMessage,
      pinnedMessage: clearPinnedMessage ? null : (pinnedMessage ?? this.pinnedMessage),
    );
  }

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final conv = JsonSafe.toMap(json['conversation']);
    final peer = JsonSafe.toMap(conv['peer']);
    final lastMsgMap = JsonSafe.toMap(json['last_message']);
    final chatSettings = conv['chat_settings'] != null
        ? ChatSettings.fromJson(JsonSafe.toMap(conv['chat_settings']))
        : null;

    final convPinned = conv['pinned_message'] is Map
        ? Message.fromJson(Map<String, dynamic>.from(conv['pinned_message'] as Map))
        : (json['pinned_message'] is Map
            ? Message.fromJson(Map<String, dynamic>.from(json['pinned_message'] as Map))
            : null);

    return ConversationItem(
      peerId: JsonSafe.toInt(peer['id']),
      peerType: JsonSafe.toStr(peer['type'], 'user'),
      inRead: JsonSafe.toInt(conv['in_read']),
      outRead: JsonSafe.toInt(conv['out_read']),
      unreadCount: JsonSafe.toInt(conv['unread_count']),
      isImportant: JsonSafe.toBool(conv['important']),
      isUnanswered: JsonSafe.toBool(conv['unanswered']),
      chatSettings: chatSettings,
      lastMessage: Message.fromJson(lastMsgMap),
      pinnedMessage: chatSettings?.pinnedMessage ?? convPinned,
    );
  }
}

class ChatSettings {
  final String title;
  final int membersCount;
  final String state;
  final String photo50;
  final String photo100;
  final String photo200;
  final List<int> activeIds;
  final int adminId;
  final Message? pinnedMessage;

  const ChatSettings({
    required this.title,
    required this.membersCount,
    required this.state,
    required this.photo50,
    required this.photo100,
    this.photo200 = '',
    this.activeIds = const [],
    required this.adminId,
    this.pinnedMessage,
  });

  String get photoUrl =>
      photo200.isNotEmpty ? photo200 : (photo100.isNotEmpty ? photo100 : photo50);

  bool get hasPhoto => photoUrl.isNotEmpty;

  ChatSettings copyWith({
    String? title,
    int? membersCount,
    String? state,
    String? photo50,
    String? photo100,
    String? photo200,
    List<int>? activeIds,
    int? adminId,
    Message? pinnedMessage,
    bool clearPinnedMessage = false,
  }) {
    return ChatSettings(
      title: title ?? this.title,
      membersCount: membersCount ?? this.membersCount,
      state: state ?? this.state,
      photo50: photo50 ?? this.photo50,
      photo100: photo100 ?? this.photo100,
      photo200: photo200 ?? this.photo200,
      activeIds: activeIds ?? this.activeIds,
      adminId: adminId ?? this.adminId,
      pinnedMessage: clearPinnedMessage ? null : (pinnedMessage ?? this.pinnedMessage),
    );
  }

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    final photo = JsonSafe.toMap(json['photo']);
    final pinned = json['pinned_message'] is Map
        ? Message.fromJson(Map<String, dynamic>.from(json['pinned_message'] as Map))
        : null;

    return ChatSettings(
      title: JsonSafe.toStr(json['title'], 'Беседа'),
      membersCount: JsonSafe.toInt(json['members_count']),
      state: JsonSafe.toStr(json['state'], 'in'),
      photo50: JsonSafe.toStr(photo['photo_50']),
      photo100: JsonSafe.toStr(photo['photo_100']),
      photo200: JsonSafe.toStr(photo['photo_200']),
      activeIds: JsonSafe.toList(json['active_ids'], (id) => JsonSafe.toInt(id)),
      adminId: JsonSafe.toInt(json['admin_id']),
      pinnedMessage: pinned,
    );
  }
}

class Chat {
  final int id;
  final String type;
  final String title;
  final int adminId;
  final List<int> users;
  final String photo50;
  final String photo100;
  final String photo200;

  const Chat({
    required this.id,
    this.type = 'chat',
    required this.title,
    required this.adminId,
    this.users = const [],
    this.photo50 = '',
    this.photo100 = '',
    this.photo200 = '',
  });

  String get photoUrl =>
      photo200.isNotEmpty ? photo200 : (photo100.isNotEmpty ? photo100 : photo50);

  bool get hasPhoto => photoUrl.isNotEmpty;

  factory Chat.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    final usersList = <int>[];
    if (rawUsers is List) {
      for (final u in rawUsers) {
        if (u is Map) {
          usersList.add(JsonSafe.toInt(u['id']));
        } else {
          usersList.add(JsonSafe.toInt(u));
        }
      }
    }

    return Chat(
      id: JsonSafe.toInt(json['id']),
      type: JsonSafe.toStr(json['type'], 'chat'),
      title: JsonSafe.toStr(json['title'], 'Беседа'),
      adminId: JsonSafe.toInt(json['admin_id']),
      users: usersList,
      photo50: JsonSafe.toStr(json['photo_50']),
      photo100: JsonSafe.toStr(json['photo_100']),
      photo200: JsonSafe.toStr(json['photo_200']),
    );
  }
}
