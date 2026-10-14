import 'dart:math';

import 'package:flutter/foundation.dart';

import '../cache/user_cache.dart';
import '../models/attachment.dart';
import '../models/conversation.dart';
import '../models/conversations_response.dart';
import '../models/group.dart';
import '../models/history_response.dart';
import '../models/message.dart';
import '../models/user.dart';

class MessengerStore {
  final UserCache userCache;

  final ValueNotifier<List<int>> conversationOrder = ValueNotifier<List<int>>([]);
  final ValueNotifier<List<int>> unreadConversationOrder = ValueNotifier<List<int>>([]);
  final ValueNotifier<int> totalUnreadCount = ValueNotifier<int>(0);

  final Map<int, ValueNotifier<ConversationItem>> _conversationNotifiers = {};
  final Map<int, ValueNotifier<List<int>>> _chatMessageOrders = {};
  final Map<int, ValueNotifier<Message>> _messageNotifiers = {};

  int currentUserId = 0;

  MessengerStore({UserCache? userCache})
      : userCache = userCache ?? UserCache();

  Map<int, User> get profiles => userCache.users;
  Map<int, Group> get groups => userCache.groups;
  Map<int, Chat> get chats => userCache.chats;

  ValueNotifier<ConversationItem>? getConversationNotifier(int peerId) {
    return _conversationNotifiers[peerId];
  }

  ValueNotifier<ConversationItem> getOrCreateConversationNotifier(ConversationItem item) {
    if (_conversationNotifiers.containsKey(item.peerId)) {
      _conversationNotifiers[item.peerId]!.value = item;
    } else {
      _conversationNotifiers[item.peerId] = ValueNotifier<ConversationItem>(item);
    }
    return _conversationNotifiers[item.peerId]!;
  }

  ValueNotifier<List<int>> getChatMessageOrderNotifier(int peerId) {
    return _chatMessageOrders.putIfAbsent(
      peerId,
      () => ValueNotifier<List<int>>([]),
    );
  }

  ValueNotifier<Message>? getMessageNotifier(int messageId) {
    return _messageNotifiers[messageId];
  }

  Message? getMessage(int messageId) {
    return _messageNotifiers[messageId]?.value;
  }

  void setConversations(
    ConversationsResponse response, {
    bool append = false,
    String filter = 'all',
  }) {
    userCache.putUsers(response.profiles.values);
    userCache.putGroups(response.groups.values);
    userCache.putChats(response.chats.values);

    final newPeerIds = <int>[];
    final unreadPeerIds = <int>[];

    for (final item in response.items) {
      getOrCreateConversationNotifier(item);
      newPeerIds.add(item.peerId);
      if (filter == 'unread' || item.unreadCount > 0) {
        unreadPeerIds.add(item.peerId);
      }
    }

    if (filter == 'unread') {
      final updatedUnread = List<int>.from(unreadConversationOrder.value);
      if (append) {
        for (final id in unreadPeerIds) {
          if (!updatedUnread.contains(id)) {
            updatedUnread.add(id);
          }
        }
      } else {
        // Merge without losing any existing unread chats in cache
        for (final id in unreadPeerIds.reversed) {
          updatedUnread.remove(id);
          updatedUnread.insert(0, id);
        }
      }
      unreadConversationOrder.value = updatedUnread;

      // Ensure they exist in conversationOrder as well
      final updatedOrder = List<int>.from(conversationOrder.value);
      for (final id in unreadPeerIds) {
        if (!updatedOrder.contains(id)) {
          updatedOrder.add(id);
        }
      }
      conversationOrder.value = updatedOrder;
    } else {
      if (append) {
        final updatedOrder = List<int>.from(conversationOrder.value);
        for (final id in newPeerIds) {
          if (!updatedOrder.contains(id)) {
            updatedOrder.add(id);
          }
        }
        conversationOrder.value = updatedOrder;

        final updatedUnread = List<int>.from(unreadConversationOrder.value);
        for (final id in unreadPeerIds) {
          if (!updatedUnread.contains(id)) {
            updatedUnread.add(id);
          }
        }
        unreadConversationOrder.value = updatedUnread;
      } else {
        conversationOrder.value = newPeerIds;

        final updatedUnread = List<int>.from(unreadConversationOrder.value);
        for (final id in unreadPeerIds) {
          if (!updatedUnread.contains(id)) {
            updatedUnread.add(id);
          }
        }
        for (final item in response.items) {
          if (item.unreadCount == 0) {
            updatedUnread.remove(item.peerId);
          }
        }
        unreadConversationOrder.value = updatedUnread;
      }
    }

    totalUnreadCount.value = response.unreadCount;
  }

