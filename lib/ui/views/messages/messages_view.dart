import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/messages_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/models/conversation.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_chat_avatar.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import 'chat_conversation_view.dart';

class MessagesView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final String filter;

  const MessagesView({
    super.key,
    required this.client,
    required this.account,
    this.filter = 'all',
  });

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  late final MessagesHandler _messagesHandler;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _allOffset = 0;
  bool _hasMoreAll = true;

  int _unreadOffset = 0;
  bool _hasMoreUnread = true;
  bool _hasFetchedUnread = false;

  late String _currentFilter;
  String _searchQuery = '';

  bool get _hasMore => _currentFilter == 'unread' ? _hasMoreUnread : _hasMoreAll;
  int get _pageSize => _currentFilter == 'unread' ? 10 : 30;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _messagesHandler = MessagesHandler(widget.client);
    _scrollController.addListener(_onScroll);
    _loadConversations();
  }

  @override
  void didUpdateWidget(covariant MessagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _currentFilter = widget.filter;
      _onFilterChanged();
    }
  }

  void _onFilterChanged() {
    if (_currentFilter == 'unread') {
      final existingUnreads =
          widget.client.messengerStore.unreadConversationOrder.value;
      if (existingUnreads.isNotEmpty) {
        // Instantly display already loaded unread chats from RAM without full reload
        // and trigger background lazy-loading check with count: 10
        _checkMoreUnread();
      } else if (!_hasFetchedUnread) {
        _loadConversations(refresh: false);
      }
    } else {
      final existingAll =
          widget.client.messengerStore.conversationOrder.value;
      if (existingAll.isEmpty) {
        _loadConversations(refresh: false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreConversations();
    }
  }

  Future<void> _checkMoreUnread() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final res = await _messagesHandler.getConversations(
      offset: _unreadOffset,
      count: 10,
      filter: 'unread',
      extended: true,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _hasFetchedUnread = true;
        _unreadOffset += data.items.length;
        _hasMoreUnread = _unreadOffset < data.count && data.items.isNotEmpty;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadConversations({bool refresh = false}) async {
    final currentList = _currentFilter == 'unread'
        ? widget.client.messengerStore.unreadConversationOrder.value
        : widget.client.messengerStore.conversationOrder.value;

    if (currentList.isEmpty && !refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final currentCount = _pageSize;

    final res = await _messagesHandler.getConversations(
      offset: 0,
      count: currentCount,
      filter: _currentFilter,
      extended: true,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        if (_currentFilter == 'unread') {
          _unreadOffset = data.items.length;
          _hasMoreUnread = _unreadOffset < data.count && data.items.isNotEmpty;
          _hasFetchedUnread = true;
        } else {
          _allOffset = data.items.length;
          _hasMoreAll = _allOffset < data.count && data.items.isNotEmpty;
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        if (currentList.isEmpty) {
          _errorMessage = res.errorOrNull?.message ?? 'Ошибка загрузки диалогов';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreConversations() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final currentOffset =
        _currentFilter == 'unread' ? _unreadOffset : _allOffset;
    final currentCount = _pageSize;

    final res = await _messagesHandler.getConversations(
      offset: currentOffset,
      count: currentCount,
      filter: _currentFilter,
      extended: true,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        if (_currentFilter == 'unread') {
          _unreadOffset += data.items.length;
          _hasMoreUnread = _unreadOffset < data.count && data.items.isNotEmpty;
        } else {
          _allOffset += data.items.length;
          _hasMoreAll = _allOffset < data.count && data.items.isNotEmpty;
        }
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }


  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();

    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (isToday) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) {
      return 'Вчера';
    }

    const months = [
      '',
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];

    if (date.year == now.year) {
      return '${date.day} ${months[date.month]}';
    }

    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = date.month.toString().padLeft(2, '0');
    final yearStr = (date.year % 100).toString().padLeft(2, '0');
    return '$dayStr.$monthStr.$yearStr';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeaderToolbar(),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildHeaderToolbar() {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Inset iOS Search Bar
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB5C4D4), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF7A889B),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(
                      fontSize: 14,
                      color: RetroTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Поиск по сообщениям',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF919FAF),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.cancel,
                        size: 16,
                        color: Color(0xFF8B98A7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final orderNotifier = _currentFilter == 'unread'
        ? widget.client.messengerStore.unreadConversationOrder
        : widget.client.messengerStore.conversationOrder;

    return ValueListenableBuilder<List<int>>(
      valueListenable: orderNotifier,
      builder: (context, peerIds, _) {
        final List<int> displayPeerIds;
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.trim().toLowerCase();
          displayPeerIds = peerIds.where((peerId) {
            final conv = widget.client.messengerStore.getConversationNotifier(peerId)?.value;
            if (conv == null) return false;
            final title = widget.client.messengerStore.getTitle(conv).toLowerCase();
            final lastMsg = conv.lastMessage.previewText.toLowerCase();
            return title.contains(query) || lastMsg.contains(query);
          }).toList();
        } else {
          displayPeerIds = peerIds;
        }

        if (_isLoading && displayPeerIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RetroLoadingIndicator(size: 28),
                const SizedBox(height: 12),
                Text(
                  _currentFilter == 'unread'
                      ? 'Проверка непрочитанных...'
                      : 'Загрузка диалогов...',
                  style: const TextStyle(
                    color: RetroTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (_errorMessage != null && displayPeerIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RetroTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => _loadConversations(refresh: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RetroTheme.vkBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Повторить попытку'),
                  ),
                ],
              ),
            ),
          );
        }

        if (displayPeerIds.isEmpty) {
          if (_isLoadingMore) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RetroLoadingIndicator(size: 28),
                  SizedBox(height: 12),
                  Text(
                    'Проверка непрочитанных...',
                    style: TextStyle(
                      color: RetroTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final String emptyText = _searchQuery.isNotEmpty
              ? 'По запросу ничего не найдено'
              : _currentFilter == 'unread'
                  ? 'Нет непрочитанных сообщений'
                  : 'У Вас пока нет сообщений';

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 48,
                  color: Color(0xFF919FAF),
                ),
                const SizedBox(height: 12),
                Text(
                  emptyText,
                  style: const TextStyle(
                    color: RetroTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return RetroPullToRefresh(
          controller: _scrollController,
          onRefresh: () => _loadConversations(refresh: true),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayPeerIds.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayPeerIds.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: RetroLoadingIndicator(size: 22)),
                );
              }

              final peerId = displayPeerIds[index];
              final notifier = widget.client.messengerStore.getConversationNotifier(peerId);
              if (notifier == null) return const SizedBox.shrink();

              return RepaintBoundary(
                key: ValueKey(peerId),
                child: ValueListenableBuilder<ConversationItem>(
                  valueListenable: notifier,
                  builder: (context, item, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: widget.client.userCache.revision,
                      builder: (context, _, __) {
                        return _buildConversationTile(item);
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

  void _openChat(ConversationItem item) {
    final store = widget.client.messengerStore;
    final title = store.getTitle(item);
    final avatarUrl = store.getAvatarUrl(item);
    final memberAvatars = store.getChatMemberAvatars(item);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatConversationView(
          client: widget.client,
          conversation: item,
          title: title,
          avatarUrl: avatarUrl,
          memberAvatars: memberAvatars,
          currentUserId: widget.account.userId,
        ),
      ),
    );
  }

  Widget _buildConversationTile(ConversationItem item) {
    final store = widget.client.messengerStore;
    final title = store.getTitle(item);
    final avatarUrl = store.getAvatarUrl(item);
    final memberAvatars = store.getChatMemberAvatars(item);

    final bool isUserOnline = !item.isChat &&
        item.isUser &&
        store.userCache.getUser(item.peerId)?.isOnline == true;

    final lastMsg = item.lastMessage;
    final isOut = lastMsg.isOut || lastMsg.fromId == widget.account.userId;

    String? senderPrefix;
    if (isOut) {
      senderPrefix = 'Вы: ';
    } else if (item.isChat && lastMsg.fromId != 0) {
      final senderName = store.userCache.getSenderName(lastMsg.fromId);
      if (senderName.isNotEmpty) {
        senderPrefix = '$senderName: ';
      } else {
        if (lastMsg.fromId > 0) {
          store.userCache.requestUser(lastMsg.fromId);
        } else if (lastMsg.fromId < 0) {
          store.userCache.requestGroup(lastMsg.fromId.abs());
        }
      }
    }

    final hasUnreadCount = item.unreadCount > 0;
    final isUnreadOut = isOut && !item.isOutRead;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openChat(item),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Retro Avatar: if chat has no cover photo, renders a 2x2 grid of up to 4 participants!
                  RetroChatAvatar(
                    avatarUrl: avatarUrl,
                    members: memberAvatars,
                    fallbackText: title,
                    size: 50,
                    isOnline: isUserOnline,
                  ),
                  const SizedBox(width: 12),
                  // Chat title, message snippet, and timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.isChat)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.people_alt_rounded,
                                  size: 14,
                                  color: Color(0xFF6B7B8D),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RetroTheme.textPrimary,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimestamp(lastMsg.date),
                              style: const TextStyle(
                                color: RetroTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    if (senderPrefix != null)
                                      TextSpan(
                                        text: senderPrefix,
                                        style: TextStyle(
                                          color: isOut
                                              ? const Color(0xFF4A6B8D)
                                              : RetroTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    TextSpan(
                                      text: lastMsg.previewText,
                                      style: TextStyle(
                                        color: isOut
                                            ? const Color(0xFF5A6675)
                                            : RetroTheme.textSecondary,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (hasUnreadCount)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: RetroTheme.badgeBlue,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  item.unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (isUnreadOut)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4C75A3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Hairline separator indented by 74px (past avatar)
            Padding(
              padding: const EdgeInsets.only(left: 74),
              child: Container(
                height: 1,
                color: RetroTheme.itemDivider,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
