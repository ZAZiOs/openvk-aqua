import 'package:flutter/material.dart';

import '../../../core/api/messages_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/conversations_response.dart';
import '../../../core/models/message.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_chat_avatar.dart';
import '../../widgets/retro_loading_indicator.dart';

class ChatConversationView extends StatefulWidget {
  final OpenVkClient client;
  final ConversationItem conversation;
  final String title;
  final String? avatarUrl;
  final List<ChatMemberAvatarInfo>? memberAvatars;
  final int currentUserId;

  const ChatConversationView({
    super.key,
    required this.client,
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
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _messagesHandler = MessagesHandler(widget.client);
    _loadHistory();
    _markRead();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    if (widget.conversation.unreadCount > 0) {
      await _messagesHandler.markAsRead(peerId: widget.conversation.peerId);
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _messagesHandler.getHistory(
      peerId: widget.conversation.peerId,
      count: 40,
      cachePolicy: refresh ? CachePolicy.networkFirst : CachePolicy.cacheFirst,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.errorOrNull?.message ?? 'Не удалось загрузить историю сообщений';
        _isLoading = false;
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
        titleWidget: Row(
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
      body: Container(
        color: const Color(0xFFE4E8EE),
        child: Column(
          children: [
            Expanded(
              child: _buildMessagesList(),
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

        return RefreshIndicator(
          onRefresh: () => _loadHistory(refresh: true),
          color: RetroTheme.vkBlue,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: messageIds.length,
            itemBuilder: (context, index) {
              final msgId = messageIds[index];
              final msgNotifier =
                  widget.client.messengerStore.getMessageNotifier(msgId);
              if (msgNotifier == null) return const SizedBox.shrink();

              return RepaintBoundary(
                key: ValueKey(msgId),
                child: ValueListenableBuilder<Message>(
                  valueListenable: msgNotifier,
                  builder: (context, message, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: widget.client.userCache.revision,
                      builder: (context, _, __) {
                        return _buildMessageBubble(message);
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

  Widget _buildMessageBubble(Message message) {
    final isOut = message.isOut || message.fromId == widget.currentUserId;
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOut) ...[
            RetroChatAvatar(
              avatarUrl: sender?.avatarUrl,
              fallbackText: sender?.firstName ?? '?',
              size: 32,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOut ? RetroTheme.msgOutBubble : RetroTheme.msgInBubble,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOut ? RetroTheme.msgOutBorder : RetroTheme.msgInBorder,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOut && widget.conversation.isChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          color: RetroTheme.textLink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: RetroTheme.textPrimary,
                        fontSize: 14.5,
                      ),
                    ),
                  if (message.attachments.isNotEmpty)
                    ...message.attachments.map((att) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            att.summaryText,
                            style: const TextStyle(
                              color: RetroTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        )),
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

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F4F7),
        border: Border(
          top: BorderSide(color: Color(0xFFC7D0DA), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
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
    );
  }
}
