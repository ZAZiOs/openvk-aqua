import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'retro_loading_indicator.dart';

class RetroArrowPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const RetroArrowPainter({
    required this.color,
    this.strokeWidth = 2.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final topY = 2.0;
    final bottomY = size.height - 2.0;

    // Stem (vertical line)
    canvas.drawLine(
      Offset(centerX, topY),
      Offset(centerX, bottomY),
      paint,
    );

    // Wings (angled upwards from the bottom point)
    final wingX = size.width * 0.42;
    final wingY = wingX * 0.95;

    // Left wing
    canvas.drawLine(
      Offset(centerX, bottomY),
      Offset(centerX - wingX, bottomY - wingY),
      paint,
    );

    // Right wing
    canvas.drawLine(
      Offset(centerX, bottomY),
      Offset(centerX + wingX, bottomY - wingY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RetroArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class RetroPullArrow extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const RetroPullArrow({
    super.key,
    this.color = const Color(0xFF8895A5),
    this.width = 22,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: RetroArrowPainter(color: color),
      ),
    );
  }
}

String formatRetroLastUpdated(DateTime dt) {
  const months = [
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
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return 'Обновлено ${dt.day} ${months[dt.month]} в $hour:$minute';
}

class RetroPullToRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final ScrollController? controller;
  final Color? backgroundColor;
  final Color? contentColor;
  final Color? arrowColor;
  final double threshold;
  final DateTime? initialLastUpdated;

  const RetroPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.controller,
    this.backgroundColor,
    this.contentColor,
    this.arrowColor,
    this.threshold = 50.0,
    this.initialLastUpdated,
  });

  @override
  State<RetroPullToRefresh> createState() => _RetroPullToRefreshState();
}

class _RetroPullToRefreshState extends State<RetroPullToRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Animation<double>? _holdAnimation;
  Animation<double>? _pullSpringAnimation;

  double _pullDistance = 0.0;
  double _refreshHoldOffset = 0.0;
  double _pointerStartY = 0.0;
  double _currentScrollOffset = 0.0;
  bool _isPointerTracking = false;
  bool _isRefreshing = false;
  bool _isReadyToRelease = false;

  late DateTime _lastUpdated;

  static const double _refreshingHeight = 58.0;

  @override
  void initState() {
    super.initState();
    _lastUpdated = widget.initialLastUpdated ?? DateTime.now();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_holdAnimation != null) {
          setState(() {
            _refreshHoldOffset = _holdAnimation!.value;
          });
        } else if (_pullSpringAnimation != null) {
          setState(() {
            _pullDistance = _pullSpringAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isAtTop {
    if (widget.controller != null && widget.controller!.hasClients) {
      return widget.controller!.offset <= 1.0;
    }
    return _currentScrollOffset <= 1.0;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isRefreshing) return;
    _pointerStartY = event.position.dy;
    _isPointerTracking = _isAtTop;
    _isReadyToRelease = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isRefreshing) return;

    final dy = event.position.dy - _pointerStartY;

    if (_isAtTop && dy > 0) {
      _isPointerTracking = true;
      // Damped resistance: 0.45x, capped at 72px so content never flies down
      final pull = min(dy * 0.45, 72.0);
      setState(() {
        _pullDistance = pull;
        _isReadyToRelease = pull >= widget.threshold;
      });
    } else if (_isPointerTracking && dy <= 0) {
      _isPointerTracking = false;
      if (_pullDistance > 0) {
        setState(() {
          _pullDistance = 0.0;
          _isReadyToRelease = false;
        });
      }
    }
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    if (_isRefreshing) return;
    if (_isPointerTracking) {
      _isPointerTracking = false;
      if (_isReadyToRelease) {
        _triggerRefresh();
      } else if (_pullDistance > 0) {
        _animatePullSpringTo(0.0);
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    _currentScrollOffset = notification.metrics.pixels;
    return false;
  }

  void _animatePullSpringTo(double target) {
    _animController.stop();
    _holdAnimation = null;
    final start = _pullDistance;
    _pullSpringAnimation = Tween<double>(
      begin: start,
      end: target,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward(from: 0.0).whenComplete(() {
      _pullSpringAnimation = null;
      if (mounted) {
        setState(() {
          _pullDistance = target;
          _isReadyToRelease = false;
        });
      }
    });
  }

  Future<void> _triggerRefresh() async {
    if (_isRefreshing) return;

    final initialHold = _pullDistance;
    setState(() {
      _isRefreshing = true;
      _isReadyToRelease = false;
      _pullDistance = 0.0;
    });

    _animateRefreshHoldTo(_refreshingHeight, from: initialHold, curve: Curves.easeOut);

    try {
      await widget.onRefresh();
      _lastUpdated = DateTime.now();
    } catch (_) {
      // Ignore errors in pull to refresh
    } finally {
      if (mounted) {
        _animateRefreshHoldTo(0.0, curve: Curves.easeInOut).whenComplete(() {
          if (mounted) {
            setState(() {
              _isRefreshing = false;
              _refreshHoldOffset = 0.0;
              _holdAnimation = null;
            });
          }
        });
      }
    }
  }

  TickerFuture _animateRefreshHoldTo(
    double target, {
    double? from,
    Curve curve = Curves.easeInOut,
  }) {
    _animController.stop();
    _pullSpringAnimation = null;
    final start = from ?? _refreshHoldOffset;
    _holdAnimation = Tween<double>(
      begin: start,
      end: target,
    ).animate(CurvedAnimation(parent: _animController, curve: curve));

    return _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFFE4E8EE);
    final isDark = bgColor.computeLuminance() < 0.35;
    final defaultContentColor =
        isDark ? const Color(0xFFCAD7E5) : const Color(0xFF7A8796);
    final contentColor = widget.contentColor ?? defaultContentColor;
    final defaultArrowColor =
        isDark ? const Color(0xFFB5C8DB) : const Color(0xFF8895A5);
    final arrowColor = widget.arrowColor ?? defaultArrowColor;
    final activeHeight = _isRefreshing ? _refreshHoldOffset : _pullDistance;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUpOrCancel,
      onPointerCancel: _onPointerUpOrCancel,
      behavior: HitTestBehavior.translucent,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          children: [
            // Pull header background with subpixel bleed (3.0px) behind child to eliminate any 1px gap
            if (activeHeight > 0.0) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: activeHeight + 3.0,
                child: Container(color: bgColor),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: activeHeight,
                child: ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        height: 48,
                        child: Opacity(
                          opacity: (activeHeight / _refreshingHeight).clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatRetroLastUpdated(_lastUpdated),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: contentColor,
                                  fontWeight: FontWeight.w500,
                                  shadows: isDark
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
                              const SizedBox(height: 5),
                              if (_isRefreshing)
                                const RetroLoadingIndicator(size: 20)
                              else
                                AnimatedRotation(
                                  turns: _isReadyToRelease ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  child: RetroPullArrow(
                                    color: arrowColor,
                                    width: 20,
                                    height: 24,
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
            ],

            // Scrollable child: translated smoothly by activeHeight with 0 gap
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, activeHeight),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
