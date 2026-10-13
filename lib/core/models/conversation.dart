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
  });

  bool get isChat => peerType == 'chat' || peerId > 2000000000;
  bool get isUser => peerType == 'user' && peerId > 0;
  bool get isGroup => peerType == 'group' || peerId < 0;

  bool get isOutRead => lastMessage.isOut && lastMessage.id <= outRead;

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final conv = JsonSafe.toMap(json['conversation']);
    final peer = JsonSafe.toMap(conv['peer']);
    final lastMsgMap = JsonSafe.toMap(json['last_message']);

    return ConversationItem(
      peerId: JsonSafe.toInt(peer['id']),
      peerType: JsonSafe.toStr(peer['type'], 'user'),
      inRead: JsonSafe.toInt(conv['in_read']),
      outRead: JsonSafe.toInt(conv['out_read']),
      unreadCount: JsonSafe.toInt(conv['unread_count']),
      isImportant: JsonSafe.toBool(conv['important']),
      isUnanswered: JsonSafe.toBool(conv['unanswered']),
      chatSettings: conv['chat_settings'] != null
          ? ChatSettings.fromJson(JsonSafe.toMap(conv['chat_settings']))
          : null,
      lastMessage: Message.fromJson(lastMsgMap),
    );
  }
}

class ChatSettings {
  final String title;
  final int membersCount;
  final String state;
  final String photo50;
  final String photo100;
  final int adminId;

  const ChatSettings({
    required this.title,
    required this.membersCount,
    required this.state,
    required this.photo50,
    required this.photo100,
    required this.adminId,
  });

  String get photoUrl => photo100.isNotEmpty ? photo100 : photo50;

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    final photo = JsonSafe.toMap(json['photo']);
    return ChatSettings(
      title: JsonSafe.toStr(json['title'], 'Беседа'),
      membersCount: JsonSafe.toInt(json['members_count']),
      state: JsonSafe.toStr(json['state'], 'in'),
      photo50: JsonSafe.toStr(photo['photo_50']),
      photo100: JsonSafe.toStr(photo['photo_100']),
      adminId: JsonSafe.toInt(json['admin_id']),
    );
  }
}
