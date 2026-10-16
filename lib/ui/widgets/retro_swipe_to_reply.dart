import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';

/// A retro-styled swipe-to-reply wrapper widget.
///
/// Swipes left with elastic resistance (easing damping) up to a max offset (~50px).
/// Triggers [onReply] once the threshold (~45px) is reached.
/// Returns smoothly to offset 0 with an ease-out curve on release.
class RetroSwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final double threshold;
  final double maxOffset;
  final bool enabled;

  const RetroSwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.threshold = 45.0,
    this.maxOffset = 52.0,
    this.enabled = true,
  });

  @override
  State<RetroSwipeToReply> createState() => _RetroSwipeToReplyState();
}

class _RetroSwipeToReplyState extends State<RetroSwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<double> _animation = const AlwaysStoppedAnimation(0.0);

  double _dragDistance = 0.0;
  double _currentOffset = 0.0;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animController.addListener(() {
      if (mounted) {
        setState(() {
          _currentOffset = _animation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double _computeOffset(double drag) {
    if (drag <= 0.0) return 0.0;
    final threshold = widget.threshold;
    final maxOffset = widget.maxOffset;
    if (drag <= threshold) {
      return drag;
    }
    final extra = drag - threshold;
    // Asymptotic easing damping towards maxOffset
    return threshold + (maxOffset - threshold) * (1.0 - exp(-extra / 25.0));
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _animController.stop();
    _dragDistance = _currentOffset;
    _hasTriggered = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    // Dragging to the left means delta.dx is negative
    _dragDistance = max(0.0, _dragDistance - details.primaryDelta!);
    final newOffset = _computeOffset(_dragDistance);

    if (newOffset >= widget.threshold && !_hasTriggered) {
      _hasTriggered = true;
      HapticFeedback.lightImpact();
    } else if (newOffset < widget.threshold * 0.6 && _hasTriggered) {
      _hasTriggered = false;
    }

    setState(() {
      _currentOffset = newOffset;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final velocity = details.primaryVelocity ?? 0.0;
    final isQuickFlick = velocity < -350 && _currentOffset >= 25.0;

    if (_hasTriggered || isQuickFlick) {
      if (!_hasTriggered) {
        HapticFeedback.lightImpact();
      }
      widget.onReply();
    }
    _hasTriggered = false;
    _animateBack();
  }

  void _onHorizontalDragCancel() {
    if (!widget.enabled) return;
    _hasTriggered = false;
    _animateBack();
  }

  void _animateBack() {
    final start = _currentOffset;
    if (start <= 0.0) return;
    _animController.stop();
    _animation = Tween<double>(
      begin: start,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_currentOffset / widget.threshold).clamp(0.0, 1.0);
    final scale = 0.5 + 0.5 * progress;
    final opacity = progress;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_currentOffset > 0.5)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: _hasTriggered ? 1.15 : scale,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: RetroTheme.buttonGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _hasTriggered
                                ? const Color(0xFF0F3A6B)
                                : const Color(0xFF1B4E87),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _hasTriggered
                                  ? const Color(0x661B4E87)
                                  : const Color(0x33000000),
                              offset: const Offset(0, 1),
                              blurRadius: _hasTriggered ? 4 : 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.reply_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(-_currentOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
