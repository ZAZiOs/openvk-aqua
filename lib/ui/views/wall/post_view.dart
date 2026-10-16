import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/api/wall_handler.dart';
import '../../../core/models/post.dart';
import '../../../core/models/post_comment.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_attachment_grid.dart';
import '../../widgets/retro_avatar.dart';
import '../../widgets/retro_ios6_dialog.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import 'wall_view.dart';
import 'widgets/wall_post_card.dart';

enum _CommentAction {
  reply,
  delete,
  copy,
}

class PostView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final Post post;
  final ValueChanged<Post>? onPostUpdated;

  const PostView({
    super.key,
    required this.client,
    required this.account,
    required this.post,
    this.onPostUpdated,
  });

  @override
  State<PostView> createState() => _PostViewState();
}

class _PostViewState extends State<PostView> {
  late final WallHandler _wallHandler;
  late Post _post;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  List<PostComment> _comments = [];
  int _commentsCount = 0;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  PostComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _commentsCount = _post.commentsCount;
    _wallHandler = WallHandler(widget.client);
    _loadComments();
    _refreshPost();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _updatePost(Post updated) {
    if (!mounted) return;
    setState(() => _post = updated);
    widget.onPostUpdated?.call(updated);
  }

  Future<void> _refreshPost() async {
    try {
      final res = await _wallHandler.getPostById(
        ownerId: _post.ownerId,
        postId: _post.id,
      );
      if (res.isSuccess && res.dataOrNull != null) {
        _updatePost(res.dataOrNull!);
      }
    } catch (_) {}
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _wallHandler.getComments(
        ownerId: _post.ownerId,
        postId: _post.id,
        offset: 0,
        count: 100,
        sort: 'asc',
      );

      if (!mounted) return;

      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull!;
        setState(() {
          _comments = data.items;
          _commentsCount = data.count > 0 ? data.count : data.items.length;
          _isLoading = false;
        });
        if (_post.commentsCount != _commentsCount) {
          _updatePost(_post.copyWith(commentsCount: _commentsCount));
        }
      } else {
        setState(() {
          _error = res.errorOrNull?.message ?? 'Не удалось загрузить комментарии';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка сети: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final replyId = _replyingTo?.id;

    try {
      final res = await _wallHandler.createComment(
        ownerId: _post.ownerId,
        postId: _post.id,
        message: text,
        replyToComment: replyId,
      );

      if (!mounted) return;

      if (res.isSuccess) {
        _commentController.clear();
        setState(() {
          _replyingTo = null;
          _isSending = false;
        });
        await _loadComments(refresh: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorOrNull?.message ?? 'Не удалось отправить комментарий'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _handleDeleteComment(PostComment comment) async {
    final confirm = await showIos6ConfirmDialog(
      context: context,
      title: 'Удаление комментария',
      message: 'Вы действительно хотите удалить этот комментарий?',
      cancelText: 'Отмена',
      confirmText: 'Удалить',
      isDestructive: true,
    );

    if (confirm != true) return;

    final res = await _wallHandler.deleteComment(
      ownerId: _post.ownerId,
      commentId: comment.id,
    );

    if (!mounted) return;

    if (res.isSuccess) {
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _commentsCount = (_commentsCount - 1).clamp(0, 999999);
      });
      _updatePost(_post.copyWith(commentsCount: _commentsCount));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorOrNull?.message ?? 'Не удалось удалить комментарий'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _handleDeletePost() async {
    final confirm = await showIos6ConfirmDialog(
      context: context,
      title: 'Удаление записи',
      message: 'Вы действительно хотите удалить эту запись со стены?',
      cancelText: 'Отмена',
      confirmText: 'Удалить',
      isDestructive: true,
    );

    if (confirm != true) return;

    final res = await _wallHandler.deletePost(
      ownerId: _post.ownerId,
      postId: _post.id,
    );

    if (!mounted) return;

    if (res.isSuccess) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorOrNull?.message ?? 'Не удалось удалить запись'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _showCommentMenu(PostComment comment) async {
    final canDelete = comment.fromId == widget.account.userId ||
        _post.ownerId == widget.account.userId;

    final actions = <Ios6DialogAction<_CommentAction>>[
      const Ios6DialogAction(
        text: 'Ответить',
        value: _CommentAction.reply,
        isPrimary: true,
      ),
      if (canDelete)
        const Ios6DialogAction(
          text: 'Удалить',
          value: _CommentAction.delete,
          isDestructive: true,
        ),
      if (comment.text.isNotEmpty)
        const Ios6DialogAction(
          text: 'Скопировать текст',
          value: _CommentAction.copy,
        ),
    ];

    final action = await showIos6ActionsDialog<_CommentAction>(
      context: context,
      title: 'Действие с комментарием',
      message: comment.text,
      actions: actions,
      cancelText: 'Отмена',
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _CommentAction.reply:
        setState(() => _replyingTo = comment);
        _commentFocusNode.requestFocus();
        break;
      case _CommentAction.delete:
        await _handleDeleteComment(comment);
        break;
      case _CommentAction.copy:
        await Clipboard.setData(ClipboardData(text: comment.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Текст скопирован в буфер обмена'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
    }
  }

  Future<void> _handleToggleCommentLike(PostComment comment) async {
    final isLiked = comment.userLikes;
    final newCount = isLiked ? (comment.likesCount - 1).clamp(0, 999999) : comment.likesCount + 1;

    setState(() {
      final idx = _comments.indexWhere((c) => c.id == comment.id);
      if (idx != -1) {
        _comments[idx] = comment.copyWith(userLikes: !isLiked, likesCount: newCount);
      }
    });

    final res = await _wallHandler.toggleCommentLike(
      ownerId: _post.ownerId,
      commentId: comment.id,
      isCurrentlyLiked: isLiked,
    );

    if (res.isSuccess && mounted) {
      setState(() {
        final idx = _comments.indexWhere((c) => c.id == comment.id);
        if (idx != -1) {
          _comments[idx] = comment.copyWith(userLikes: !isLiked, likesCount: res.dataOrNull);
        }
      });
    }
  }

  Future<void> _handleTogglePostLike() async {
    final isLiked = _post.userLikes;
    final newCount = isLiked ? (_post.likesCount - 1).clamp(0, 999999) : _post.likesCount + 1;

    _updatePost(_post.copyWith(userLikes: !isLiked, likesCount: newCount));

    final res = await _wallHandler.toggleLike(
      ownerId: _post.ownerId,
      postId: _post.id,
      isCurrentlyLiked: isLiked,
    );

    if (res.isSuccess && mounted) {
      _updatePost(_post.copyWith(likesCount: res.dataOrNull));
    }
  }

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

  void _openRepostView(Post repost) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostView(
          client: widget.client,
          account: widget.account,
          post: repost,
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';

    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final hourStr = dt.hour.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr';

    if (isToday) return 'сегодня в $timeStr';
    if (isYesterday) return 'вчера в $timeStr';

    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    final monthStr = dt.month >= 1 && dt.month <= 12 ? months[dt.month] : '';

    if (dt.year == now.year) {
      return '${dt.day} $monthStr в $timeStr';
    }
    return '${dt.day} $monthStr ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RetroAppBar(
        title: 'Запись',
        showBackButton: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isConstrained = constraints.maxWidth > 800;

          return Container(
            color: isConstrained ? const Color(0xFFCAD4DF) : const Color(0xFFF0F2F5),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  border: isConstrained
                      ? const Border.symmetric(
                          vertical: BorderSide(
                            color: Color(0xFFB8C5D3),
                            width: 1,
                          ),
                        )
                      : null,
                  boxShadow: isConstrained
                      ? const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: RetroPullToRefresh(
                        onRefresh: () async {
                          await _refreshPost();
                          await _loadComments(refresh: true);
                        },
                        child: ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          children: [
                            // The Post itself
                            WallPostCard(
                              post: _post,
                              onLikeToggle: _handleTogglePostLike,
                              onCommentsTap: () {
                                _commentFocusNode.requestFocus();
                              },
                              onAuthorTap: _openUserProfile,
                              onRepostContentTap: _openRepostView,
                              onDeleteTap: (_post.fromId == widget.account.userId ||
                                      _post.ownerId == widget.account.userId)
                                  ? _handleDeletePost
                                  : null,
                            ),

                            // Comments Section Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                              child: Row(
                                children: [
                                  Text(
                                    'КОММЕНТАРИИ ($_commentsCount)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4C566C),
                                      letterSpacing: 0.3,
                                      shadows: [
                                        Shadow(
                                          color: Colors.white,
                                          offset: Offset(0, 1),
                                          blurRadius: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isLoading)
                                    const RetroLoadingIndicator(size: 14),
                                ],
                              ),
                            ),

                            // Comments content
                            if (_isLoading && _comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 36),
                                child: Center(child: RetroLoadingIndicator(size: 24)),
                              )
                            else if (_error != null && _comments.isEmpty)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBCC4CE), width: 1),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: RetroTheme.textSecondary,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () => _loadComments(refresh: true),
                                        child: const Text('Повторить попытку'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (_comments.isEmpty)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBCC4CE), width: 1),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 42,
                                      color: Color(0xFFB5C2D0),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Здесь пока нет комментариев',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: RetroTheme.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Будьте первым, кто оставит свой комментарий!',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: RetroTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBCC4CE), width: 1),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Column(
                                    children: [
                                      for (int i = 0; i < _comments.length; i++) ...[
                                        _buildCommentTile(_comments[i]),
                                        if (i < _comments.length - 1)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 58),
                                            child: Container(
                                              height: 1,
                                              color: RetroTheme.itemDivider,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Comment Input Bar
                    if (_post.canPostComments)
                      _buildCommentInputBar()
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE4E8EE),
                          border: Border(top: BorderSide(color: Color(0xFFCBD2DA))),
                        ),
                        child: const Text(
                          'Комментирование этой записи ограничено',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: RetroTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentTile(PostComment comment) {
    return InkWell(
      onTap: () => _showCommentMenu(comment),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Avatar
            GestureDetector(
              onTap: () => _openUserProfile(comment.fromId),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFC0C7D0), width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3.5),
                  child: RetroAvatar(
                    url: comment.authorAvatarUrl,
                    size: 38,
                    fallbackText: comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Author Name & Timestamp
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openUserProfile(comment.fromId),
                          child: Text(
                            comment.authorName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B4764),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(comment.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: RetroTheme.textMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Text
                  if (comment.text.isNotEmpty)
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: Color(0xFF1E242B),
                      ),
                    ),

                  // Attachments
                  if (comment.attachments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    RetroAttachmentGrid(attachments: comment.attachments),
                  ],

                  const SizedBox(height: 4),

                  // Actions: Like on the right
                  Row(
                    children: [
                      const Spacer(),

                      // Like button for comment
                      InkWell(
                        onTap: () => _handleToggleCommentLike(comment),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: comment.userLikes
                                ? const Color(0xFFFFF0F1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: comment.userLikes
                                ? Border.all(color: const Color(0xFFE59CA5), width: 0.8)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.userLikes
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 13,
                                color: comment.userLikes
                                    ? const Color(0xFFD62B42)
                                    : const Color(0xFF758595),
                              ),
                              if (comment.likesCount > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${comment.likesCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: comment.userLikes
                                        ? const Color(0xFFD62B42)
                                        : const Color(0xFF556677),
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInputBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECEFF3), Color(0xFFD6DBE2)],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFB5BDC6), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x15000000),
            offset: Offset(0, -1),
            blurRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: const Color(0xFFE2E7ED),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 14, color: Color(0xFF4C75A3)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ответ для ${_replyingTo!.authorName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4C75A3),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _replyingTo = null),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 16, color: Color(0xFF758595)),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF9EACB9), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            offset: Offset(0, 1),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                        style: const TextStyle(fontSize: 14, color: RetroTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Написать комментарий...',
                          hintStyle: TextStyle(fontSize: 13.5, color: RetroTheme.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _isSending ? null : _sendComment,
      child: Container(
        width: 34,
        height: 34,
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
                  size: 18,
                ),
        ),
      ),
    );
  }
}
