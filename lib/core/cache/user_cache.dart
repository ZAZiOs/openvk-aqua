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
  final Set<int> _inFlightUserIds = {};
  final Set<int> _failedUserIds = {};

  final Set<int> _pendingGroupIds = {};
  final Set<int> _inFlightGroupIds = {};
  final Set<int> _failedGroupIds = {};

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

  User? getUser(int id, {bool autoFetch = true}) {
    final user = _users[id];
    if (user == null && autoFetch && id > 0) {
      requestUser(id);
    }
    return user;
  }

  Group? getGroup(int id, {bool autoFetch = true}) {
    final absId = id.abs();
    final group = _groups[absId];
    if (group == null && autoFetch && absId > 0) {
      requestGroup(absId);
    }
    return group;
  }

  Chat? getChat(int id) => _chats[id];

  bool hasUser(int id) => _users.containsKey(id);
  bool hasGroup(int id) => _groups.containsKey(id);
  bool hasChat(int id) => _chats.containsKey(id);

  /// Stores or updates a user profile with the latest information.
  void putUser(User user) {
    _users[user.id] = user;
    _failedUserIds.remove(user.id);
    _notifyRevision();
  }

  /// Stores or updates multiple user profiles.
  void putUsers(Iterable<User> newUsers) {
    if (newUsers.isEmpty) return;
    for (final u in newUsers) {
      _users[u.id] = u;
      _failedUserIds.remove(u.id);
    }
    _notifyRevision();
  }

  /// Stores or updates a community/group with the latest information.
  void putGroup(Group group) {
    _groups[group.id] = group;
    _failedGroupIds.remove(group.id);
    _notifyRevision();
  }

  /// Stores or updates multiple communities.
  void putGroups(Iterable<Group> newGroups) {
    if (newGroups.isEmpty) return;
    for (final g in newGroups) {
      _groups[g.id] = g;
      _failedGroupIds.remove(g.id);
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
      requestUser(fromId);
      return '';
    } else if (fromId < 0) {
      final absId = fromId.abs();
      final group = _groups[absId];
      if (group != null) {
        return group.name;
      }
      requestGroup(absId);
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
      final group = _groups[groupId];
      if (group != null && group.name.isNotEmpty) return group.name;
      requestGroup(groupId);
      return 'Сообщество #$groupId';
    }

    final user = _users[item.peerId];
    if (user != null && user.fullName.isNotEmpty) return user.fullName;

    requestUser(item.peerId);
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
      final group = _groups[groupId];
      if (group == null) requestGroup(groupId);
      return group?.avatarUrl;
    }

    final user = _users[item.peerId];
    if (user == null) requestUser(item.peerId);
    return user?.avatarUrl;
  }

  /// Requests a user to be fetched in background if not already cached.
  /// Automatically batches multiple requests into a single API call.
  void requestUser(int userId) {
    if (userId <= 0 ||
        _users.containsKey(userId) ||
        _pendingUserIds.contains(userId) ||
        _inFlightUserIds.contains(userId) ||
        _failedUserIds.contains(userId)) {
      return;
    }
    if (fetchUsersHandler == null) return;

    _pendingUserIds.add(userId);
    _batchUserTimer?.cancel();
    _batchUserTimer = Timer(const Duration(milliseconds: 30), _flushPendingUsers);
  }

  Future<void> _flushPendingUsers() async {
    final idsToFetch = _pendingUserIds.toList();
    _pendingUserIds.clear();
    if (idsToFetch.isEmpty) return;

    _inFlightUserIds.addAll(idsToFetch);

    try {
      final fetched = await fetchUsersHandler!(idsToFetch);
      putUsers(fetched);

      for (final id in idsToFetch) {
        if (!_users.containsKey(id)) {
          _failedUserIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[UserCache] Ошибка фоновой загрузки пользователей $idsToFetch: $e');
    } finally {
      _inFlightUserIds.removeAll(idsToFetch);
    }
  }

  /// Requests a group to be fetched in background if not already cached.
  void requestGroup(int groupId) {
    final absId = groupId.abs();
    if (absId <= 0 ||
        _groups.containsKey(absId) ||
        _pendingGroupIds.contains(absId) ||
        _inFlightGroupIds.contains(absId) ||
        _failedGroupIds.contains(absId)) {
      return;
    }
    if (fetchGroupsHandler == null) return;

    _pendingGroupIds.add(absId);
    _batchGroupTimer?.cancel();
    _batchGroupTimer = Timer(const Duration(milliseconds: 30), _flushPendingGroups);
  }

  Future<void> _flushPendingGroups() async {
    final idsToFetch = _pendingGroupIds.toList();
    _pendingGroupIds.clear();
    if (idsToFetch.isEmpty) return;

    _inFlightGroupIds.addAll(idsToFetch);

    try {
      final fetched = await fetchGroupsHandler!(idsToFetch);
      putGroups(fetched);

      for (final id in idsToFetch) {
        if (!_groups.containsKey(id)) {
          _failedGroupIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[UserCache] Ошибка фоновой загрузки сообществ $idsToFetch: $e');
    } finally {
      _inFlightGroupIds.removeAll(idsToFetch);
    }
  }

  void _notifyRevision() {
    revision.value++;
  }

  /// Clears in-memory session cache on logout or account switch.
  void clear() {
    _batchUserTimer?.cancel();
    _batchGroupTimer?.cancel();
    _pendingUserIds.clear();
    _inFlightUserIds.clear();
    _failedUserIds.clear();
    _pendingGroupIds.clear();
    _inFlightGroupIds.clear();
    _failedGroupIds.clear();
    _users.clear();
    _groups.clear();
    _chats.clear();
    revision.value = 0;
  }
}
