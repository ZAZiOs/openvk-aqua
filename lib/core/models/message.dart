import '../cache/user_cache.dart';
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
  final bool isUnread;
  final List<Attachment> attachments;
  final List<Message> fwdMessages;
  final Message? replyMessage;
  final int? replyMessageId;
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
    this.isUnread = false,
    required this.attachments,
    required this.fwdMessages,
    this.replyMessage,
    this.replyMessageId,
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

  bool get isSticker =>
      attachments.isNotEmpty &&
      attachments.first.type == 'sticker' &&
      text.isEmpty;

  StickerAttachment? get stickerAttachment =>
      attachments.where((a) => a.type == 'sticker').firstOrNull?.sticker;

  bool get hasGift =>
      attachments.isNotEmpty && attachments.any((a) => a.type == 'gift');

  GiftAttachment? get giftAttachment =>
      attachments.where((a) => a.type == 'gift').firstOrNull?.gift;

  bool get isAction => action != null;

  String formatActionText({int? currentUserId, UserCache? userCache}) {
    if (action == null) return text;

    String? actorName;
    int? actorSex;
    String? memberName;

    if (userCache != null) {
      if (fromId > 0) {
        final u = userCache.getUser(fromId);
        if (u != null) {
          actorName = u.fullName.isNotEmpty ? u.fullName : u.firstName;
          actorSex = u.genderType;
        } else {
          userCache.requestUser(fromId);
        }
      } else if (fromId < 0) {
        final g = userCache.getGroup(fromId.abs());
        if (g != null) {
          actorName = g.name;
        } else {
          userCache.requestGroup(fromId.abs());
        }
      }

      if (action!.memberId > 0) {
        final m = userCache.getUser(action!.memberId);
        if (m != null) {
          memberName = m.fullName.isNotEmpty ? m.fullName : m.firstName;
        } else {
          userCache.requestUser(action!.memberId);
        }
      } else if (action!.memberId < 0) {
        final g = userCache.getGroup(action!.memberId.abs());
        if (g != null) {
          memberName = g.name;
        } else {
          userCache.requestGroup(action!.memberId.abs());
        }
      }
    }

    return action!.formatText(
      fromId: fromId,
      currentUserId: currentUserId,
      actorName: actorName,
      memberName: memberName,
      actorSex: actorSex,
      actorGenderType: actorSex,
    );
  }

  String get previewText {
    if (action != null) {
      return formatActionText();
    }
    if (hasGift) {
      final g = giftAttachment;
      if (text.isNotEmpty) return text;
      if (g != null && g.message.isNotEmpty) return g.message;
      return '[Подарок]';
    }
    if (text.isNotEmpty) return text;
    if (attachments.isNotEmpty) return attachments.first.summaryText;
    if (fwdMessages.isNotEmpty) return '[Пересланные сообщения]';
    if (replyMessage != null || replyMessageId != null) return '[Ответ]';
    return '...';
  }

  Message copyWith({
    int? id,
    int? date,
    int? peerId,
    int? fromId,
    String? text,
    bool? isOut,
    bool? isImportant,
    bool? isUnread,
    List<Attachment>? attachments,
    List<Message>? fwdMessages,
    Message? replyMessage,
    int? replyMessageId,
    MessageAction? action,
    int? conversationMessageId,
    int? updateTime,
  }) {
    return Message(
      id: id ?? this.id,
      date: date ?? this.date,
      peerId: peerId ?? this.peerId,
      fromId: fromId ?? this.fromId,
      text: text ?? this.text,
      isOut: isOut ?? this.isOut,
      isImportant: isImportant ?? this.isImportant,
      isUnread: isUnread ?? this.isUnread,
      attachments: attachments ?? this.attachments,
      fwdMessages: fwdMessages ?? this.fwdMessages,
      replyMessage: replyMessage ?? this.replyMessage,
      replyMessageId: replyMessageId ?? this.replyMessageId,
      action: action ?? this.action,
      conversationMessageId:
          conversationMessageId ?? this.conversationMessageId,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final parsedReplyMsg = json['reply_message'] != null
        ? Message.fromJson(JsonSafe.toMap(json['reply_message']))
        : null;
    final parsedReplyId = parsedReplyMsg?.id ??
        (json['reply_to'] != null
            ? int.tryParse(json['reply_to'].toString())
            : (json['reply'] != null
                ? int.tryParse(json['reply'].toString())
                : (json['reply_message_id'] != null
                    ? int.tryParse(json['reply_message_id'].toString())
                    : null)));

    final parsedAction = json['action'] != null
        ? MessageAction.fromJson(JsonSafe.toMap(json['action']))
        : (json['source_act'] != null
            ? MessageAction.fromJson(json)
            : null);

    return Message(
      id: JsonSafe.toInt(json['id']),
      date: JsonSafe.toInt(json['date']),
      peerId: JsonSafe.toInt(json['peer_id']),
      fromId: JsonSafe.toInt(json['from_id']),
      text: JsonSafe.toStr(json['text']),
      isOut: JsonSafe.toBool(json['out']),
      isImportant: JsonSafe.toBool(json['important']),
      isUnread: JsonSafe.toBool(json['unread']) ||
          ((JsonSafe.toInt(json['flags']) & 1) != 0),
      attachments: JsonSafe.toList(
        json['attachments'],
        (a) => Attachment.fromJson(JsonSafe.toMap(a)),
      ),
      fwdMessages: JsonSafe.toList(
        json['fwd_messages'],
        (f) => Message.fromJson(JsonSafe.toMap(f)),
      ),
      replyMessage: parsedReplyMsg,
      replyMessageId: parsedReplyId,
      action: parsedAction,
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
    isUnread: false,
    attachments: [],
    fwdMessages: [],
    replyMessage: null,
    replyMessageId: null,
    conversationMessageId: 0,
    updateTime: 0,
  );
}

class MessageAction {
  final String type;
  final int memberId;
  final String text;
  final String email;
  final Map<String, dynamic>? photo;
  final int conversationMessageId;

  const MessageAction({
    required this.type,
    this.memberId = 0,
    this.text = '',
    this.email = '',
    this.photo,
    this.conversationMessageId = 0,
  });

  factory MessageAction.fromJson(Map<String, dynamic> json) {
    return MessageAction(
      type: JsonSafe.toStr(json['type'] ?? json['source_act'] ?? json['act']),
      memberId: JsonSafe.toInt(
        json['member_id'] ?? json['source_mid'] ?? json['mid'],
      ),
      text: JsonSafe.toStr(
        json['text'] ?? json['source_text'] ?? json['source_old_text'],
      ),
      email: JsonSafe.toStr(json['email']),
      photo: json['photo'] is Map<String, dynamic> ? json['photo'] : null,
      conversationMessageId: JsonSafe.toInt(
        json['conversation_message_id'] ?? json['conversation_msg_id'],
      ),
    );
  }

  static String _verb({
    required bool isSelf,
    required int? genderType,
    required String self,
    required String male,
    required String female,
    String? neutral,
  }) {
    if (isSelf) return self;
    if (genderType == 2) return male;
    if (genderType == 1) return female;
    return neutral ?? '$male(а)';
  }

  String formatText({
    int fromId = 0,
    int? currentUserId,
    String? actorName,
    String? memberName,
    int? actorSex,
    int? actorGenderType,
  }) {
    final int? gender = actorGenderType ?? actorSex;
    final bool isSelf =
        (currentUserId != null && fromId != 0 && fromId == currentUserId);
    final String actor = isSelf
        ? 'Вы'
        : (actorName ?? (fromId > 0 ? 'id$fromId' : 'Пользователь'));

    switch (type) {
      case 'chat_create':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'создали',
          male: 'создал',
          female: 'создала',
        );
        final title = text.isNotEmpty ? ' «$text»' : '';
        return '$actor $v беседу$title';

      case 'chat_title_update':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'изменили',
          male: 'изменил',
          female: 'изменила',
        );
        final title = text.isNotEmpty ? ' на «$text»' : '';
        return '$actor $v название беседы$title';

      case 'chat_photo_update':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'обновили',
          male: 'обновил',
          female: 'обновила',
        );
        return '$actor $v фотографию беседы';

      case 'chat_photo_remove':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'удалили',
          male: 'удалил',
          female: 'удалила',
        );
        return '$actor $v фотографию беседы';

      case 'chat_invite_user':
        if (memberId == fromId && memberId != 0) {
          final v = _verb(
            isSelf: isSelf,
            genderType: gender,
            self: 'вернулись',
            male: 'вернулся',
            female: 'вернулась',
            neutral: 'вернулся(лась)',
          );
          return '$actor $v в беседу';
        } else {
          final v = _verb(
            isSelf: isSelf,
            genderType: gender,
            self: 'пригласили',
            male: 'пригласил',
            female: 'пригласила',
          );
          final target = (currentUserId != null && memberId == currentUserId)
              ? 'вас'
              : (memberName != null && memberName.isNotEmpty
                  ? memberName
                  : (memberId > 0 ? 'пользователя id$memberId' : 'пользователя'));
          return '$actor $v $target';
        }

      case 'chat_kick_user':
        if (memberId == fromId && memberId != 0) {
          final v = _verb(
            isSelf: isSelf,
            genderType: gender,
            self: 'покинули',
            male: 'покинул',
            female: 'покинула',
            neutral: 'покинул(а)',
          );
          return '$actor $v беседу';
        } else {
          final v = _verb(
            isSelf: isSelf,
            genderType: gender,
            self: 'исключили',
            male: 'исключил',
            female: 'исключила',
          );
          final target = (currentUserId != null && memberId == currentUserId)
              ? 'вас'
              : (memberName != null && memberName.isNotEmpty
                  ? memberName
                  : (memberId > 0 ? 'пользователя id$memberId' : 'пользователя'));
          return '$actor $v $target';
        }

      case 'chat_pin_message':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'закрепили',
          male: 'закрепил',
          female: 'закрепила',
        );
        return '$actor $v сообщение';

      case 'chat_unpin_message':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'открепили',
          male: 'открепил',
          female: 'открепила',
        );
        return '$actor $v сообщение';

      case 'chat_invite_user_by_link':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'присоединились',
          male: 'присоединился',
          female: 'присоединилась',
          neutral: 'присоединился(лась)',
        );
        return '$actor $v к беседе по ссылке';

      case 'chat_moderator_add':
      case 'chat_admin_add':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'назначили',
          male: 'назначил',
          female: 'назначила',
        );
        if (memberId == fromId && memberId != 0) {
          return isSelf
              ? 'Вы назначили себя администратором'
              : '$actor $v себя администратором';
        }
        final target = (currentUserId != null && memberId == currentUserId)
            ? 'вас'
            : (memberName != null && memberName.isNotEmpty
                ? memberName
                : (memberId > 0 ? 'пользователя id$memberId' : 'пользователя'));
        return '$actor $v $target администратором';

      case 'chat_moderator_remove':
      case 'chat_admin_remove':
        final v = _verb(
          isSelf: isSelf,
          genderType: gender,
          self: 'сняли',
          male: 'снял',
          female: 'сняла',
        );
        if (memberId == fromId && memberId != 0) {
          return isSelf
              ? 'Вы сняли с себя полномочия администратора'
              : '$actor $v с себя полномочия администратора';
        }
        final target = (currentUserId != null && memberId == currentUserId)
            ? 'с вас'
            : (memberName != null && memberName.isNotEmpty
                ? 'с $memberName'
                : (memberId > 0 ? 'с пользователя id$memberId' : 'с пользователя'));
        return '$actor $v полномочия администратора $target';

      default:
        if (text.isNotEmpty) return text;
        return 'Системное действие';
    }
  }

  String get description => formatText();
}
