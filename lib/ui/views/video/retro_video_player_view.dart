import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';

import '../../../core/models/attachment.dart';
import '../../widgets/retro_loading_indicator.dart';

/// Full-screen in-app video player in authentic iOS 6 QuickTime style.
class RetroVideoPlayerView extends StatefulWidget {
  final VideoAttachment video;

  const RetroVideoPlayerView({
    super.key,
    required this.video,
  });

  /// Opens the player in a full-screen route.
  static Future<void> open(BuildContext context, VideoAttachment video) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: RetroVideoPlayerView(video: video),
          );
        },
      ),
    );
  }

  @override
  State<RetroVideoPlayerView> createState() => _RetroVideoPlayerViewState();
}

class _RetroVideoPlayerViewState extends State<RetroVideoPlayerView> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _volume = 1.0;
  bool _isSeeking = false;
  double _seekProgress = 0.0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _focusNode.dispose();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final direct = widget.video.directVideoUrl;
    final player = widget.video.playerUrl;
    final candidateUrl = (direct != null && direct.isNotEmpty)
        ? direct
        : (player.isNotEmpty ? player : null);

    if (candidateUrl == null || candidateUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Ссылка на видеопоток отсутствует';
      });
      return;
    }

    try {
      if (Platform.isWindows) {
        WindowsVideoPlayer.registerWith();
      }

      final uri = Uri.parse(candidateUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      controller.addListener(_onControllerUpdate);
      await controller.setVolume(_volume);
      await controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Не удалось загрузить видеофайл ($e)';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false) && !_isSeeking) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
      _hideControlsTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      controller.play();
      _startHideTimer();
    }
  }

  void _seekRelative(int seconds) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final current = controller.value.position;
    final total = controller.value.duration;
    final newPos = (current + Duration(seconds: seconds));
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > total ? total : newPos);

    controller.seekTo(clamped);
    _startHideTimer();
  }

  Future<void> _openExternalBrowser() async {
    final targetUrl = widget.video.playerUrl.isNotEmpty
        ? widget.video.playerUrl
        : (widget.video.directVideoUrl ??
            'https://ovk.to/video${widget.video.ownerId}_${widget.video.id}');

    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyK) {
        _togglePlayPause();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekRelative(-5);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekRelative(5);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _adjustVolume(0.1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _adjustVolume(-0.1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _adjustVolume(double delta) {
    final newVol = (_volume + delta).clamp(0.0, 1.0);
    setState(() => _volume = newVol);
    _controller?.setVolume(newVol);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Canvas or Fallback
              Center(
                child: _buildVideoContent(),
              ),

              // Top iOS 6 QuickTime Navigation Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                top: _showControls ? 0 : -80,
                left: 0,
                right: 0,
                child: _buildTopBar(context),
              ),

              // Bottom iOS 6 QuickTime HUD Controls
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                bottom: _showControls ? 0 : -140,
                left: 0,
                right: 0,
                child: _buildBottomHud(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_hasError) {
      return _buildErrorCard();
    }

    final controller = _controller;
    if (controller != null && _isInitialized && controller.value.isInitialized) {
      final aspect = controller.value.aspectRatio > 0
          ? controller.value.aspectRatio
          : 16 / 9;

      return AspectRatio(
        aspectRatio: aspect,
        child: VideoPlayer(controller),
      );
    }

    // Loading State with Thumbnail in background
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.video.photoUrl.isNotEmpty)
          Image.network(
            widget.video.photoUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        Container(color: const Color(0x99000000)),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RetroLoadingIndicator(size: 36),
              SizedBox(height: 14),
              Text(
                'Загрузка видео...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE62A303A),
            Color(0xE615191F),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF475260), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.ondemand_video_rounded,
            color: Color(0xFF8AA3BE),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            widget.video.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage.isNotEmpty
                ? _errorMessage
                : 'Прямой видеопоток встроенного формата не найден.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFBAC3CD),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          _RetroIos6Button(
            text: 'Открыть в браузере',
            icon: Icons.open_in_browser_rounded,
            onPressed: _openExternalBrowser,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
              // iOS 6 "Готово" (Done) button
              _RetroIos6Button(
                text: 'Готово',
                onPressed: () => Navigator.of(context).pop(),
              ),

              const SizedBox(width: 12),

              // Title in center
              Expanded(
                child: Text(
                  widget.video.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // External link button
              _RetroIos6Button(
                icon: Icons.open_in_browser_rounded,
                tooltip: 'Открыть источник',
                onPressed: _openExternalBrowser,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomHud() {
    final controller = _controller;
    final isReady = controller != null &&
        _isInitialized &&
        controller.value.isInitialized;

    final position = isReady
        ? (_isSeeking
            ? Duration(
                milliseconds: (_seekProgress *
                        controller.value.duration.inMilliseconds)
                    .round(),
              )
            : controller.value.position)
        : Duration.zero;

    final duration = isReady
        ? controller.value.duration
        : Duration(seconds: widget.video.duration);

    final isPlaying = isReady && controller.value.isPlaying;

    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xEA2A3038),
            Color(0xFA14171B),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrubber Row: Elapsed, Metallic Track, Duration
              Row(
                children: [
                  Text(
                    _formatTime(position),
                    style: const TextStyle(
                      color: Color(0xFFD4DCE6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const _RetroIos6SliderThumbShape(),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: const Color(0xFF3B82C4),
                        inactiveTrackColor: const Color(0x55000000),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: _isSeeking ? _seekProgress : progress,
                        onChangeStart: (_) {
                          setState(() => _isSeeking = true);
                        },
                        onChanged: (val) {
                          setState(() => _seekProgress = val);
                        },
                        onChangeEnd: (val) {
                          setState(() => _isSeeking = false);
                          if (isReady && duration.inMilliseconds > 0) {
                            final targetMs =
                                (val * duration.inMilliseconds).round();
                            controller.seekTo(Duration(milliseconds: targetMs));
                          }
                          _startHideTimer();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '-${_formatTime(duration - position)}',
                    style: const TextStyle(
                      color: Color(0xFFD4DCE6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Control Buttons Row: Rewind, Big Play, Fast-Forward, Volume
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  _RetroCircleButton(
                    icon: Icons.replay_10_rounded,
                    size: 40,
                    iconSize: 22,
                    onPressed: isReady ? () => _seekRelative(-10) : null,
                  ),

                  const SizedBox(width: 24),

                  // Main Glossy Play / Pause Button
                  _RetroCircleButton(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 52,
                    iconSize: 32,
                    isProminent: true,
                    onPressed: isReady ? _togglePlayPause : null,
                  ),

                  const SizedBox(width: 24),

                  // Fast-forward 10s
                  _RetroCircleButton(
                    icon: Icons.forward_10_rounded,
                    size: 40,
                    iconSize: 22,
                    onPressed: isReady ? () => _seekRelative(10) : null,
                  ),

                  const Spacer(),

                  // Volume Controls
                  const Icon(
                    Icons.volume_down_rounded,
                    color: Color(0xFFB0BAC6),
                    size: 18,
                  ),
                  SizedBox(
                    width: 100,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: const Color(0xFF3B82C4),
                        inactiveTrackColor: const Color(0x44000000),
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (val) {
                          setState(() => _volume = val);
                          controller?.setVolume(val);
                          _startHideTimer();
                        },
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFFB0BAC6),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(Duration duration) {
    if (duration.isNegative) duration = Duration.zero;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Authentic iOS 6 styled glossy button with metallic bevel and dark slate gradient.
class _RetroIos6Button extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const _RetroIos6Button({
    this.text,
    this.icon,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                if (text != null) const SizedBox(width: 6),
              ],
              if (text != null)
                Text(
                  text!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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

/// Circular glossy media button (Play, Rewind, Fast Forward).
class _RetroCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final bool isProminent;
  final VoidCallback? onPressed;

  const _RetroCircleButton({
    required this.icon,
    this.size = 40,
    this.iconSize = 22,
    this.isProminent = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isProminent
                  ? const [
                      Color(0xFF555F6D),
                      Color(0xFF3A424C),
                      Color(0xFF20252C),
                    ]
                  : const [
                      Color(0xFF454C57),
                      Color(0xFF2B3139),
                    ],
            ),
            border: Border.all(
              color: isProminent
                  ? const Color(0xFF8B98A7)
                  : const Color(0xFF58626F),
              width: isProminent ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 2,
                  offset: Offset(0, -1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom iOS 6 metallic slider thumb with silver gloss and center pin.
class _RetroIos6SliderThumbShape extends SliderComponentShape {
  const _RetroIos6SliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(18, 18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Outer shadow
    canvas.drawCircle(
      center.translate(0, 1),
      9,
      Paint()
        ..color = Colors.black45
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Silver metallic gradient circle
    final rect = Rect.fromCircle(center: center, radius: 9);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFD6DBE0),
          Color(0xFFAAB2BA),
        ],
      ).createShader(rect);

    canvas.drawCircle(center, 9, paint);

    // Outer border
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = const Color(0xFF6B7480)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Inner glossy highlight on top hemisphere
    final topHighlight = Path()
      ..addArc(Rect.fromCircle(center: center, radius: 8), 3.14, 3.14);
    canvas.drawPath(
      topHighlight,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }
}
