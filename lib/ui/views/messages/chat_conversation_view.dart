import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/messages_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/models/attachment.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/conversations_response.dart';
import '../../../core/models/message.dart';
import '../../../core/models/user.dart';
import '../../../core/notifications/notification_dispatcher.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_attachment_grid.dart';
import '../../widgets/retro_chat_avatar.dart';
import '../../widgets/retro_ios6_dialog.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../wall/wall_view.dart';

class ChatConversationView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final ConversationItem conversation;
  final String title;
  final String? avatarUrl;
  final List<ChatMemberAvatarInfo>? memberAvatars;
  final int currentUserId;
  final bool isEmbedded;
  final VoidCallback? onClose;

  const ChatConversationView({
    super.key,
    required this.client,
    required this.account,
    required this.conversation,
    required this.title,
    this.avatarUrl,
    this.memberAvatars,
    required this.currentUserId,
    this.isEmbedded = false,
    this.onClose,
  });

  static const russianMonthsGenitive = [
    '',
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static String formatDateSeparator(int timestamp) {
    if (timestamp <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final monthName = russianMonthsGenitive[dt.month];
    if (dt.year != now.year) {
      return '${dt.day} $monthName ${dt.year}';
    }
    return '${dt.day} $monthName';
  }

  static bool isSameDay(int ts1, int ts2) {
    if (ts1 <= 0 || ts2 <= 0) return true;
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1 * 1000);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2 * 1000);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  late final MessagesHandler _messagesHandler;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _listKey = GlobalKey();
  int? _unreadSeparatorMessageId;
  bool _hasCalculatedUnreadSeparator = false;
  bool _hasJumpedToUnread = false;

  int _lastMarkedReadId = 0;
  int _pendingReadCandidateId = 0;
  Timer? _markReadDebounceTimer;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingNewer = false;
  bool _isAtLatest = true;
  bool _showScrollToBottom = false;
  int? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _hasMore = true;
  bool _isSending = false;
  int _historyOffset = 0;
  String? _errorMessage;
  final Map<int, GlobalKey> _messageKeys = {};

  GlobalKey _getKeyForMessage(int id) =>
      _messageKeys.putIfAbsent(id, () => GlobalKey());

  void _openUserProfile(int userId) {
    if (userId == 0) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WallView(
          client: widget.client,
          account: widget.account,
          ownerId: userId,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    NotificationDispatcher.instance.activePeerId = widget.conversation.peerId;
    _messagesHandler = MessagesHandler(widget.client);
    _lastMarkedReadId = widget.conversation.inRead;
    _pendingReadCandidateId = widget.conversation.inRead;
    _scrollController.addListener(_onScroll);
    _loadHistory();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _markReadDebounceTimer?.cancel();
    if (_pendingReadCandidateId > _lastMarkedReadId) {
      final idToMark = _pendingReadCandidateId;
      _lastMarkedReadId = idToMark;
      widget.client.messengerStore.onReadIncoming(widget.conversation.peerId, idToMark);
      _messagesHandler.markAsRead(peerId: widget.conversation.peerId, startMessageId: idToMark);
    }
    if (NotificationDispatcher.instance.activePeerId == widget.conversation.peerId) {
      NotificationDispatcher.instance.activePeerId = null;
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.isEmbedded && widget.onClose != null) {
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) {
          nav.maybePop();
          return true;
        }
        widget.onClose!();
        return true;
      } else {
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) {
          nav.maybePop();
          return true;
        }
      }
    }
    return false;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    _checkVisibleUnreadMessages();

    // In reverse ListView: maxScrollExtent is the top of the chat (where older messages are)
    if (pos.pixels >= pos.maxScrollExtent - 250 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreHistory();
    }

    // In reverse ListView: pixels <= 250 is near the bottom (where newer messages are)
    if (!_isAtLatest &&
        pos.pixels <= 250 &&
        !_isLoading &&
        !_isLoadingNewer) {
      _loadNewerHistory();
    }

    final shouldShowScrollToBottom = !_isAtLatest || pos.pixels > 300;
    if (shouldShowScrollToBottom != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShowScrollToBottom;
      });
    }
  }

  Widget _buildUnreadSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFB8C2CC),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Непрочитанные сообщения',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7B8D),
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFB8C2CC),
            ),
          ),
        ],
      ),
    );
  }

  void _checkVisibleUnreadMessages() {
    if (!mounted || !_scrollController.hasClients) return;

    final listRenderBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listRenderBox == null || !listRenderBox.hasSize || !listRenderBox.attached) return;

    final listHeight = listRenderBox.size.height;
    final orderNotifier = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId);
    final messageIds = orderNotifier.value;
    if (messageIds.isEmpty) return;

    int? maxVisibleUnreadId;

    for (final id in messageIds) {
      final msg = widget.client.messengerStore.getMessage(id);
      if (msg == null || msg.isOut) continue;

      // Only check unread messages
      if (id <= _lastMarkedReadId && !msg.isUnread) continue;

      final msgContext = _messageKeys[id]?.currentContext;
      if (msgContext == null || !msgContext.mounted) continue;

      final msgBox = msgContext.findRenderObject() as RenderBox?;
      if (msgBox == null || !msgBox.hasSize || !msgBox.attached) continue;

      try {
        final msgBottomInList = msgBox.localToGlobal(
          Offset(0, msgBox.size.height),
          ancestor: listRenderBox,
        ).dy;

        final isAtBottom = _scrollController.position.pixels <= 10;
        if (msgBottomInList <= listHeight + 10 || isAtBottom) {
          if (maxVisibleUnreadId == null || id > maxVisibleUnreadId) {
            maxVisibleUnreadId = id;
          }
        }
      } catch (_) {}
    }

    if (maxVisibleUnreadId != null && maxVisibleUnreadId > _lastMarkedReadId) {
      _scheduleMarkAsRead(maxVisibleUnreadId);
    }
  }

  void _scheduleMarkAsRead(int targetId) {
    if (targetId <= _lastMarkedReadId) return;

    _pendingReadCandidateId = max(_pendingReadCandidateId, targetId);

    // Update local store immediately so conversation unread badges and store stay in sync
    widget.client.messengerStore.onReadIncoming(
      widget.conversation.peerId,
      _pendingReadCandidateId,
    );

    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final idToMark = _pendingReadCandidateId;
      if (idToMark <= _lastMarkedReadId) return;

      _lastMarkedReadId = idToMark;

      try {
        await _messagesHandler.markAsRead(
          peerId: widget.conversation.peerId,
          startMessageId: idToMark,
        );
      } catch (e) {
        debugPrint('[ChatConversationView] markAsRead error: $e');
      }
    });
  }

  Future<void> _jumpToUnreadMessage(int targetId) async {
    if (!mounted || !_scrollController.hasClients) return;

    final orderNotifier = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId);
    final messageIds = orderNotifier.value;
    final targetIndex = messageIds.indexOf(targetId);
    if (targetIndex <= 0) {
      _checkVisibleUnreadMessages();
      return;
    }

    // 1. If already mounted in viewport:
    final existingContext = _messageKeys[targetId]?.currentContext;
    if (existingContext != null && existingContext.mounted) {
      await Scrollable.ensureVisible(
        existingContext,
        alignment: 0.85,
        duration: Duration.zero,
      );
      _checkVisibleUnreadMessages();
      return;
    }

    // 2. If not mounted, jump near estimated offset in reverse ListView:
    if (_scrollController.hasClients) {
      final viewportDim = _scrollController.position.viewportDimension;
      final estimatedOffset = (targetIndex * 65.0 - viewportDim * 0.15).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(estimatedOffset);
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) return;

    // 3. Precisely align:
    final targetContext = _messageKeys[targetId]?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.85,
        duration: Duration.zero,
      );
    }
    _checkVisibleUnreadMessages();
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    final existingMessages = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId)
        .value;

    if (!_hasCalculatedUnreadSeparator && existingMessages.isNotEmpty) {
      int? oldestUnreadId;
      for (final id in existingMessages) {
        final msg = widget.client.messengerStore.getMessage(id);
        if (msg != null && !msg.isOut && (id > widget.conversation.inRead || msg.isUnread)) {
          if (oldestUnreadId == null || id < oldestUnreadId) {
            oldestUnreadId = id;
          }
        }
      }
      if (oldestUnreadId != null) {
        _hasCalculatedUnreadSeparator = true;
        _unreadSeparatorMessageId = oldestUnreadId;
        if (!_hasJumpedToUnread) {
          _hasJumpedToUnread = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _jumpToUnreadMessage(oldestUnreadId!);
          });
        }
      }
    }

    if (existingMessages.isEmpty || refresh) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      } else {
        _isLoading = true;
        _errorMessage = null;
      }
    }

    final res = await _messagesHandler.getHistory(
      peerId: widget.conversation.peerId,
      offset: 0,
      count: 40,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      final orderNotifier = widget.client.messengerStore
          .getChatMessageOrderNotifier(widget.conversation.peerId);
      final currentMessageIds = orderNotifier.value;

      if (!_hasCalculatedUnreadSeparator) {
        int? oldestUnreadId;
        for (final id in currentMessageIds) {
          final msg = widget.client.messengerStore.getMessage(id);
          if (msg != null && !msg.isOut && (id > widget.conversation.inRead || msg.isUnread)) {
            if (oldestUnreadId == null || id < oldestUnreadId) {
              oldestUnreadId = id;
            }
          }
        }
        if (oldestUnreadId != null) {
          _hasCalculatedUnreadSeparator = true;
          _unreadSeparatorMessageId = oldestUnreadId;
        }
      }

      setState(() {
        _historyOffset = data.items.length;
        _hasMore = _historyOffset < data.count && data.items.isNotEmpty;
        _isLoading = false;
        _isAtLatest = true;
        _errorMessage = null;
      });

      if (!_hasJumpedToUnread && _unreadSeparatorMessageId != null) {
        _hasJumpedToUnread = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToUnreadMessage(_unreadSeparatorMessageId!);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVisibleUnreadMessages();
        });
      }
    } else {
      setState(() {
        if (existingMessages.isEmpty) {
          _errorMessage =
              res.errorOrNull?.message ?? 'Не удалось загрузить историю сообщений';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final currentCount = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId)
        .value
        .length;
    final offsetToUse = _historyOffset > currentCount ? _historyOffset : currentCount;

    final res = await _messagesHandler.getHistory(
      peerId: widget.conversation.peerId,
      offset: offsetToUse,
      count: 40,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _historyOffset = offsetToUse + data.items.length;
        _hasMore = _historyOffset < data.count && data.items.isNotEmpty;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadNewerHistory() async {
    if (_isLoading || _isLoadingNewer || _isAtLatest) return;

    setState(() => _isLoadingNewer = true);

    final currentIds = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId)
        .value;
    if (currentIds.isEmpty) {
      setState(() => _isLoadingNewer = false);
      return;
    }

    final newestId = currentIds.first;

    final res = await _messagesHandler.getHistory(
      peerId: widget.conversation.peerId,
      startMessageId: newestId,
      offset: -40,
      count: 40,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      widget.client.messengerStore.setHistory(
        widget.conversation.peerId,
        data,
        merge: true,
      );

      final lastChatMsgId = widget.conversation.lastMessage.id;
      final reachedLatest = data.items.isEmpty ||
          data.items.length < 40 ||
          data.items.any((m) => m.id >= lastChatMsgId);

      setState(() {
        _isLoadingNewer = false;
        if (reachedLatest) {
          _isAtLatest = true;
        }
      });
    } else {
      setState(() => _isLoadingNewer = false);
    }
  }

  Future<void> _jumpToMessage(int targetId) async {
    final orderNotifier = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId);
    var messageIds = orderNotifier.value;

    if (!messageIds.contains(targetId)) {
      setState(() => _isLoadingMore = true);
      final res = await _messagesHandler.getHistory(
        peerId: widget.conversation.peerId,
        startMessageId: targetId,
        offset: -20,
        count: 40,
      );

      if (!mounted) return;
      setState(() => _isLoadingMore = false);

      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull!;
        widget.client.messengerStore.setHistory(
          widget.conversation.peerId,
          data,
          merge: true,
        );

        final lastChatMsgId = widget.conversation.lastMessage.id;
        final reachedLatest = data.items.any((m) => m.id >= lastChatMsgId);
        setState(() {
          _isAtLatest = reachedLatest;
        });
      } else {
        return;
      }
      messageIds = orderNotifier.value;
    }

    final targetIndex = messageIds.indexOf(targetId);
    if (targetIndex == -1) return;

    setState(() {
      _highlightedMessageId = targetId;
    });

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _highlightedMessageId == targetId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });

    // 1. If target widget is already mounted in viewport, smoothly center it
    final existingContext = _messageKeys[targetId]?.currentContext;
    if (existingContext != null && existingContext.mounted) {
      await Scrollable.ensureVisible(
        existingContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (!mounted) return;

    // 2. If not currently mounted, jump near the item taking viewportDimension into account
    // In reverse ListView: 0 is bottom, scrolling up moves pixels towards maxScrollExtent.
    // The center of the viewport is at `scrollOffset + viewportDimension / 2`.
    // Target item is approximately at distance `targetIndex * 70.0`.
    if (_scrollController.hasClients) {
      final viewportDim = _scrollController.position.viewportDimension;
      final estimatedOffset = (targetIndex * 70.0 - viewportDim / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(estimatedOffset);

      // Wait for layout to build items around the jumped offset
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) return;

    // 3. Now the target widget is mounted in the viewport; precisely center it
    final newContext = _messageKeys[targetId]?.currentContext;
    if (newContext != null && newContext.mounted) {
      await Scrollable.ensureVisible(
        newContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _jumpToLatest() async {
    if (_isAtLatest) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      await _loadHistory(refresh: true);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      setState(() {
        _isAtLatest = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputController.clear();

    final res = await _messagesHandler.send(
      peerId: widget.conversation.peerId,
      message: text,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorOrNull?.message ?? 'Ошибка при отправке сообщения'),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  Widget _buildDateSeparator(int timestamp) {
    final text = ChatConversationView.formatDateSeparator(timestamp);
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7B8D),
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildEmbeddedHeader() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFFE4E9EF),
        border: Border(
          bottom: BorderSide(color: Color(0xFFC7D0DA), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (widget.conversation.peerId > 0 && !widget.conversation.isChat) {
                _openUserProfile(widget.conversation.peerId);
              }
            },
            child: RetroChatAvatar(
              avatarUrl: widget.avatarUrl,
              members: widget.memberAvatars,
              fallbackText: widget.title,
              size: 34,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (widget.conversation.peerId > 0 && !widget.conversation.isChat) {
                  _openUserProfile(widget.conversation.peerId);
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RetroTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.client.messengerStore
                        .getTypingNotifier(widget.conversation.peerId),
                    builder: (context, typingText, _) {
                      if (typingText != null && typingText.isNotEmpty) {
                        return Text(
                          typingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RetroTheme.vkBlue,
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      if (widget.conversation.isChat) {
                        return Text(
                          '${widget.conversation.chatSettings?.membersCount ?? 2} участников',
                          style: const TextStyle(
                            color: RetroTheme.textSecondary,
                            fontSize: 11.5,
                          ),
                        );
                      }
                      final isUserOnline = !widget.conversation.isChat &&
                          widget.conversation.isUser &&
                          widget.client.userCache.getUser(widget.conversation.peerId)?.isOnline == true;
                      if (isUserOnline) {
                        return const Text(
                          'online',
                          style: TextStyle(
                            color: RetroTheme.vkBlue,
                            fontSize: 11.5,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPinnedMessagePreview(Message message) {
    if (message.text.trim().isNotEmpty) {
      return message.text;
    }
    if (message.isSticker) {
      return 'Стикер';
    }
    if (message.hasGift) {
      final g = message.giftAttachment;
      if (message.text.trim().isNotEmpty) return message.text;
      if (g != null && g.message.trim().isNotEmpty) return g.message;
      return 'Подарок';
    }
    if (message.attachments.isNotEmpty) {
      final type = message.attachments.first.type;
      switch (type) {
        case 'gift':
          return 'Подарок';
        case 'photo':
          return 'Фотография';
        case 'video':
          return 'Видеозапись';
        case 'audio':
          return 'Аудиозапись';
        case 'doc':
          return 'Документ';
        default:
          return 'Вложение';
      }
    }
    if (message.isAction) {
      return message.formatActionText(
        currentUserId: widget.currentUserId,
        userCache: widget.client.userCache,
      );
    }
    return 'Сообщение';
  }

  Widget _buildPinnedMessageBar() {
    final notifier = widget.client.messengerStore
        .getOrCreateConversationNotifier(widget.conversation);
    return ValueListenableBuilder<ConversationItem>(
      valueListenable: notifier,
      builder: (context, conv, _) {
        final pinned = conv.activePinnedMessage;
        if (pinned == null) return const SizedBox.shrink();

        final preview = _getPinnedMessagePreview(pinned);

        return Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4F9),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFC7D3E0),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: RetroTheme.vkBlue,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _jumpToMessage(pinned.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Закреплённое сообщение',
                          style: TextStyle(
                            color: RetroTheme.vkBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RetroTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Color(0xFF7A889B)),
                tooltip: 'Открепить сообщение',
                splashRadius: 16,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final confirmed = await showIos6ConfirmDialog(
                    context: context,
                    title: 'Открепить сообщение',
                    message: 'Вы действительно хотите открепить это сообщение?',
                    cancelText: 'Отмена',
                    confirmText: 'Открепить',
                    isDestructive: true,
                  );
                  if (confirmed == true && mounted) {
                    final res = await _messagesHandler.unpin(peerId: widget.conversation.peerId);
                    if (!res.isSuccess && mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(res.errorOrNull?.message ?? 'Не удалось открепить сообщение')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideChat = constraints.maxWidth > 870;

        final Widget chatBody = Container(
          color: const Color(0xFFE4E8EE),
          child: Column(
            children: [
              if (widget.isEmbedded) _buildEmbeddedHeader(),
              _buildPinnedMessageBar(),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          const fadeHeight = 24.0;
                          final double fadeStart = bounds.height > fadeHeight
                              ? ((bounds.height - fadeHeight) / bounds.height)
                                  .clamp(0.0, 1.0)
                              : 0.0;
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [
                              0.0,
                              fadeStart,
                              1.0,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: _buildMessagesList(isWideChat: isWideChat),
                      ),
                    ),
                    if (_showScrollToBottom)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'chat_scroll_bottom',
                          onPressed: _jumpToLatest,
                          backgroundColor: Colors.white,
                          foregroundColor: RetroTheme.vkBlue,
                          elevation: 3,
                          child: const Icon(Icons.keyboard_arrow_down, size: 24),
                        ),
                      ),
                  ],
                ),
              ),
              _buildTypingIndicatorBar(),
              _buildInputBar(),
            ],
          ),
        );

        if (widget.isEmbedded) {
          return chatBody;
        }

        return Scaffold(
          appBar: RetroAppBar(
            showBackButton: true,
            titleWidget: GestureDetector(
              onTap: () {
                if (widget.conversation.peerId > 0 && !widget.conversation.isChat) {
                  _openUserProfile(widget.conversation.peerId);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RetroChatAvatar(
                    avatarUrl: widget.avatarUrl,
                    members: widget.memberAvatars,
                    fallbackText: widget.title,
                    size: 34,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Color(0x99000000),
                                offset: Offset(0, -1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: widget.client.messengerStore
                              .getTypingNotifier(widget.conversation.peerId),
                          builder: (context, typingText, _) {
                            if (typingText != null && typingText.isNotEmpty) {
                              return Text(
                                typingText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE2ECF7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                            if (widget.conversation.isChat) {
                              return Text(
                                '${widget.conversation.chatSettings?.membersCount ?? 2} участников',
                                style: const TextStyle(
                                  color: Color(0xFFC8D7E8),
                                  fontSize: 11,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: chatBody,
        );
      },
    );
  }

  Widget _buildTypingIndicatorBar() {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.client.messengerStore
          .getTypingNotifier(widget.conversation.peerId),
      builder: (context, typingText, _) {
        final isTyping = typingText != null && typingText.isNotEmpty;
        return Container(
          width: double.infinity,
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFFE4E8EE),
          alignment: Alignment.centerLeft,
          child: AnimatedOpacity(
            opacity: isTyping ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: RetroLoadingIndicator(size: 12),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    typingText ?? '',
                    style: const TextStyle(
                      color: Color(0xFF6B7B8D),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesList({required bool isWideChat}) {
    final orderNotifier = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId);

    return ValueListenableBuilder<List<int>>(
      valueListenable: orderNotifier,
      builder: (context, messageIds, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkVisibleUnreadMessages();
          }
        });

        if (_isLoading && messageIds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroLoadingIndicator(size: 28),
                SizedBox(height: 12),
                Text(
                  'Загрузка сообщений...',
                  style: TextStyle(
                    color: RetroTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (_errorMessage != null && messageIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RetroTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadHistory(refresh: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RetroTheme.vkBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        if (messageIds.isEmpty) {
          return const Center(
            child: Text(
              'В этой беседе пока нет сообщений',
              style: TextStyle(
                color: RetroTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        final showBottomLoader = _isLoadingNewer;
        final showTopLoader = _isLoadingMore;
        final totalCount = messageIds.length +
            (showBottomLoader ? 1 : 0) +
            (showTopLoader ? 1 : 0);

        return KeyedSubtree(
          key: _listKey,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              // Index 0 in reverse ListView is at the bottom of the scroll
              if (showBottomLoader && index == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: RetroLoadingIndicator(size: 20),
                  ),
                );
              }

              // Top of the chat (older messages)
              if (showTopLoader && index == totalCount - 1) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: RetroLoadingIndicator(size: 20),
                  ),
                );
              }

              final actualIndex = showBottomLoader ? index - 1 : index;
              final msgId = messageIds[actualIndex];
              final msgNotifier =
                  widget.client.messengerStore.getMessageNotifier(msgId);
              if (msgNotifier == null) return const SizedBox.shrink();

              final prevMsgId = actualIndex + 1 < messageIds.length
                  ? messageIds[actualIndex + 1]
                  : null;
              final nextMsgId =
                  actualIndex - 1 >= 0 ? messageIds[actualIndex - 1] : null;

              final prevMsg = prevMsgId != null
                  ? widget.client.messengerStore.getMessage(prevMsgId)
                  : null;
              final nextMsg = nextMsgId != null
                  ? widget.client.messengerStore.getMessage(nextMsgId)
                  : null;

              final showUnreadSeparator = msgId == _unreadSeparatorMessageId;

              return RepaintBoundary(
                key: _getKeyForMessage(msgId),
                child: ValueListenableBuilder<Message>(
                  valueListenable: msgNotifier,
                  builder: (context, message, _) {
                    final isDifferentDayFromPrev = prevMsg == null ||
                        !ChatConversationView.isSameDay(message.date, prevMsg.date);
                    final isDifferentDayFromNext = nextMsg == null ||
                        !ChatConversationView.isSameDay(message.date, nextMsg.date);

                    final isFirstInGroup = isDifferentDayFromPrev ||
                        prevMsg.fromId != message.fromId ||
                        prevMsg.isOut != message.isOut ||
                        prevMsg.isSticker ||
                        prevMsg.hasGift ||
                        message.hasGift ||
                        prevMsg.action != null ||
                        (message.date - prevMsg.date).abs() > 300;

                    final isLastInGroup = isDifferentDayFromNext ||
                        nextMsg.fromId != message.fromId ||
                        nextMsg.isOut != message.isOut ||
                        nextMsg.isSticker ||
                        nextMsg.hasGift ||
                        message.hasGift ||
                        nextMsg.action != null ||
                        (nextMsg.date - message.date).abs() > 300;

                    return ValueListenableBuilder<int>(
                      valueListenable: widget.client.userCache.revision,
                      builder: (context, _, child) {
                        final bubble = _buildMessageBubble(
                          message,
                          isWideChat: isWideChat,
                          isFirstInGroup: isFirstInGroup,
                          isLastInGroup: isLastInGroup,
                        );

                        if ((isDifferentDayFromPrev && message.date > 0) || showUnreadSeparator) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isDifferentDayFromPrev && message.date > 0)
                                _buildDateSeparator(message.date),
                              if (showUnreadSeparator)
                                _buildUnreadSeparator(),
                              bubble,
                            ],
                          );
                        }

                        return bubble;
                      },
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(
    Message message, {
    required bool isWideChat,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    if (message.action != null) {
      return _buildActionMessage(message);
    }

    final isOut = message.isOut || message.fromId == widget.currentUserId;
    final isHighlighted = _highlightedMessageId == message.id;

    if (message.isSticker) {
      return _buildStickerMessage(
        message,
        isOut,
        isWideChat: isWideChat,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      );
    }

    final cache = widget.client.userCache;
    final sender = cache.getUser(message.fromId);
    if (sender == null && message.fromId > 0) {
      cache.requestUser(message.fromId);
    } else if (sender == null && message.fromId < 0) {
      cache.requestGroup(message.fromId.abs());
    }

    final myUser = cache.getUser(widget.currentUserId);
    final myAvatarUrl = widget.account.avatarUrl.isNotEmpty
        ? widget.account.avatarUrl
        : myUser?.avatarUrl;
    final myName = myUser?.firstName ??
        (widget.account.name.isNotEmpty
            ? widget.account.name
            : 'Вы');

    final senderName = isOut
        ? 'Вы'
        : (sender?.fullName ??
            (cache.getSenderName(message.fromId).isNotEmpty
                ? cache.getSenderName(message.fromId)
                : 'Собеседник'));

    final isGift = message.hasGift;
    final gift = message.giftAttachment;
    final giftComment = gift?.message.trim() ?? '';
    final rawMsgText = message.text.trim();
    final String effectiveGiftText;
    if (rawMsgText.isNotEmpty && giftComment.isNotEmpty) {
      if (rawMsgText == giftComment) {
        effectiveGiftText = rawMsgText;
      } else {
        effectiveGiftText = '$rawMsgText\n$giftComment';
      }
    } else if (rawMsgText.isNotEmpty) {
      effectiveGiftText = rawMsgText;
    } else {
      effectiveGiftText = giftComment;
    }

    final timeStr = _formatTime(message.date);
    final textStyle = TextStyle(
      color: isGift
          ? const Color(0xFF382A02)
          : (isOut ? const Color(0xFF14293E) : const Color(0xFF1E242B)),
      fontSize: 14.5,
      height: 1.25,
    );
    final timeStyle = TextStyle(
      color: isGift
          ? const Color(0xFF8A6D1C)
          : (isOut ? const Color(0xFF5C7C9E) : const Color(0xFF8692A0)),
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
    );

    final int genderType = sender?.genderType ??
        User.resolveGenderType(sex: sender?.sex, pronouns: sender?.pronouns);
    final String verb = switch (genderType) {
      1 => 'отправила',
      2 => 'отправил',
      _ => 'отправил(а)',
    };

    final String giftHeaderTitle;
    if (isOut) {
      giftHeaderTitle = 'Вы отправили подарок';
    } else if (widget.conversation.isChat) {
      giftHeaderTitle = '$senderName $verb подарок';
    } else {
      giftHeaderTitle = '$verb вам подарок';
    }

    final maxBubbleWidth = isGift
        ? 210.0
        : (isWideChat
            ? 560.0
            : min(MediaQuery.of(context).size.width * 0.78, 420.0));

    final showLeftAvatar = !isOut || isWideChat;
    final showLeftTail = isLastInGroup && (!isOut || isWideChat);
    final showRightTail = isLastInGroup && (isOut && !isWideChat);

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 4.5 : 1.5,
        bottom: isLastInGroup ? 4.5 : 1.5,
      ),
      child: Row(
        mainAxisAlignment: (isOut && !isWideChat)
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showLeftAvatar) ...[
            if (isLastInGroup)
              GestureDetector(
                onTap: () => _openUserProfile(
                    isOut ? widget.currentUserId : message.fromId),
                child: RetroChatAvatar(
                  avatarUrl: isOut ? myAvatarUrl : sender?.avatarUrl,
                  fallbackText: isOut ? myName : (sender?.firstName ?? '?'),
                  size: 32,
                ),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                gradient: isHighlighted
                    ? (isGift
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFEA9F), Color(0xFFE6AE1E)],
                          )
                        : (isOut
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFD6E8FA), Color(0xFFBEDBF7)],
                              )
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFEAF1FB), Color(0xFFD9E7F7)],
                              )))
                    : (isGift
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFF9DB), // Glossy warm gold highlight top
                              Color(0xFFFFDF7D), // Rich gold bottom
                            ],
                          )
                        : (isOut
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFEDF5FE), // Glossy top highlight
                                  Color(0xFFD2E4F7), // Rich soft blue bottom
                                ],
                              )
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFFFFFF), // Pure white gloss top
                                  Color(0xFFEDF1F6), // Soft silver-gray bottom
                                ],
                              ))),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(showLeftTail ? 3 : 14),
                  bottomRight: Radius.circular(showRightTail ? 3 : 14),
                ),
                border: Border.all(
                  color: isHighlighted
                      ? (isGift ? const Color(0xFFC78F0A) : RetroTheme.vkBlue)
                      : (isGift
                          ? const Color(0xFFE0B445)
                          : (isOut
                              ? const Color(0xFFA6C2DE)
                              : const Color(0xFFC5CED8))),
                  width: isHighlighted ? 1.5 : 1.0,
                ),
                boxShadow: [
                  if (isHighlighted)
                    BoxShadow(
                      color: (isGift ? const Color(0xFFE6AE1E) : RetroTheme.vkBlue)
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  else ...[
                    BoxShadow(
                      color: isGift ? const Color(0x248A6D1C) : const Color(0x18000000),
                      offset: const Offset(0, 1),
                      blurRadius: 1.5,
                    ),
                    BoxShadow(
                      color: isGift ? const Color(0x148A6D1C) : const Color(0x06000000),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isGift)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        giftHeaderTitle,
                        style: const TextStyle(
                          color: Color(0xFF7A5500),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (widget.conversation.isChat && isFirstInGroup)
                    if (!isOut || isWideChat)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: GestureDetector(
                          onTap: () => _openUserProfile(
                              isOut ? widget.currentUserId : message.fromId),
                          child: Text(
                            isOut ? 'Вы' : senderName,
                            style: const TextStyle(
                              color: RetroTheme.vkBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  if (message.replyMessage != null ||
                      message.replyMessageId != null)
                    _buildReplyQuote(message, isOut),
                  if (isGift && gift != null)
                    _buildGiftAttachment(gift),
                  if (isGift) ...[
                    if (message.attachments.where((a) => a.type != 'gift').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: RetroAttachmentGrid(
                          attachments: message.attachments
                              .where((a) => a.type != 'gift')
                              .toList(),
                          isOut: isOut,
                          maxWidth: 200,
                        ),
                      ),
                    if (effectiveGiftText.isNotEmpty)
                      _BubbleTextWithTime(
                        text: effectiveGiftText,
                        time: timeStr,
                        textStyle: textStyle,
                        timeStyle: timeStyle,
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(timeStr, style: timeStyle),
                        ),
                      ),
                  ] else ...[
                    if (message.attachments.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: (message.replyMessage != null ||
                                  message.replyMessageId != null)
                              ? 2
                              : 0,
                          bottom: message.text.isNotEmpty ? 5 : 0,
                        ),
                        child: RetroAttachmentGrid(
                          attachments: message.attachments,
                          isOut: isOut,
                          maxWidth: 380,
                        ),
                      ),
                    if (message.text.isNotEmpty)
                      _BubbleTextWithTime(
                        text: message.text,
                        time: timeStr,
                        textStyle: textStyle,
                        timeStyle: timeStyle,
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(timeStr, style: timeStyle),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (isOut && !isWideChat) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildGiftAttachment(GiftAttachment gift) {
    final thumb = gift.bestThumb;
    const double giftSize = 160.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: thumb.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  thumb,
                  width: giftSize,
                  height: giftSize,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: giftSize,
                      height: giftSize,
                      child: Center(
                        child: RetroLoadingIndicator(size: 24),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: giftSize,
                      height: giftSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8A1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE0B445), width: 1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.card_giftcard,
                          size: 56,
                          color: Color(0xFFB8860B),
                        ),
                      ),
                    );
                  },
                ),
              )
            : Container(
                width: giftSize,
                height: giftSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8A1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0B445), width: 1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.card_giftcard,
                    size: 56,
                    color: Color(0xFFB8860B),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildReplyQuote(Message message, bool isOut) {
    final replyId = message.replyMessage?.id ?? message.replyMessageId;
    if (replyId == null) return const SizedBox.shrink();

    final reply = message.replyMessage;
    final cache = widget.client.userCache;

    String authorName = 'Ответ';
    String preview = 'Загрузка...';

    if (reply != null) {
      if (reply.fromId == widget.currentUserId) {
        authorName = 'Вы';
      } else if (reply.fromId > 0) {
        final user = cache.getUser(reply.fromId);
        authorName = user?.fullName ?? cache.getSenderName(reply.fromId);
        if (authorName.isEmpty) authorName = 'Пользователь';
      } else if (reply.fromId < 0) {
        final group = cache.getGroup(reply.fromId.abs());
        authorName = group?.name ?? 'Сообщество';
      }
      preview = reply.previewText;
    } else {
      authorName = 'Сообщение #$replyId';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _jumpToMessage(replyId),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              color: isOut ? const Color(0x14000000) : const Color(0x0C000000),
              borderRadius: BorderRadius.circular(4),
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: RetroTheme.vkBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RetroTheme.textLink,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RetroTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerMessage(
    Message message,
    bool isOut, {
    required bool isWideChat,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    final sticker = message.stickerAttachment;
    final stickerUrl = sticker?.bestImage ?? '';

    final cache = widget.client.userCache;
    final sender = cache.getUser(message.fromId);
    if (sender == null && message.fromId > 0) {
      cache.requestUser(message.fromId);
    } else if (sender == null && message.fromId < 0) {
      cache.requestGroup(message.fromId.abs());
    }

    final myUser = cache.getUser(widget.currentUserId);
    final myAvatarUrl = widget.account.avatarUrl.isNotEmpty
        ? widget.account.avatarUrl
        : myUser?.avatarUrl;
    final myName = myUser?.firstName ??
        (widget.account.name.isNotEmpty
            ? widget.account.name
            : 'Вы');

    final showLeftAvatar = !isOut || isWideChat;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 4 : 1.5,
        bottom: isLastInGroup ? 4 : 1.5,
      ),
      child: Row(
        mainAxisAlignment: (isOut && !isWideChat)
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showLeftAvatar) ...[
            if (isLastInGroup)
              GestureDetector(
                onTap: () => _openUserProfile(
                    isOut ? widget.currentUserId : message.fromId),
                child: RetroChatAvatar(
                  avatarUrl: isOut ? myAvatarUrl : sender?.avatarUrl,
                  fallbackText: isOut ? myName : (sender?.firstName ?? '?'),
                  size: 32,
                ),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: (isOut && !isWideChat)
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.replyMessage != null ||
                  message.replyMessageId != null)
                _buildReplyQuote(message, isOut),
              Stack(
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: stickerUrl.isNotEmpty
                        ? Image.network(
                            stickerUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildStickerFallback(sticker?.stickerId ?? 0),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: RetroLoadingIndicator(size: 20),
                              );
                            },
                          )
                        : _buildStickerFallback(sticker?.stickerId ?? 0),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x66000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isOut) ...[
                            const SizedBox(width: 3),
                            Icon(
                              message.isUnread ? Icons.done : Icons.done_all,
                              size: 11,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isOut && !isWideChat) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildStickerFallback(int stickerId) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0x0C000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x18000000)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_satisfied_alt_rounded,
              size: 44,
              color: Color(0xFF8B98A7),
            ),
            const SizedBox(height: 6),
            Text(
              stickerId > 0 ? 'Стикер #$stickerId' : 'Стикер',
              style: const TextStyle(
                color: Color(0xFF8B98A7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMessage(Message message) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.client.userCache.revision,
      builder: (context, _, child) {
        final text = message.formatActionText(
          currentUserId: widget.currentUserId,
          userCache: widget.client.userCache,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7B8D),
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F4F7),
        border: Border(
          top: BorderSide(color: Color(0xFFC7D0DA), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB5C4D4), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      offset: Offset(0, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Сообщение...',
                    hintStyle: TextStyle(
                      color: Color(0xFF909BA7),
                      fontSize: 14.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: RetroTheme.buttonGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1B4E87), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: _isSending
                      ? const RetroLoadingIndicator(size: 16)
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _BubbleTextWithTime extends StatelessWidget {
  final String text;
  final String time;
  final TextStyle textStyle;
  final TextStyle timeStyle;

  const _BubbleTextWithTime({
    required this.text,
    required this.time,
    required this.textStyle,
    required this.timeStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const spacing = 7.0;

        final timePainter = TextPainter(
          text: TextSpan(text: time, style: timeStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPainter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);

        final lines = textPainter.computeLineMetrics();
        final timeWidth = timePainter.width;

        // 1. Single-line: check if text + spacing + time fits on 1 line
        if (lines.length <= 1) {
          final singleLineWidth = textPainter.width;
          if (singleLineWidth + spacing + timeWidth <= maxWidth) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(text, style: textStyle),
                ),
                const SizedBox(width: spacing),
                Text(time, style: timeStyle),
              ],
            );
          }
        }

        // 2. Multi-line: check if last line has space for time without expanding block width
        if (lines.isNotEmpty) {
          final lastLine = lines.last;
          final maxLineWidth = lines.map((l) => l.width).reduce(max);

          // If last line width + spacing + time fits within maxWidth and doesn't exceed the widest line + 8
          if (lastLine.width + spacing + timeWidth <= maxWidth &&
              lastLine.width + spacing + timeWidth <= max(maxLineWidth, 60.0) + 8) {
            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text, style: textStyle),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: spacing),
                      child: Text(time, style: timeStyle),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        // 3. Time does not fit on the same line -> wrap to second line, aligned to the right, fit-content!
        return IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: textStyle),
              const SizedBox(height: 1.5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(time, style: timeStyle),
              ),
            ],
          ),
        );
      },
    );
  }
}
