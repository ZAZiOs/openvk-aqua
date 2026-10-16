import '../utils/json_safe.dart';
import 'attachment.dart';
import 'group.dart';
import 'user.dart';

class PostComment {
  final int id;
  final int fromId;
  final int date;
  final String text;
  final int? replyToUser;
  final int? replyToComment;
  final List<Attachment> attachments;
  final int likesCount;
  final bool userLikes;
  final bool canLike;
  final User? author;
  final Group? authorGroup;

  const PostComment({
    required this.id,
    required this.fromId,
    required this.date,
    required this.text,
    this.replyToUser,
    this.replyToComment,
    this.attachments = const [],
    this.likesCount = 0,
    this.userLikes = false,
    this.canLike = true,
    this.author,
    this.authorGroup,
  });

  bool get isCommunity => fromId < 0 || authorGroup != null;

  String get authorName {
    if (authorGroup != null) return authorGroup!.name;
    if (author != null) return author!.fullName;
    return 'Пользователь';
  }

  String get authorAvatarUrl {
    if (authorGroup != null) return authorGroup!.avatarUrl;
    if (author != null) return author!.avatarUrl;
    return '';
  }

  PostComment copyWith({
    int? likesCount,
    bool? userLikes,
    bool? canLike,
    User? author,
    Group? authorGroup,
  }) {
    return PostComment(
      id: id,
      fromId: fromId,
      date: date,
      text: text,
      replyToUser: replyToUser,
      replyToComment: replyToComment,
      attachments: attachments,
      likesCount: likesCount ?? this.likesCount,
      userLikes: userLikes ?? this.userLikes,
      canLike: canLike ?? this.canLike,
      author: author ?? this.author,
      authorGroup: authorGroup ?? this.authorGroup,
    );
  }

  factory PostComment.fromJson(
    Map<String, dynamic> json, {
    Map<int, User>? usersMap,
    Map<int, Group>? groupsMap,
  }) {
    final id = JsonSafe.toInt(json['id'] ?? json['comment_id']);
    final fromId =
        JsonSafe.toInt(json['from_id'] ?? json['user_id'] ?? json['author_id']);
    final date = JsonSafe.toInt(json['date']);
    final text = JsonSafe.toStr(json['text']);
    final replyToUser = json['reply_to_user'] != null
        ? JsonSafe.toInt(json['reply_to_user'])
        : null;
    final replyToComment = json['reply_to_comment'] != null
        ? JsonSafe.toInt(json['reply_to_comment'])
        : null;

    final likes = json['likes'] is Map ? json['likes'] as Map : null;
    final likesCount = likes != null ? JsonSafe.toInt(likes['count']) : 0;
    final userLikes =
        likes != null ? JsonSafe.toBool(likes['user_likes']) : false;
    final canLike =
        likes != null ? JsonSafe.toBool(likes['can_like'], true) : true;

    final attachments = JsonSafe.toList(
      json['attachments'],
      (att) => Attachment.fromJson(JsonSafe.toMap(att)),
    );

    User? author;
    Group? authorGroup;
    if (fromId > 0) {
      author = usersMap?[fromId];
    } else if (fromId < 0) {
      authorGroup = groupsMap?[fromId.abs()];
    }

    return PostComment(
      id: id,
      fromId: fromId,
      date: date,
      text: text,
      replyToUser: replyToUser,
      replyToComment: replyToComment,
      attachments: attachments,
      likesCount: likesCount,
      userLikes: userLikes,
      canLike: canLike,
      author: author,
      authorGroup: authorGroup,
    );
  }
}
