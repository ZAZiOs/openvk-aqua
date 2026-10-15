import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/models/attachment.dart';
import '../views/video/retro_video_player_view.dart';
import 'retro_loading_indicator.dart';

/// Full-screen media viewer for photos and videos in authentic iOS 6 style,
/// supporting swipe gestures across adjacent media, pinch/double-tap zoom,
/// file download/saving, and in-app video playback.
class RetroMediaViewer extends StatefulWidget {
  final List<Attachment> items;
  final int initialIndex;

  const RetroMediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  /// Opens the media viewer in a full-screen modal route.
  static Future<void> open(
    BuildContext context, {
    required List<Attachment> items,
    int initialIndex = 0,
  }) {
    if (items.isEmpty) return Future.value();
    final clampedIndex = initialIndex.clamp(0, items.length - 1);

    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0xF2000000),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: RetroMediaViewer(
              items: items,
              initialIndex: clampedIndex,
            ),
          );
        },
      ),
    );
  }

  /// Convenience method to open a single photo from a URL.
  static Future<void> openSinglePhotoUrl(
    BuildContext context,
    String imageUrl, {
    String? caption,
  }) {
    final photoAtt = Attachment(
      type: 'photo',
      photo: PhotoAttachment(
        id: 0,
        ownerId: 0,
        url: imageUrl,
        width: 0,
        height: 0,
        text: caption ?? '',
      ),
    );
    return open(context, items: [photoAtt], initialIndex: 0);
  }

  @override
  State<RetroMediaViewer> createState() => _RetroMediaViewerState();
}

