import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DrawerBoundPhysics extends ScrollPhysics {
  const DrawerBoundPhysics({super.parent});

  @override
  DrawerBoundPhysics applyTo(ScrollPhysics? ancestor) {
    return DrawerBoundPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

void main() {
  testWidgets('Parent catches horizontal overscroll from PageView containing vertical ListView', (tester) async {
    final overscrollDeltas = <double>[];
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) {
                if (notification is OverscrollNotification) {
                  final dx = notification.dragDetails?.delta.dx;
                  if (dx != null) {
                    overscrollDeltas.add(dx);
                  }
                }
              }
              return false;
            },
            child: PageView(
              controller: controller,
              physics: const DrawerBoundPhysics(parent: ClampingScrollPhysics()),
              children: [
                ListView.builder(
                  key: const ValueKey('list0'),
                  itemCount: 50,
                  itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
                ),
                ListView.builder(
                  key: const ValueKey('list1'),
                  itemCount: 50,
                  itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Drag right on list0
    await tester.drag(find.text('Item 0'), const Offset(100, 0));
    await tester.pump();

    debugPrint('Overscroll deltas: $overscrollDeltas');
    expect(overscrollDeltas.isNotEmpty, true);
    expect(overscrollDeltas.first > 0, true);
  });

  testWidgets('PageView with DrawerBoundPhysics snaps between pages and overscrolls at page 0', (tester) async {
    final overscrollDeltas = <double>[];
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) {
                if (notification is OverscrollNotification) {
                  final dx = notification.dragDetails?.delta.dx;
                  if (dx != null) {
                    overscrollDeltas.add(dx);
                  }
                }
              }
              return false;
            },
            child: PageView(
              controller: controller,
              physics: const DrawerBoundPhysics(
                parent: PageScrollPhysics(parent: ClampingScrollPhysics()),
              ),
              children: [
                Container(key: const ValueKey('p0'), color: Colors.red, child: const Text('Page 0')),
                Container(key: const ValueKey('p1'), color: Colors.blue, child: const Text('Page 1')),
              ],
            ),
          ),
        ),
      ),
    );

    // 1. Drag right on Page 0 -> should overscroll
    await tester.drag(find.text('Page 0'), const Offset(50, 0));
    await tester.pump();
    expect(overscrollDeltas.isNotEmpty, true);
    expect(controller.page, 0.0);

    overscrollDeltas.clear();

    // 2. Drag left on Page 0 to swipe to Page 1
    await tester.fling(find.text('Page 0'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 1.0);
    expect(overscrollDeltas.isEmpty, true);
  });

  testWidgets('Full drawer and PageView interaction: page 0 opens drawer, page 1 switches to page 0', (tester) async {
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return _TestDrawerHome(pageController: controller);
          },
        ),
      ),
    );

    // Initial state: page 0, drawer closed (0.0)
    expect(controller.page, 0.0);
    final drawerFinder = find.byType(_TestDrawerHome);
    final state = tester.state<_TestDrawerHomeState>(drawerFinder);
    expect(state.drawerController.value, 0.0);

    // 1. Drag right on Page 0 by 50px (< 35%) -> drawer opens slightly, then settles back to closed (0.0)
    await tester.drag(find.text('Page 0'), const Offset(50, 0));
    await tester.pump();
    expect(state.drawerController.value > 0, true);
    await tester.pumpAndSettle();
    expect(state.drawerController.value, 0.0);

    // 2. Drag right on Page 0 by 120px (> 35%) -> drawer opens and snaps fully open (1.0)
    await tester.drag(find.text('Page 0'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(state.drawerController.value, 1.0);

    // Reset drawer to closed
    state.drawerController.value = 0.0;
    await tester.pumpAndSettle();

    // 3. Drag left on Page 0 -> should switch to Page 1, drawer remains closed
    await tester.fling(find.text('Page 0'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 1.0);
    expect(state.drawerController.value, 0.0);

    // 4. Drag right on Page 1 -> should switch back to Page 0, drawer remains closed
    await tester.fling(find.text('Page 1'), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 0.0);
    expect(state.drawerController.value, 0.0);
  });
}

class _TestDrawerHome extends StatefulWidget {
  final PageController pageController;
  const _TestDrawerHome({required this.pageController});

  @override
  State<_TestDrawerHome> createState() => _TestDrawerHomeState();
}

class _TestDrawerHomeState extends State<_TestDrawerHome> with SingleTickerProviderStateMixin {
  late final AnimationController drawerController;

  @override
  void initState() {
    super.initState();
    drawerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    drawerController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      if (notification is OverscrollNotification) {
        final dx = notification.dragDetails?.delta.dx;
        if (dx != null && dx > 0) {
          drawerController.value = (drawerController.value + dx / 260.0).clamp(0.0, 1.0);
        }
      } else if (notification is ScrollEndNotification) {
        if (drawerController.value > 0 && drawerController.value < 1.0) {
          final target = drawerController.value >= 0.35 ? 1.0 : 0.0;
          drawerController.animateTo(target, curve: Curves.easeOutCubic);
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: PageView(
          controller: widget.pageController,
          physics: const DrawerBoundPhysics(
            parent: PageScrollPhysics(parent: ClampingScrollPhysics()),
          ),
          children: [
            Container(key: const ValueKey('p0'), color: Colors.red, child: const Text('Page 0')),
            Container(key: const ValueKey('p1'), color: Colors.blue, child: const Text('Page 1')),
          ],
        ),
      ),
    );
  }
}
