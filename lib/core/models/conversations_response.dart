import '../utils/json_safe.dart';
import 'conversation.dart';
import 'group.dart';
import 'user.dart';

class ChatMemberAvatarInfo {
  final String? url;
  final String fallbackText;

  const ChatMemberAvatarInfo({this.url, required this.fallbackText});
}

class ConversationsResponse {
  final int count;
  final int unreadCount;
  final List<ConversationItem> items;
  final Map<int, User> profiles;
  final Map<int, Group> groups;
  final Map<int, Chat> chats;

  const ConversationsResponse({
    required this.count,
    required this.unreadCount,
    required this.items,
    required this.profiles,
    required this.groups,
    this.chats = const {},
  });

  String getTitle(ConversationItem item) {
    if (item.isChat) {
      final title = item.chatSettings?.title;
      if (title != null && title.isNotEmpty) return title;
      final chatId = item.peerId > 2000000000 ? item.peerId - 2000000000 : item.peerId;
      final chat = chats[chatId] ?? chats[item.peerId];
      if (chat != null && chat.title.isNotEmpty) return chat.title;
      return 'Беседа #$chatId';
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
      final chatId = item.peerId > 2000000000 ? item.peerId - 2000000000 : item.peerId;
      final chat = chats[chatId] ?? chats[item.peerId];
      if (chat != null && chat.photoUrl.isNotEmpty) return chat.photoUrl;
      return null;
    }

    if (item.isGroup) {
      return groups[item.peerId.abs()]?.avatarUrl;
    }

    return profiles[item.peerId]?.avatarUrl;
  }

  List<ChatMemberAvatarInfo> getChatMemberAvatars(
    ConversationItem item, {
    int maxCount = 4,
  }) {
    if (!item.isChat) return const [];

    final chatId = item.peerId > 2000000000 ? item.peerId - 2000000000 : item.peerId;
    final chatObj = chats[chatId] ?? chats[item.peerId];

    final candidateIds = <int>[];

    if (item.chatSettings != null && item.chatSettings!.activeIds.isNotEmpty) {
      candidateIds.addAll(item.chatSettings!.activeIds);
    }

    if (chatObj != null && chatObj.users.isNotEmpty) {
      candidateIds.addAll(chatObj.users);
    }

    if (item.lastMessage.fromId != 0) {
      candidateIds.add(item.lastMessage.fromId);
    }

    final seen = <int>{};
    final uniqueIds = <int>[];
    for (final id in candidateIds) {
      if (id != 0 && seen.add(id)) {
        uniqueIds.add(id);
      }
    }

    final result = <ChatMemberAvatarInfo>[];
    for (final id in uniqueIds) {
      if (result.length >= maxCount) break;

      if (id > 0) {
        final user = profiles[id];
        if (user != null) {
          result.add(
            ChatMemberAvatarInfo(
              url: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
              fallbackText: user.firstName.isNotEmpty ? user.firstName : '?',
            ),
          );
        } else {
          result.add(
            const ChatMemberAvatarInfo(url: null, fallbackText: '?'),
          );
        }
      } else {
        final group = groups[id.abs()];
        if (group != null) {
          result.add(
            ChatMemberAvatarInfo(
              url: group.avatarUrl.isNotEmpty ? group.avatarUrl : null,
              fallbackText: group.name.isNotEmpty ? group.name : '?',
            ),
          );
        } else {
          result.add(
            const ChatMemberAvatarInfo(url: null, fallbackText: '?'),
          );
        }
      }
    }

    return result;
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

    final rawChats = JsonSafe.toList(
      json['chats'],
      (c) => Chat.fromJson(JsonSafe.toMap(c)),
    );
    final chatsMap = <int, Chat>{};
    for (final c in rawChats) {
      chatsMap[c.id] = c;
      chatsMap[2000000000 + c.id] = c;
    }

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
      chats: chatsMap,
    );
  }

  factory ConversationsResponse.empty() => const ConversationsResponse(
    count: 0,
    unreadCount: 0,
    items: [],
    profiles: {},
    groups: {},
    chats: {},
  );
}