class _RetroMediaViewerState extends State<RetroMediaViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isSaving = false;
  bool _isZoomed = false;
  bool _showUiBars = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Attachment get _currentItem => widget.items[_currentIndex];

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isZoomed = false;
    });
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleBars() {
    setState(() => _showUiBars = !_showUiBars);
  }

  Future<void> _saveCurrentMedia() async {
    if (_isSaving) return;

    final item = _currentItem;
    String downloadUrl = '';
    String fileName = '';

    if (item.type == 'photo' && item.photo != null) {
      downloadUrl = item.photo!.url;
      final ext = _guessExtension(downloadUrl, defaultExt: '.jpg');
      fileName = 'openvk_photo_${item.photo!.ownerId}_${item.photo!.id}$ext';
    } else if (item.type == 'video' && item.video != null) {
      downloadUrl = item.video!.directVideoUrl ?? item.video!.photoUrl;
      final ext = item.video!.directVideoUrl != null
          ? _guessExtension(item.video!.directVideoUrl!, defaultExt: '.mp4')
          : '.jpg';
      fileName = 'openvk_video_${item.video!.ownerId}_${item.video!.id}$ext';
    }

    if (downloadUrl.isEmpty) {
      _showFeedback(
        'Не удалось найти прямую ссылку для скачивания',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      Directory? saveDir;
      try {
        saveDir = await getDownloadsDirectory();
      } catch (_) {}

      saveDir ??= await getApplicationDocumentsDirectory();

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      var targetFile = File(p.join(saveDir.path, fileName));
      var counter = 1;
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);

      while (await targetFile.exists()) {
        targetFile = File(p.join(saveDir.path, '${nameWithoutExt}_$counter$ext'));
        counter++;
      }

      await targetFile.writeAsBytes(response.bodyBytes);

      if (mounted) {
        _showFeedback('Сохранено в Загрузки:\n${p.basename(targetFile.path)}');
      }
    } catch (e) {
      if (mounted) {
        _showFeedback('Ошибка при сохранении: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _guessExtension(String url, {required String defaultExt}) {
    try {
      final path = Uri.parse(url).path;
      final ext = p.extension(path).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    } catch (_) {}
    return defaultExt;
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError
            ? const Color(0xFFC0392B)
            : const Color(0xF22C3E50),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isError
                ? const Color(0xFFE74C3C)
                : const Color(0xFF5A738E),
            width: 1,
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previousPage();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _nextPage();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.space &&
          _currentItem.type == 'video' &&
          _currentItem.video != null) {
        _openVideoPlayer(_currentItem.video!);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _openVideoPlayer(VideoAttachment video) {
    RetroVideoPlayerView.open(context, video);
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.items.length;
    final hasMultiple = totalCount > 1;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Main PageView for Media Carousel (filling screen naturally)
            PageView.builder(
              controller: _pageController,
              itemCount: totalCount,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                if (item.type == 'video') {
                  return _buildVideoItemView(item);
                }
                return _PhotoZoomView(
                  key: ValueKey(item.photo?.url ?? index),
                  photo: item.photo,
                  onTap: _toggleBars,
                  onZoomChanged: (zoomed) {
                    if (_isZoomed != zoomed) {
                      setState(() => _isZoomed = zoomed);
                    }
                  },
                );
              },
            ),

            // Left Navigation Arrow Button
            if (hasMultiple && _currentIndex > 0 && _showUiBars)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: _previousPage,
                    tooltip: 'Предыдущее (←)',
                  ),
                ),
              ),

            // Right Navigation Arrow Button
            if (hasMultiple && _currentIndex < totalCount - 1 && _showUiBars)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: _nextPage,
                    tooltip: 'Следующее (→)',
                  ),
                ),
              ),

            // Top iOS 6 Glossy Navigation Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: _showUiBars ? 0 : -80,
              left: 0,
              right: 0,
              child: _buildHeaderBar(context, hasMultiple, totalCount),
            ),

            // Bottom iOS 6 Info Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              bottom: _showUiBars ? 0 : -120,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    bool hasMultiple,
    int totalCount,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xEA353B44),
            Color(0xEA1F2329),
          ],
        ),
        border: Border(
          top: BorderSide(color: Color(0x40FFFFFF), width: 1),
          bottom: BorderSide(color: Color(0x99000000), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // iOS 6 Close / Back Button
              _RetroIos6Button(
                text: 'Закрыть',
                icon: Icons.close_rounded,
                tooltip: 'Закрыть (Esc)',
                onPressed: () => Navigator.of(context).pop(),
              ),

              const SizedBox(width: 12),

              // Page counter / Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasMultiple
                          ? '${_currentIndex + 1} из $totalCount'
                          : (_currentItem.type == 'video'
                              ? 'Видеозапись'
                              : 'Фотография'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 3,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                    ),
                    if (hasMultiple)
                      Text(
                        _currentItem.type == 'video'
                            ? 'Видеозапись'
                            : 'Фотография',
                        style: const TextStyle(
                          color: Color(0xFFBAC3CE),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Save / Download Button in iOS 6 style
              _RetroIos6Button(
                text: 'Сохранить',
                icon: _isSaving ? null : Icons.download_rounded,
                customChild: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: RetroLoadingIndicator(size: 14),
                      )
                    : null,
                tooltip: 'Сохранить файл в Загрузки',
                onPressed: _saveCurrentMedia,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final item = _currentItem;
    final isVideo = item.type == 'video' && item.video != null;
    final video = item.video;

    final String title;
    final String subtitle;

    if (isVideo) {
      title = video!.title;
      final dur = video.duration > 0
          ? 'Длительность: ${_formatDuration(video.duration)}'
          : '';
      final desc = video.description.trim();
      subtitle = [dur, desc].where((s) => s.isNotEmpty).join(' • ');
    } else if (item.type == 'photo' && item.photo != null) {
      title = item.photo!.text.trim();
      subtitle = '';
    } else {
      title = '';
      subtitle = '';
    }

    if (title.isEmpty && subtitle.isEmpty && !isVideo) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xEA1F2329),
            Color(0xEA353B44),
          ],
        ),
        border: Border(
          top: BorderSide(color: Color(0x40FFFFFF), width: 1),
          bottom: BorderSide(color: Color(0x99000000), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                              offset: Offset(0, -1),
                            ),
                          ],
                        ),
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFBAC3CE),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (isVideo) ...[
                const SizedBox(width: 12),
                _RetroIos6Button(
                  text: 'Смотреть',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _openVideoPlayer(video!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoItemView(Attachment item) {
    final video = item.video;
    final thumbUrl = video?.photoUrl ?? '';

    return GestureDetector(
      onTap: () {
        if (video != null) {
          _openVideoPlayer(video);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background video thumbnail (naturally contained)
          if (thumbUrl.isNotEmpty)
            Image.network(
              thumbUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.videocam_rounded,
                  size: 72,
                  color: Color(0xFF555F6D),
                ),
              ),
            )
          else
            const Center(
              child: Icon(
                Icons.videocam_rounded,
                size: 72,
                color: Color(0xFF555F6D),
              ),
            ),

          // Authentic iOS 6 QuickTime Large Center Play Button
          Center(
            child: _Ios6QuickTimePlayButton(
              onTap: () {
                if (video != null) {
                  _openVideoPlayer(video);
                }
              },
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
}

/// Authentic iOS 6 QuickTime glossy play badge.
class _Ios6QuickTimePlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _Ios6QuickTimePlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC383E48),
                Color(0xEE14171C),
              ],
            ),
            border: Border.all(
              color: const Color(0xC0FFFFFF),
              width: 2.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Upper hemisphere gloss highlight
              Align(
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                  child: Container(
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Play Arrow Icon with shadow
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 3,
                        offset: Offset(0, -1),
                      ),
                    ],
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

/// Zoomable photo view with double-tap zoom and pan gestures.
class _PhotoZoomView extends StatefulWidget {
  final PhotoAttachment? photo;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  const _PhotoZoomView({
    super.key,
    required this.photo,
    required this.onTap,
    required this.onZoomChanged,
  });

  @override
  State<_PhotoZoomView> createState() => _PhotoZoomViewState();
}

class _PhotoZoomViewState extends State<_PhotoZoomView>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    widget.onZoomChanged(isZoomed);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale =
        _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;

    if (currentScale > 1.1) {
      endMatrix = Matrix4.identity();
    } else {
      const s = 2.5;
      final position = details.localPosition;
      final x = -position.dx * (s - 1);
      final y = -position.dy * (s - 1);

      endMatrix = Matrix4(
        s, 0, 0, 0,
        0, s, 0, 0,
        0, 0, 1, 0,
        x, y, 0, 1,
      );
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photo?.url ?? '';
    if (url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.white54,
          size: 64,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.8,
          maxScale: 5.0,
          clipBehavior: Clip.none,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: RetroLoadingIndicator(size: 32),
              );
            },
            errorBuilder: (_, _, _) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Не удалось загрузить изображение',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent dark circular navigation button (Left / Right).
class _NavArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _NavArrowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x991C2025),
              border: Border.all(
                color: const Color(0x66FFFFFF),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

/// Authentic iOS 6 styled rounded glass button with dark slate gradient and bevel.
class _RetroIos6Button extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final Widget? customChild;
  final String? tooltip;
  final VoidCallback onPressed;

  const _RetroIos6Button({
    this.text,
    this.icon,
    this.customChild,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4C5460),
                Color(0xFF383F49),
                Color(0xFF262B32),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF6B7480),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: customChild ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 16),
                    if (text != null) const SizedBox(width: 5),
                  ],
                  if (text != null)
                    Text(
                      text!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 2,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
