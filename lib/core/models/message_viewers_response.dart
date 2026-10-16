import '../utils/json_safe.dart';
import 'user.dart';

class MessageViewerItem {
  final int userId;
  final int lastReadId;

  const MessageViewerItem({
    required this.userId,
    required this.lastReadId,
  });

  factory MessageViewerItem.fromJson(Map<String, dynamic> json) {
    return MessageViewerItem(
      userId: JsonSafe.toInt(json['user_id']),
      lastReadId: JsonSafe.toInt(json['last_read_id']),
    );
  }
}

class MessageViewersResponse {
  final int count;
  final List<MessageViewerItem> items;
  final List<int> userIds;
  final List<User> profiles;

  const MessageViewersResponse({
    required this.count,
    required this.items,
    this.userIds = const [],
    this.profiles = const [],
  });

  factory MessageViewersResponse.fromJson(Map<String, dynamic> json) {
    final count = JsonSafe.toInt(json['count']);

    final items = JsonSafe.toList(
      json['items'],
      (it) => MessageViewerItem.fromJson(JsonSafe.toMap(it)),
    );

    final userIds = JsonSafe.toList(
      json['user_ids'],
      (id) => JsonSafe.toInt(id),
    );

    final profiles = JsonSafe.toList(
      json['profiles'],
      (p) => User.fromJson(JsonSafe.toMap(p)),
    );

    return MessageViewersResponse(
      count: count,
      items: items,
      userIds: userIds,
      profiles: profiles,
    );
  }

  factory MessageViewersResponse.empty() =>
      const MessageViewersResponse(count: 0, items: []);
}