  void setHistory(int peerId, HistoryResponse response, {bool append = false}) {
    userCache.putUsers(response.profiles.values);
    userCache.putGroups(response.groups.values);

    final msgOrder = getChatMessageOrderNotifier(peerId);
    final ids = <int>[];

    for (final msg in response.items) {
      if (_messageNotifiers.containsKey(msg.id)) {
        _messageNotifiers[msg.id]!.value = msg;
      } else {
        _messageNotifiers[msg.id] = ValueNotifier<Message>(msg);
      }
      ids.add(msg.id);
    }

    if (append) {
      final updated = List<int>.from(msgOrder.value);
      for (final id in ids) {
        if (!updated.contains(id)) {
          updated.add(id);
        }
      }
      msgOrder.value = updated;
    } else {
      msgOrder.value = ids;
    }
  }

  void onNewMessage({
    required int messageId,
    required int flags,
    required int peerId,
    required int timestamp,
    required String text,
    Map<String, dynamic>? attachments,
    int? randomId,
    int? conversationMessageId,
    Map<String, dynamic>? extraFields,
    int? fromId,
  }) {
    final isOut = (flags & 2) != 0;
    final isUnread = (flags & 1) != 0;
    final isImportant = (flags & 8) != 0;

    int? detectedFromId = fromId;
    if (detectedFromId == null) {
      if (attachments != null && attachments.containsKey('from')) {
        detectedFromId = int.tryParse(attachments['from'].toString());
      } else if (extraFields != null && extraFields.containsKey('from')) {
        detectedFromId = int.tryParse(extraFields['from'].toString());
      }
    }

    final parsedFromId = detectedFromId ?? (isOut ? currentUserId : peerId);

    // Auto-request sender info if not in cache
    if (parsedFromId > 0 && !userCache.hasUser(parsedFromId)) {
      userCache.requestUser(parsedFromId);
    } else if (parsedFromId < 0 && !userCache.hasGroup(parsedFromId.abs())) {
      userCache.requestGroup(parsedFromId.abs());
    }

    if (peerId > 0 && peerId <= 2000000000 && !userCache.hasUser(peerId)) {
      userCache.requestUser(peerId);
    } else if (peerId < 0 && !userCache.hasGroup(peerId.abs())) {
      userCache.requestGroup(peerId.abs());
    }

    final parsedAttachments = _parseAttachments(attachments);

    final newMessage = Message(
      id: messageId,
      date: timestamp,
      peerId: peerId,
      fromId: parsedFromId,
      text: text,
      isOut: isOut,
      isImportant: isImportant,
      isUnread: isUnread,
      attachments: parsedAttachments,
      fwdMessages: const [],
      conversationMessageId: conversationMessageId ?? 0,
      updateTime: timestamp,
    );

    debugPrint('[MessengerStore] 📝 onNewMessage: peerId=$peerId, msgId=$messageId, fromId=$parsedFromId, text="$text", preview="${newMessage.previewText}"');

    if (_messageNotifiers.containsKey(messageId)) {
      _messageNotifiers[messageId]!.value = newMessage;
    } else {
      _messageNotifiers[messageId] = ValueNotifier<Message>(newMessage);
    }

    final chatOrder = getChatMessageOrderNotifier(peerId);
    final currentChatIds = List<int>.from(chatOrder.value);
    if (!currentChatIds.contains(messageId)) {
      currentChatIds.insert(0, messageId);
      chatOrder.value = currentChatIds;
    }

    final convNotifier = _conversationNotifiers[peerId];
    if (convNotifier != null) {
      final oldConv = convNotifier.value;
      final newUnread = (!isOut && isUnread)
          ? oldConv.unreadCount + 1
          : oldConv.unreadCount;
      convNotifier.value = oldConv.copyWith(
        lastMessage: newMessage,
        unreadCount: newUnread,
      );
    } else {
      final newConv = ConversationItem(
        peerId: peerId,
        peerType: peerId > 2000000000
            ? 'chat'
            : (peerId < 0 ? 'group' : 'user'),
        inRead: 0,
        outRead: 0,
        unreadCount: (!isOut && isUnread) ? 1 : 0,
        isImportant: isImportant,
        isUnanswered: false,
        lastMessage: newMessage,
      );
      _conversationNotifiers[peerId] = ValueNotifier<ConversationItem>(newConv);
    }

    final currentOrder = List<int>.from(conversationOrder.value);
    currentOrder.remove(peerId);
    currentOrder.insert(0, peerId);
    conversationOrder.value = currentOrder;

    if (!isOut && isUnread) {
      final currentUnreadOrder = List<int>.from(unreadConversationOrder.value);
      currentUnreadOrder.remove(peerId);
      currentUnreadOrder.insert(0, peerId);
      unreadConversationOrder.value = currentUnreadOrder;
      totalUnreadCount.value += 1;
    }
  }

