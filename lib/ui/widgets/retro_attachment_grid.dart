import 'package:flutter/material.dart';

import '../../core/models/attachment.dart';
import '../theme/retro_theme.dart';
import 'retro_loading_indicator.dart';
import 'retro_media_viewer.dart';

/// Reusable retro attachment grid for messages, wall posts, and comments.
/// Renders photos and videos in a harmonious mosaic grid, and audios/docs as clean rows.
class RetroAttachmentGrid extends StatelessWidget {
  final List<Attachment> attachments;
  final bool isOut;
  final double? maxWidth;
  final void Function(Attachment attachment, int index)? onAttachmentTap;

  const RetroAttachmentGrid({
    super.key,
    required this.attachments,
    this.isOut = false,
    this.maxWidth,
    this.onAttachmentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final visualAttachments = attachments
        .where((a) => a.type == 'photo' || a.type == 'video')
        .toList();

    final audioAttachments =
        attachments.where((a) => a.type == 'audio').toList();

    final docAttachments =
        attachments.where((a) => a.type == 'doc').toList();

    final stickerAttachments =
        attachments.where((a) => a.type == 'sticker').toList();

    final giftAttachments =
        attachments.where((a) => a.type == 'gift').toList();

    final otherAttachments = attachments
        .where((a) =>
            a.type != 'photo' &&
            a.type != 'video' &&
            a.type != 'audio' &&
            a.type != 'doc' &&
            a.type != 'sticker' &&
            a.type != 'gift')
        .toList();

    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (visualAttachments.isNotEmpty)
            _buildVisualGrid(context, visualAttachments),
          if (audioAttachments.isNotEmpty) ...[
            if (visualAttachments.isNotEmpty) const SizedBox(height: 6),
            ...audioAttachments.map((a) => _buildAudioRow(context, a)),
          ],
          if (docAttachments.isNotEmpty) ...[
            if (visualAttachments.isNotEmpty || audioAttachments.isNotEmpty)
              const SizedBox(height: 6),
            ...docAttachments.map((d) => _buildDocRow(context, d)),
          ],
          if (stickerAttachments.isNotEmpty) ...[
            if (visualAttachments.isNotEmpty ||
                audioAttachments.isNotEmpty ||
                docAttachments.isNotEmpty)
              const SizedBox(height: 6),
            ...stickerAttachments.map((s) => _buildStickerRow(context, s)),
          ],
          if (giftAttachments.isNotEmpty) ...[
            if (visualAttachments.isNotEmpty ||
                audioAttachments.isNotEmpty ||
                docAttachments.isNotEmpty ||
                stickerAttachments.isNotEmpty)
              const SizedBox(height: 6),
            ...giftAttachments.map((g) => _buildGiftRow(context, g)),
          ],
          if (otherAttachments.isNotEmpty) ...[
            if (visualAttachments.isNotEmpty ||
                audioAttachments.isNotEmpty ||
                docAttachments.isNotEmpty ||
                stickerAttachments.isNotEmpty ||
                giftAttachments.isNotEmpty)
              const SizedBox(height: 6),
            ...otherAttachments.map((o) => _buildGenericRow(context, o)),
          ],
        ],
      ),
    );
  }

  Widget _buildGiftRow(BuildContext context, Attachment item) {
    final gift = item.gift;
    final thumb = gift?.bestThumb ?? '';
    final message = gift?.message ?? '';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9DB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5B83B), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thumb.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                thumb,
                width: 64,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.card_giftcard,
                  size: 40,
                  color: Color(0xFFB8860B),
                ),
              ),
            )
          else
            const Icon(
              Icons.card_giftcard,
              size: 40,
              color: Color(0xFFB8860B),
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Подарок',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF6B4E00),
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF382A02),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerRow(BuildContext context, Attachment item) {
    final sticker = item.sticker;
    final url = sticker?.bestImage ?? '';
    if (url.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Стикер #${sticker?.stickerId ?? 0}',
            style: const TextStyle(color: RetroTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    return Image.network(
      url,
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        child: Text(
          'Стикер #${sticker?.stickerId ?? 0}',
          style: const TextStyle(color: RetroTheme.textSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildVisualGrid(BuildContext context, List<Attachment> items) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: switch (items.length) {
        1 => _buildSingleMedia(context, items),
        2 => _buildTwoMedia(context, items),
        3 => _buildThreeMedia(context, items),
        4 => _buildFourMedia(context, items),
        _ => _buildMultiMedia(context, items),
      },
    );
  }

  Widget _buildSingleMedia(BuildContext context, List<Attachment> items) {
    final item = items[0];
    double aspectRatio = 16 / 9;
    if (item.type == 'photo' && item.photo != null) {
      final p = item.photo!;
      if (p.width > 0 && p.height > 0) {
        aspectRatio = (p.width / p.height).clamp(0.65, 2.2);
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildMediaCell(context, items, 0),
      ),
    );
  }

  Widget _buildTwoMedia(BuildContext context, List<Attachment> items) {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(child: _buildMediaCell(context, items, 0)),
          const SizedBox(width: 4),
          Expanded(child: _buildMediaCell(context, items, 1)),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(BuildContext context, List<Attachment> items) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: _buildMediaCell(context, items, 0),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 110,
          child: Row(
            children: [
              Expanded(child: _buildMediaCell(context, items, 1)),
              const SizedBox(width: 4),
              Expanded(child: _buildMediaCell(context, items, 2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourMedia(BuildContext context, List<Attachment> items) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: Row(
            children: [
              Expanded(child: _buildMediaCell(context, items, 0)),
              const SizedBox(width: 4),
              Expanded(child: _buildMediaCell(context, items, 1)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 130,
          child: Row(
            children: [
              Expanded(child: _buildMediaCell(context, items, 2)),
              const SizedBox(width: 4),
              Expanded(child: _buildMediaCell(context, items, 3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiMedia(BuildContext context, List<Attachment> items) {
    // 5+ items: 2 rows layout (2 top, remaining bottom)
    final topCount = items.length <= 6 ? 2 : 3;
    final topItems = items.take(topCount).toList();
    final bottomItems = items.skip(topCount).toList();

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: Row(
            children: [
              for (int i = 0; i < topItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(child: _buildMediaCell(context, items, i)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 110,
          child: Row(
            children: [
              for (int i = 0; i < bottomItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _buildMediaCell(
                    context,
                    items,
                    topCount + i,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaCell(
    BuildContext context,
    List<Attachment> allItems,
    int index,
  ) {
    final item = allItems[index];
    final isVideo = item.type == 'video';
    final imageUrl =
        isVideo ? item.video?.photoUrl ?? '' : item.photo?.url ?? '';

    return GestureDetector(
      onTap: () {
        if (onAttachmentTap != null) {
          onAttachmentTap!(item, index);
        } else {
          RetroMediaViewer.open(
            context,
            items: allItems,
            initialIndex: index,
          );
        }
      },
      child: Container(
        color: const Color(0xFFD6DCE5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFF8B98A7),
                    size: 28,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: RetroLoadingIndicator(size: 20),
                  );
                },
              )
            else
              Center(
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                  color: const Color(0xFF8B98A7),
                  size: 32,
                ),
              ),
            if (isVideo) ...[
              // Dark vignette overlay
              Container(color: const Color(0x30000000)),
              // Play button
              Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xAA000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              // Video duration badge
              if (item.video != null && item.video!.duration > 0)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(item.video!.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioRow(BuildContext context, Attachment item) {
    final audio = item.audio;
    final title = audio?.title ?? 'Без названия';
    final artist = audio?.artist ?? 'Неизвестный исполнитель';
    final duration = audio?.duration ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOut ? const Color(0xFFDFE9F5) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOut ? const Color(0xFFC7D7E8) : const Color(0xFFDCE1E7),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: RetroTheme.buttonGradient,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RetroTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RetroTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (duration > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: RetroTheme.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocRow(BuildContext context, Attachment item) {
    final doc = item.doc;
    final title = doc?.title ?? 'Документ';
    final size = doc?.size ?? 0;
    final ext = doc?.ext.toUpperCase() ?? 'DOC';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOut ? const Color(0xFFDFE9F5) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOut ? const Color(0xFFC7D7E8) : const Color(0xFFDCE1E7),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF5A789A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ext,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RetroTheme.textLink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (size > 0)
                  Text(
                    _formatFileSize(size),
                    style: const TextStyle(
                      color: RetroTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.download_rounded,
            size: 18,
            color: Color(0xFF7A889B),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericRow(BuildContext context, Attachment item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.attach_file_rounded,
            size: 16,
            color: Color(0xFF7A889B),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.summaryText,
              style: const TextStyle(
                color: RetroTheme.textLink,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}
