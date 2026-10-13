import '../utils/json_safe.dart';
import 'conversation.dart';
import 'group.dart';
import 'user.dart';

class ConversationsResponse {
  final int count;
  final int unreadCount;
  final List<ConversationItem> items;
  final Map<int, User> profiles;
  final Map<int, Group> groups;

  const ConversationsResponse({
    required this.count,
    required this.unreadCount,
    required this.items,
    required this.profiles,
    required this.groups,
  });

  String getTitle(ConversationItem item) {
    if (item.isChat) {
      final title = item.chatSettings?.title;
      if (title != null && title.isNotEmpty) return title;
      return 'Беседа #${item.peerId - 2000000000}';
    }

    if (item.isGroup) {
      final groupId = item.peerId.abs();
      return groups[groupId]?.name ?? 'Сообщество #$groupId';
    }

    final user = profiles[item.peerId];
    if (user != null) return user.fullName;

    return 'Пользователь #${item.peerId}';
  }

  String? getAvatarUrl(ConversationItem item) {
    if (item.isChat) {
      final photo = item.chatSettings?.photoUrl;
      if (photo != null && photo.isNotEmpty) return photo;
      return null;
    }

    if (item.isGroup) {
      return groups[item.peerId.abs()]?.avatarUrl;
    }

    return profiles[item.peerId]?.avatarUrl;
  }

  factory ConversationsResponse.fromJson(Map<String, dynamic> json) {
    final rawProfiles = JsonSafe.toList(
      json['profiles'],
      (p) => User.fromJson(JsonSafe.toMap(p)),
    );
    final profilesMap = {for (var u in rawProfiles) u.id: u};

    final rawGroups = JsonSafe.toList(
      json['groups'],
      (g) => Group.fromJson(JsonSafe.toMap(g)),
    );
    final groupsMap = {for (var g in rawGroups) g.id: g};

    final items = JsonSafe.toList(
      json['items'],
      (i) => ConversationItem.fromJson(JsonSafe.toMap(i)),
    );

    return ConversationsResponse(
      count: JsonSafe.toInt(json['count']),
      unreadCount: JsonSafe.toInt(json['unread_count']),
      items: items,
      profiles: profilesMap,
      groups: groupsMap,
    );
  }

  factory ConversationsResponse.empty() => const ConversationsResponse(
    count: 0,
    unreadCount: 0,
    items: [],
    profiles: {},
    groups: {},
  );
}
