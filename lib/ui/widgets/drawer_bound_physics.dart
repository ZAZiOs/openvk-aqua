import 'package:flutter/material.dart';

/// A [ScrollPhysics] that prevents negative overscroll on page 0
/// (i.e. scrolling past the beginning), while reporting overscroll deltas
/// via [OverscrollNotification] so parent widgets (such as a drawer or sidebar)
/// can smoothly respond to horizontal drag without bouncing the PageView.
class DrawerBoundPhysics extends ScrollPhysics {
  const DrawerBoundPhysics({super.parent});

  @override
  DrawerBoundPhysics applyTo(ScrollPhysics? ancestor) {
    return DrawerBoundPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // When dragging right at or before the minScrollExtent (pixels <= 0),
    // prevent the viewport from scrolling into negative pixels.
    // Returning (value - position.pixels) completely absorbs the scroll motion
    // and causes an OverscrollNotification with the exact drag delta to be dispatched.
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
