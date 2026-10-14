import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/messages_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/conversations_response.dart';
import '../../../core/models/message.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_attachment_grid.dart';
import '../../widgets/retro_chat_avatar.dart';
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

  const ChatConversationView({
    super.key,
    required this.client,
    required this.account,
    required this.conversation,
    required this.title,
    this.avatarUrl,
    this.memberAvatars,
    required this.currentUserId,
  });

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  late final MessagesHandler _messagesHandler;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    if (userId <= 0) return;
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
    _messagesHandler = MessagesHandler(widget.client);
    _scrollController.addListener(_onScroll);
    _loadHistory();
    _markRead();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

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

  Future<void> _markRead() async {
    if (widget.conversation.unreadCount > 0) {
      widget.client.messengerStore.onReadIncoming(
        widget.conversation.peerId,
        widget.conversation.lastMessage.id,
      );
      await _messagesHandler.markAsRead(peerId: widget.conversation.peerId);
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    final existingMessages = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId)
        .value;

    if (existingMessages.isEmpty || refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final res = await _messagesHandler.getHistory(
      peerId: widget.conversation.peerId,
      offset: 0,
      count: 40,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _historyOffset = data.items.length;
        _hasMore = _historyOffset < data.count && data.items.isNotEmpty;
        _isLoading = false;
        _isAtLatest = true;
        _errorMessage = null;
      });
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

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
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
                    if (widget.conversation.isChat)
                      Text(
                        '${widget.conversation.chatSettings?.membersCount ?? 2} участников',
                        style: const TextStyle(
                          color: Color(0xFFC8D7E8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFE4E8EE),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildMessagesList(),
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
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    final orderNotifier = widget.client.messengerStore
        .getChatMessageOrderNotifier(widget.conversation.peerId);

    return ValueListenableBuilder<List<int>>(
      valueListenable: orderNotifier,
      builder: (context, messageIds, _) {
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

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

            return RepaintBoundary(
              key: _getKeyForMessage(msgId),
              child: ValueListenableBuilder<Message>(
                valueListenable: msgNotifier,
                builder: (context, message, _) {
                  final isFirstInGroup = prevMsg == null ||
                      prevMsg.fromId != message.fromId ||
                      prevMsg.isOut != message.isOut ||
                      prevMsg.isSticker ||
                      (message.date - prevMsg.date).abs() > 300;

                  final isLastInGroup = nextMsg == null ||
                      nextMsg.fromId != message.fromId ||
                      nextMsg.isOut != message.isOut ||
                      nextMsg.isSticker ||
                      (nextMsg.date - message.date).abs() > 300;

                  return ValueListenableBuilder<int>(
                    valueListenable: widget.client.userCache.revision,
                    builder: (context, _, child) {
                      return _buildMessageBubble(
                        message,
                        isFirstInGroup: isFirstInGroup,
                        isLastInGroup: isLastInGroup,
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(
    Message message, {
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    final isOut = message.isOut || message.fromId == widget.currentUserId;
    final isHighlighted = _highlightedMessageId == message.id;

    if (message.isSticker) {
      return _buildStickerMessage(
        message,
        isOut,
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

    final senderName = sender?.fullName ??
        (isOut
            ? 'Вы'
            : (cache.getSenderName(message.fromId).isNotEmpty
                ? cache.getSenderName(message.fromId)
                : 'Собеседник'));

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 4 : 1.5,
        bottom: isLastInGroup ? 4 : 1.5,
      ),
      child: Row(
        mainAxisAlignment:
            isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOut) ...[
            if (isLastInGroup)
              GestureDetector(
                onTap: () => _openUserProfile(message.fromId),
                child: RetroChatAvatar(
                  avatarUrl: sender?.avatarUrl,
                  fallbackText: sender?.firstName ?? '?',
                  size: 32,
                ),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? (isOut ? const Color(0xFFD8E7FA) : const Color(0xFFE8F1FC))
                    : (isOut ? RetroTheme.msgOutBubble : RetroTheme.msgInBubble),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHighlighted
                      ? RetroTheme.vkBlue
                      : (isOut ? RetroTheme.msgOutBorder : RetroTheme.msgInBorder),
                  width: isHighlighted ? 1.5 : 1,
                ),
                boxShadow: [
                  if (isHighlighted)
                    BoxShadow(
                      color: RetroTheme.vkBlue.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  else
                    const BoxShadow(
                      color: Color(0x10000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOut && widget.conversation.isChat && isFirstInGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: GestureDetector(
                        onTap: () => _openUserProfile(message.fromId),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: RetroTheme.textLink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (message.replyMessage != null ||
                      message.replyMessageId != null)
                    _buildReplyQuote(message, isOut),
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: RetroTheme.textPrimary,
                        fontSize: 14.5,
                      ),
                    ),
                  if (message.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: RetroAttachmentGrid(
                        attachments: message.attachments,
                        isOut: isOut,
                        maxWidth: 380,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatTime(message.date),
                      style: const TextStyle(
                        color: RetroTheme.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOut) const SizedBox(width: 4),
        ],
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

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 4 : 1.5,
        bottom: isLastInGroup ? 4 : 1.5,
      ),
      child: Row(
        mainAxisAlignment:
            isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOut) ...[
            if (isLastInGroup)
              GestureDetector(
                onTap: () => _openUserProfile(message.fromId),
                child: RetroChatAvatar(
                  avatarUrl: sender?.avatarUrl,
                  fallbackText: sender?.firstName ?? '?',
                  size: 32,
                ),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
          if (isOut) const SizedBox(width: 4),
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
