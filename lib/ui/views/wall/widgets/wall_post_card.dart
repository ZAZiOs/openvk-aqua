import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/post.dart';
import '../../../widgets/retro_attachment_grid.dart';
import '../../../widgets/retro_avatar.dart';
import '../../../widgets/retro_ios6_dialog.dart';
import '../../../utils/retro_text_parser.dart';

enum _PostAction {
  open,
  copy,
  repost,
  delete,
}

class WallPostCard extends StatefulWidget {
  final Post post;
  final bool isFeed;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onRepostTap;
  final VoidCallback? onDeleteTap;
  final ValueChanged<int>? onAuthorTap;
  final VoidCallback? onPostTap;
  final ValueChanged<Post>? onRepostContentTap;

  const WallPostCard({
    super.key,
    required this.post,
    this.isFeed = false,
    this.onLikeToggle,
    this.onCommentsTap,
    this.onRepostTap,
    this.onDeleteTap,
    this.onAuthorTap,
    this.onPostTap,
    this.onRepostContentTap,
  });

  @override
  State<WallPostCard> createState() => _WallPostCardState();
}

class _WallPostCardState extends State<WallPostCard> {
  bool _isExpanded = false;

  String _formatDate(int timestamp) {
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
    final post = widget.post;
    final text = post.text.trim();
    final bool isLongText = text.length > 280 || '\n'.allMatches(text).length > 4;
    final String displayText = (isLongText && !_isExpanded)
        ? '${text.substring(0, text.length > 250 ? 250 : text.length)}...'
        : text;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showPostActions(context),
        onSecondaryTap: () => _showPostActions(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Date
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => widget.onAuthorTap?.call(post.fromId),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFC0C7D0),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: RetroAvatar(
                          url: post.authorAvatarUrl,
                          size: 40,
                          fallbackText: post.authorName.isNotEmpty
                              ? post.authorName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => widget.onAuthorTap?.call(post.fromId),
                          child: Text(
                            post.authorName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF22446B),
                              shadows: [
                                Shadow(
                                  color: Color(0x22FFFFFF),
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.isFeed && post.ownerId != post.fromId) ...[
                          const SizedBox(height: 1),
                          GestureDetector(
                            onTap: () => widget.onAuthorTap?.call(post.ownerId),
                            child: Text(
                              post.ownerId < 0
                                  ? 'в группе ${post.wallOwnerName.isNotEmpty ? post.wallOwnerName : 'сообществе'}'
                                  : 'на стене у ${post.wallOwnerName.isNotEmpty ? post.wallOwnerName : 'пользователя'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF4C75A3),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        Text(
                          _formatDate(post.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7A8999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isFeed && post.isPinned)
                    Container(
                      margin: const EdgeInsets.only(right: 4, top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCAD4DF), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_rounded, size: 11, color: Color(0xFF4C75A3)),
                          SizedBox(width: 3),
                          Text(
                            'Закреплён',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4C75A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Post Text
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onPostTap,
                      onLongPress: () => _showPostActions(context),
                      onSecondaryTap: () => _showPostActions(context),
                      behavior: HitTestBehavior.opaque,
                      child: RetroLinkifiedText(
                        text: displayText,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.38,
                          color: Color(0xFF1E242B),
                        ),
                        onOpenProfile: widget.onAuthorTap,
                      ),
                    ),
                    if (isLongText && !_isExpanded)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = true),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Читать дальше..',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF245899),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Repost (copy_history)
            if (post.copyHistory.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFF9FB2C8), width: 3),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final repost in post.copyHistory) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onRepostContentTap?.call(repost),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => widget.onAuthorTap?.call(repost.fromId),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFC0C7D0), width: 0.5),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3.5),
                                        child: RetroAvatar(
                                          url: repost.authorAvatarUrl,
                                          size: 26,
                                          fallbackText: repost.authorName.isNotEmpty
                                              ? repost.authorName[0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => widget.onAuthorTap?.call(repost.fromId),
                                    child: Text(
                                      repost.authorName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF22446B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (repost.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                RetroLinkifiedText(
                                  text: repost.text.trim(),
                                  style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF1E242B)),
                                  onOpenProfile: widget.onAuthorTap,
                                ),
                              ],
                              if (repost.attachments.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                RetroAttachmentGrid(attachments: repost.attachments),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Attachments
            if (post.attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: RetroAttachmentGrid(attachments: post.attachments),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: 6),
            ],

            const Divider(height: 1, color: Color(0xFFE2E6EB)),

            // Actions Footer: Like, Comment, Repost in iOS 6 pill style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  // Likes
                  _ActionButton(
                    icon: post.userLikes ? Icons.favorite : Icons.favorite_border,
                    iconColor: post.userLikes ? const Color(0xFFD62B42) : const Color(0xFF6B7887),
                    label: post.likesCount > 0 ? '${post.likesCount}' : '',
                    textColor: post.userLikes ? const Color(0xFFD62B42) : const Color(0xFF384656),
                    isActive: post.userLikes,
                    activeType: _ActionPillType.like,
                    onTap: widget.onLikeToggle,
                  ),
                  const SizedBox(width: 8),

                  // Comments
                  _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    iconColor: const Color(0xFF6B7887),
                    label: post.commentsCount > 0 ? '${post.commentsCount}' : '',
                    textColor: const Color(0xFF384656),
                    onTap: widget.onCommentsTap ?? widget.onPostTap,
                  ),
                  const SizedBox(width: 8),

                  // Repost
                  _ActionButton(
                    icon: Icons.reply,
                    iconColor: const Color(0xFF6B7887),
                    label: post.repostsCount > 0 ? '${post.repostsCount}' : '',
                    textColor: const Color(0xFF384656),
                    onTap: widget.onRepostTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showPostActions(BuildContext context) async {
    final post = widget.post;
    final actions = <Ios6DialogAction<_PostAction>>[
      if (widget.onPostTap != null || widget.onCommentsTap != null)
        const Ios6DialogAction(
          text: 'Открыть запись',
          value: _PostAction.open,
          isPrimary: true,
        ),
      if (post.text.trim().isNotEmpty)
        const Ios6DialogAction(
          text: 'Скопировать текст',
          value: _PostAction.copy,
        ),
      if (widget.onRepostTap != null)
        const Ios6DialogAction(
          text: 'Поделиться',
          value: _PostAction.repost,
        ),
      if (widget.onDeleteTap != null)
        const Ios6DialogAction(
          text: 'Удалить запись',
          value: _PostAction.delete,
          isDestructive: true,
        ),
    ];

    if (actions.isEmpty) return;

    final action = await showIos6ActionsDialog<_PostAction>(
      context: context,
      title: 'Действие с записью',
      message: post.text.trim(),
      actions: actions,
      cancelText: 'Отмена',
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _PostAction.open:
        (widget.onPostTap ?? widget.onCommentsTap)?.call();
        break;
      case _PostAction.copy:
        await Clipboard.setData(ClipboardData(text: post.text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Текст записи скопирован'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      case _PostAction.repost:
        widget.onRepostTap?.call();
        break;
      case _PostAction.delete:
        widget.onDeleteTap?.call();
        break;
    }
  }
}

enum _ActionPillType { normal, like }

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  final bool isActive;
  final _ActionPillType activeType;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.textColor,
    this.isActive = false,
    this.activeType = _ActionPillType.normal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLikedActive = isActive && activeType == _ActionPillType.like;

    final gradientColors = isLikedActive
        ? const [Color(0xFFFFF1F2), Color(0xFFFFD6DA)]
        : const [Color(0xFFFFFFFF), Color(0xFFECEFF3)];

    final borderColor = isLikedActive
        ? const Color(0xFFE58894)
        : const Color(0xFFBCC4CE);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 27,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    shadows: isLikedActive
                        ? null
                        : const [
                            Shadow(
                              color: Colors.white,
                              offset: Offset(0, 1),
                              blurRadius: 0,
                            ),
                          ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
