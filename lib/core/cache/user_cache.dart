import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/conversation.dart';
import '../models/group.dart';
import '../models/user.dart';

typedef FetchUsersCallback = Future<List<User>> Function(List<int> userIds);
typedef FetchGroupsCallback = Future<List<Group>> Function(List<int> groupIds);

/// In-memory global session cache for users, groups, and chats.
/// Never persists to SQLite — lives strictly in RAM during the active session.
/// Automatically overwrites cached entities with newer data whenever fetched.
class UserCache {
  final Map<int, User> _users = {};
  final Map<int, Group> _groups = {};
  final Map<int, Chat> _chats = {};

  final Set<int> _pendingUserIds = {};
  final Set<int> _pendingGroupIds = {};

  Timer? _batchUserTimer;
  Timer? _batchGroupTimer;

  final FetchUsersCallback? fetchUsersHandler;
  final FetchGroupsCallback? fetchGroupsHandler;

  /// Revision counter to notify reactive UI when profiles or groups are updated.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  UserCache({
    this.fetchUsersHandler,
    this.fetchGroupsHandler,
  });

  Map<int, User> get users => _users;
  Map<int, Group> get groups => _groups;
  Map<int, Chat> get chats => _chats;

  User? getUser(int id) => _users[id];
  Group? getGroup(int id) => _groups[id];
  Chat? getChat(int id) => _chats[id];

  bool hasUser(int id) => _users.containsKey(id);
  bool hasGroup(int id) => _groups.containsKey(id);
  bool hasChat(int id) => _chats.containsKey(id);

  /// Stores or updates a user profile with the latest information.
  void putUser(User user) {
    _users[user.id] = user;
    _notifyRevision();
  }

  /// Stores or updates multiple user profiles.
  void putUsers(Iterable<User> newUsers) {
    if (newUsers.isEmpty) return;
    for (final u in newUsers) {
      _users[u.id] = u;
    }
    _notifyRevision();
  }

  /// Stores or updates a community/group with the latest information.
  void putGroup(Group group) {
    _groups[group.id] = group;
    _notifyRevision();
  }

  /// Stores or updates multiple communities.
  void putGroups(Iterable<Group> newGroups) {
    if (newGroups.isEmpty) return;
    for (final g in newGroups) {
      _groups[g.id] = g;
    }
    _notifyRevision();
  }

  /// Stores or updates a chat metadata object.
  void putChat(Chat chat) {
    _chats[chat.id] = chat;
    _notifyRevision();
  }

  /// Stores or updates multiple chats.
  void putChats(Iterable<Chat> newChats) {
    if (newChats.isEmpty) return;
    for (final c in newChats) {
      _chats[c.id] = c;
    }
    _notifyRevision();
  }

  /// Returns sender's display name (first name for user, title for group).
  String getSenderName(int fromId) {
    if (fromId > 0) {
      final user = _users[fromId];
      if (user != null) {
        return user.firstName.isNotEmpty ? user.firstName : user.fullName;
      }
      return '';
    } else if (fromId < 0) {
      final group = _groups[fromId.abs()];
      if (group != null) {
        return group.name;
      }
      return '';
    }
    return '';
  }

  /// Resolves title for a conversation item using cached chat, group, or user info.
  String getTitle(ConversationItem item) {
    if (item.isChat) {
      final title = item.chatSettings?.title;
      if (title != null && title.isNotEmpty) return title;
      final chatId = item.peerId > 2000000000 ? item.peerId - 2000000000 : item.peerId;
      final chat = _chats[chatId] ?? _chats[item.peerId];
      if (chat != null && chat.title.isNotEmpty) return chat.title;
      return 'Беседа #$chatId';
    }

    if (item.isGroup) {
      final groupId = item.peerId.abs();
      return _groups[groupId]?.name ?? 'Сообщество #$groupId';
    }

    final user = _users[item.peerId];
    if (user != null) return user.fullName;

    return 'Пользователь #${item.peerId}';
  }

  /// Resolves avatar URL for a conversation item using cached information.
  String? getAvatarUrl(ConversationItem item) {
    if (item.isChat) {
      final photo = item.chatSettings?.photoUrl;
      if (photo != null && photo.isNotEmpty) return photo;
      final chatId = item.peerId > 2000000000 ? item.peerId - 2000000000 : item.peerId;
      final chat = _chats[chatId] ?? _chats[item.peerId];
      if (chat != null && chat.photoUrl.isNotEmpty) return chat.photoUrl;
      return null;
    }

    if (item.isGroup) {
      final groupId = item.peerId.abs();
      return _groups[groupId]?.avatarUrl;
    }

    return _users[item.peerId]?.avatarUrl;
  }

  /// Requests a user to be fetched in background if not already cached.
  /// Automatically batches multiple requests within 50ms into a single API call.
  void requestUser(int userId) {
    if (userId <= 0 || _users.containsKey(userId) || _pendingUserIds.contains(userId)) {
      return;
    }
    if (fetchUsersHandler == null) return;

    _pendingUserIds.add(userId);
    _batchUserTimer?.cancel();
    _batchUserTimer = Timer(const Duration(milliseconds: 50), () async {
      final idsToFetch = _pendingUserIds.toList();
      _pendingUserIds.clear();
      if (idsToFetch.isEmpty) return;

      try {
        final fetched = await fetchUsersHandler!(idsToFetch);
        putUsers(fetched);
      } catch (e) {
        debugPrint('[UserCache] Ошибка фоновой загрузки пользователей $idsToFetch: $e');
      }
    });
  }

  /// Requests a group to be fetched in background if not already cached.
  void requestGroup(int groupId) {
    final absId = groupId.abs();
    if (absId <= 0 || _groups.containsKey(absId) || _pendingGroupIds.contains(absId)) {
      return;
    }
    if (fetchGroupsHandler == null) return;

    _pendingGroupIds.add(absId);
    _batchGroupTimer?.cancel();
    _batchGroupTimer = Timer(const Duration(milliseconds: 50), () async {
      final idsToFetch = _pendingGroupIds.toList();
      _pendingGroupIds.clear();
      if (idsToFetch.isEmpty) return;

      try {
        final fetched = await fetchGroupsHandler!(idsToFetch);
        putGroups(fetched);
      } catch (e) {
        debugPrint('[UserCache] Ошибка фоновой загрузки сообществ $idsToFetch: $e');
      }
    });
  }

  void _notifyRevision() {
    revision.value++;
  }

  /// Clears in-memory session cache on logout or account switch.
  void clear() {
    _batchUserTimer?.cancel();
    _batchGroupTimer?.cancel();
    _pendingUserIds.clear();
    _pendingGroupIds.clear();
    _users.clear();
    _groups.clear();
    _chats.clear();
    revision.value = 0;
  }
}
