import '../utils/json_safe.dart';
import 'attachment.dart';
import 'group.dart';
import 'user.dart';

class Post {
  final int id;
  final int ownerId;
  final int fromId;
  final int date;
  final String text;
  final int? replyOwnerId;
  final int? replyPostId;
  final bool friendsOnly;
  final int commentsCount;
  final bool canPostComments;
  final int likesCount;
  final bool userLikes;
  final bool canLike;
  final bool canPublish;
  final int repostsCount;
  final bool userReposted;
  final String postType;
  final List<Attachment> attachments;
  final List<Post> copyHistory;
  final User? author;
  final Group? authorGroup;
  final bool isPinned;
  final User? wallOwner;
  final Group? wallOwnerGroup;

  const Post({
    required this.id,
    required this.ownerId,
    required this.fromId,
    required this.date,
    required this.text,
    this.replyOwnerId,
    this.replyPostId,
    this.friendsOnly = false,
    this.commentsCount = 0,
    this.canPostComments = true,
    this.likesCount = 0,
    this.userLikes = false,
    this.canLike = true,
    this.canPublish = true,
    this.repostsCount = 0,
    this.userReposted = false,
    this.postType = 'post',
    this.attachments = const [],
    this.copyHistory = const [],
    this.author,
    this.authorGroup,
    this.isPinned = false,
    this.wallOwner,
    this.wallOwnerGroup,
  });

  bool get isCommunity => fromId < 0 || authorGroup != null;

  String get authorName {
    if (authorGroup != null) return authorGroup!.name;
    if (author != null) return author!.fullName;
    return 'Пользователь';
  }

  String get wallOwnerName {
    if (wallOwnerGroup != null) return wallOwnerGroup!.name;
    if (wallOwner != null) return wallOwner!.fullName;
    return '';
  }

  String get authorAvatarUrl {
    if (authorGroup != null) return authorGroup!.avatarUrl;
    if (author != null) return author!.avatarUrl;
    return '';
  }

  Post copyWith({
    int? likesCount,
    bool? userLikes,
    int? commentsCount,
    int? repostsCount,
    bool? userReposted,
    User? author,
    Group? authorGroup,
    bool? isPinned,
    User? wallOwner,
    Group? wallOwnerGroup,
  }) {
    return Post(
      id: id,
      ownerId: ownerId,
      fromId: fromId,
      date: date,
      text: text,
      replyOwnerId: replyOwnerId,
      replyPostId: replyPostId,
      friendsOnly: friendsOnly,
      commentsCount: commentsCount ?? this.commentsCount,
      canPostComments: canPostComments,
      likesCount: likesCount ?? this.likesCount,
      userLikes: userLikes ?? this.userLikes,
      canLike: canLike,
      canPublish: canPublish,
      repostsCount: repostsCount ?? this.repostsCount,
      userReposted: userReposted ?? this.userReposted,
      postType: postType,
      attachments: attachments,
      copyHistory: copyHistory,
      author: author ?? this.author,
      authorGroup: authorGroup ?? this.authorGroup,
      isPinned: isPinned ?? this.isPinned,
      wallOwner: wallOwner ?? this.wallOwner,
      wallOwnerGroup: wallOwnerGroup ?? this.wallOwnerGroup,
    );
  }

  factory Post.fromJson(
    Map<String, dynamic> json, {
    Map<int, User>? usersMap,
    Map<int, Group>? groupsMap,
  }) {
    final sourceId = json['source_id'];
    final fromId = JsonSafe.toInt(json['from_id'] ?? sourceId);
    final ownerId = JsonSafe.toInt(json['owner_id'] ?? sourceId);
    final id = JsonSafe.toInt(json['id'] ?? json['post_id']);

    // Comments map
    final comments = json['comments'] is Map ? json['comments'] : null;
    final commentsCount = comments != null ? JsonSafe.toInt(comments['count']) : 0;
    final canPost = comments != null ? JsonSafe.toBool(comments['can_post'], true) : true;

    // Likes map
    final likes = json['likes'] is Map ? json['likes'] : null;
    final likesCount = likes != null ? JsonSafe.toInt(likes['count']) : 0;
    final userLikes = likes != null ? JsonSafe.toBool(likes['user_likes']) : false;
    final canLike = likes != null ? JsonSafe.toBool(likes['can_like'], true) : true;
    final canPublish = likes != null ? JsonSafe.toBool(likes['can_publish'], true) : true;

    // Reposts map
    final reposts = json['reposts'] is Map ? json['reposts'] : null;
    final repostsCount = reposts != null ? JsonSafe.toInt(reposts['count']) : 0;
    final userReposted = reposts != null ? JsonSafe.toBool(reposts['user_reposted']) : false;

    // Attachments
    final attachments = JsonSafe.toList(
      json['attachments'],
      (att) => Attachment.fromJson(JsonSafe.toMap(att)),
    );

    // Copy history (reposts)
    final copyHistory = JsonSafe.toList(
      json['copy_history'],
      (c) => Post.fromJson(JsonSafe.toMap(c), usersMap: usersMap, groupsMap: groupsMap),
    );

    // Resolve author
    User? author;
    Group? group;
    if (fromId > 0) {
      author = usersMap?[fromId];
    } else if (fromId < 0) {
      group = groupsMap?[fromId.abs()];
    }

    // Resolve wall owner
    User? wallOwner;
    Group? wallOwnerGroup;
    if (ownerId > 0) {
      wallOwner = usersMap?[ownerId];
    } else if (ownerId < 0) {
      wallOwnerGroup = groupsMap?[ownerId.abs()];
    }

    final isPinned = JsonSafe.toBool(json['is_pinned']);

    return Post(
      id: id,
      ownerId: ownerId,
      fromId: fromId,
      date: JsonSafe.toInt(json['date']),
      text: JsonSafe.toStr(json['text']),
      replyOwnerId: json['reply_owner_id'] != null ? JsonSafe.toInt(json['reply_owner_id']) : null,
      replyPostId: json['reply_post_id'] != null ? JsonSafe.toInt(json['reply_post_id']) : null,
      friendsOnly: JsonSafe.toBool(json['friends_only']),
      commentsCount: commentsCount,
      canPostComments: canPost,
      likesCount: likesCount,
      userLikes: userLikes,
      canLike: canLike,
      canPublish: canPublish,
      repostsCount: repostsCount,
      userReposted: userReposted,
      postType: JsonSafe.toStr(json['post_type'] ?? json['type'], 'post'),
      attachments: attachments,
      copyHistory: copyHistory,
      author: author,
      authorGroup: group,
      isPinned: isPinned,
      wallOwner: wallOwner,
      wallOwnerGroup: wallOwnerGroup,
    );
  }
}
