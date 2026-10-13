import '../utils/json_safe.dart';
import 'attachment.dart';

class Message {
  final int id;
  final int date;
  final int peerId;
  final int fromId;
  final String text;
  final bool isOut;
  final bool isImportant;
  final List<Attachment> attachments;
  final List<Message> fwdMessages;
  final Message? replyMessage;
  final MessageAction? action;
  final int conversationMessageId;
  final int updateTime;

  const Message({
    required this.id,
    required this.date,
    required this.peerId,
    required this.fromId,
    required this.text,
    required this.isOut,
    required this.isImportant,
    required this.attachments,
    required this.fwdMessages,
    this.replyMessage,
    this.action,
    required this.conversationMessageId,
    required this.updateTime,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(date * 1000);

  String get timeString {
    final dt = dateTime;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get previewText {
    if (text.isNotEmpty) return text;
    if (attachments.isNotEmpty) return attachments.first.summaryText;
    if (fwdMessages.isNotEmpty) return '[Пересланные сообщения]';
    if (action != null) return action!.description;
    return '...';
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: JsonSafe.toInt(json['id']),
      date: JsonSafe.toInt(json['date']),
      peerId: JsonSafe.toInt(json['peer_id']),
      fromId: JsonSafe.toInt(json['from_id']),
      text: JsonSafe.toStr(json['text']),
      isOut: JsonSafe.toBool(json['out']),
      isImportant: JsonSafe.toBool(json['important']),
      attachments: JsonSafe.toList(
        json['attachments'],
        (a) => Attachment.fromJson(JsonSafe.toMap(a)),
      ),
      fwdMessages: JsonSafe.toList(
        json['fwd_messages'],
        (f) => Message.fromJson(JsonSafe.toMap(f)),
      ),
      replyMessage: json['reply_message'] != null
          ? Message.fromJson(JsonSafe.toMap(json['reply_message']))
          : null,
      action: json['action'] != null
          ? MessageAction.fromJson(JsonSafe.toMap(json['action']))
          : null,
      conversationMessageId: JsonSafe.toInt(json['conversation_message_id']),
      updateTime: JsonSafe.toInt(json['update_time']),
    );
  }

  factory Message.empty() => const Message(
    id: 0,
    date: 0,
    peerId: 0,
    fromId: 0,
    text: '',
    isOut: false,
    isImportant: false,
    attachments: [],
    fwdMessages: [],
    conversationMessageId: 0,
    updateTime: 0,
  );
}

class MessageAction {
  final String type;
  final int memberId;
  final String text;

  const MessageAction({
    required this.type,
    required this.memberId,
    required this.text,
  });

  factory MessageAction.fromJson(Map<String, dynamic> json) {
    return MessageAction(
      type: JsonSafe.toStr(json['type']),
      memberId: JsonSafe.toInt(json['member_id']),
      text: JsonSafe.toStr(json['text']),
    );
  }

  String get description {
    return switch (type) {
      'chat_create' => 'Создана беседа "$text"',
      'chat_title_update' => 'Название изменено на "$text"',
      'chat_photo_update' => 'Обновлена обложка беседы',
      'chat_photo_remove' => 'Удалена обложка беседы',
      'chat_invite_user' => 'Приглашён пользователь',
      'chat_kick_user' => 'Пользователь исключён',
      'chat_pin_message' => 'Сообщение закреплено',
      'chat_unpin_message' => 'Сообщение откреплено',
      'chat_invite_user_by_link' => 'Вход по ссылке-приглашению',
      _ => 'Системное действие',
    };
  }
}