  void onMessageFlagsUpdated(int messageId, int mask, int peerId, bool add) {
    final notifier = _messageNotifiers[messageId];
    if (notifier == null) return;

    final msg = notifier.value;
    var isUnread = msg.isUnread;
    var isImportant = msg.isImportant;

    if ((mask & 1) != 0) {
      isUnread = add;
    }
    if ((mask & 8) != 0) {
      isImportant = add;
    }

    notifier.value = msg.copyWith(
      isUnread: isUnread,
      isImportant: isImportant,
    );
  }

  void onReadIncoming(int peerId, int localId) {
    final convNotifier = _conversationNotifiers[peerId];
    if (convNotifier != null) {
      final old = convNotifier.value;
      final newInRead = max(old.inRead, localId);
      convNotifier.value = old.copyWith(
        inRead: newInRead,
        unreadCount: 0,
      );
    }

    final currentUnreadOrder = List<int>.from(unreadConversationOrder.value);
    if (currentUnreadOrder.remove(peerId)) {
      unreadConversationOrder.value = currentUnreadOrder;
    }

    final chatOrder = _chatMessageOrders[peerId];
    if (chatOrder != null) {
      for (final id in chatOrder.value) {
        if (id <= localId) {
          final msgNotifier = _messageNotifiers[id];
          if (msgNotifier != null && !msgNotifier.value.isOut && msgNotifier.value.isUnread) {
            msgNotifier.value = msgNotifier.value.copyWith(isUnread: false);
          }
        }
      }
    }
  }

  void onReadOutgoing(int peerId, int localId) {
    final convNotifier = _conversationNotifiers[peerId];
    if (convNotifier != null) {
      final old = convNotifier.value;
      final newOutRead = max(old.outRead, localId);
      convNotifier.value = old.copyWith(outRead: newOutRead);
    }

    final chatOrder = _chatMessageOrders[peerId];
    if (chatOrder != null) {
      for (final id in chatOrder.value) {
        if (id <= localId) {
          final msgNotifier = _messageNotifiers[id];
          if (msgNotifier != null && msgNotifier.value.isOut && msgNotifier.value.isUnread) {
            msgNotifier.value = msgNotifier.value.copyWith(isUnread: false);
          }
        }
      }
    }
  }

  void onEditMessage(int messageId, int peerId, String newText) {
    final msgNotifier = _messageNotifiers[messageId];
    if (msgNotifier != null) {
      msgNotifier.value = msgNotifier.value.copyWith(text: newText);
    }

    final convNotifier = _conversationNotifiers[peerId];
    if (convNotifier != null && convNotifier.value.lastMessage.id == messageId) {
      convNotifier.value = convNotifier.value.copyWith(
        lastMessage: convNotifier.value.lastMessage.copyWith(text: newText),
      );
    }
  }

  void setTotalUnreadCount(int count) {
    totalUnreadCount.value = count;
  }

  String getTitle(ConversationItem item) => userCache.getTitle(item);

  String? getAvatarUrl(ConversationItem item) => userCache.getAvatarUrl(item);

  List<ChatMemberAvatarInfo> getChatMemberAvatars(ConversationItem item) {
    if (!item.isChat) return const [];

    final activeIds = item.chatSettings?.activeIds ?? const [];
    if (activeIds.isEmpty) return const [];

    final result = <ChatMemberAvatarInfo>[];
    for (final memberId in activeIds.take(4)) {
      if (memberId > 0) {
        final user = userCache.getUser(memberId);
        if (user != null) {
          result.add(
            ChatMemberAvatarInfo(
              url: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
              fallbackText: user.firstName.isNotEmpty
                  ? user.firstName
                  : user.fullName,
            ),
          );
        } else {
          userCache.requestUser(memberId);
          result.add(
            const ChatMemberAvatarInfo(url: null, fallbackText: '?'),
          );
        }
      } else if (memberId < 0) {
        final group = userCache.getGroup(memberId.abs());
        if (group != null) {
          result.add(
            ChatMemberAvatarInfo(
              url: group.avatarUrl.isNotEmpty ? group.avatarUrl : null,
              fallbackText: group.name.isNotEmpty ? group.name : '?',
            ),
          );
        } else {
          userCache.requestGroup(memberId.abs());
          result.add(
            const ChatMemberAvatarInfo(url: null, fallbackText: '?'),
          );
        }
      }
    }

    return result;
  }

  List<Attachment> _parseAttachments(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const [];

    final list = <Attachment>[];
    for (int i = 1; i <= 10; i++) {
      final typeKey = 'attach${i}_type';
      if (!raw.containsKey(typeKey)) break;
      final type = raw[typeKey].toString();
      list.add(Attachment(type: type));
    }
    return list;
  }

  void clear() {
    conversationOrder.value = [];
    unreadConversationOrder.value = [];
    totalUnreadCount.value = 0;
    _conversationNotifiers.clear();
    _chatMessageOrders.clear();
    _messageNotifiers.clear();
    userCache.clear();
  }
}
