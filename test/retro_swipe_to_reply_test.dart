import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/ui/widgets/retro_swipe_to_reply.dart';

void main() {
  group('RetroSwipeToReply Widget Tests', () {
    testWidgets('Swipe right does not trigger reply nor move message', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroSwipeToReply(
                onReply: () => replied = true,
                child: const SizedBox(
                  key: ValueKey('msg_target'),
                  width: 200,
                  height: 50,
                  child: Text('Message Bubble'),
                ),
              ),
            ),
          ),
        ),
      );

      final msgFinder = find.byKey(const ValueKey('msg_target'));

      // Drag to the right
      await tester.drag(msgFinder, const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(replied, isFalse);
    });

    testWidgets('Swipe left less than threshold does not trigger reply', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroSwipeToReply(
                threshold: 45.0,
                onReply: () => replied = true,
                child: const SizedBox(
                  key: ValueKey('msg_target'),
                  width: 200,
                  height: 50,
                  child: Text('Message Bubble'),
                ),
              ),
            ),
          ),
        ),
      );

      final msgFinder = find.byKey(const ValueKey('msg_target'));

      // Drag left by only 25px (less than 45px threshold)
      await tester.drag(msgFinder, const Offset(-25, 0));
      await tester.pumpAndSettle();

      expect(replied, isFalse);
    });

    testWidgets('Swipe left past threshold triggers reply', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroSwipeToReply(
                threshold: 45.0,
                maxOffset: 52.0,
                onReply: () => replied = true,
                child: const SizedBox(
                  key: ValueKey('msg_target'),
                  width: 200,
                  height: 50,
                  child: Text('Message Bubble'),
                ),
              ),
            ),
          ),
        ),
      );

      final msgFinder = find.byKey(const ValueKey('msg_target'));

      // Drag left by 60px (> 45px threshold)
      await tester.drag(msgFinder, const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(replied, isTrue);
    });

    testWidgets('Message offset is strictly clamped by easing damping and does not fly far', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroSwipeToReply(
                threshold: 45.0,
                maxOffset: 52.0,
                onReply: () {},
                child: const SizedBox(
                  key: ValueKey('msg_target'),
                  width: 200,
                  height: 50,
                  child: Text('Message Bubble'),
                ),
              ),
            ),
          ),
        ),
      );

      final msgFinder = find.byKey(const ValueKey('msg_target'));

      // Start drag left by massive distance (400px)
      final gesture = await tester.startGesture(tester.getCenter(msgFinder));
      await gesture.moveBy(const Offset(-400, 0));
      await tester.pump();

      // Find the Transform.translate widget
      final transformFinder = find.byWidgetPredicate(
        (widget) => widget is Transform && widget.transform.getTranslation().x < 0,
      );
      expect(transformFinder, findsOneWidget);

      final transform = tester.widget<Transform>(transformFinder);
      final translationX = transform.transform.getTranslation().x;

      // Displacement must not fly far away: should be between -53px and -45px (strictly capped around 52px)
      expect(translationX, lessThanOrEqualTo(-45.0));
      expect(translationX, greaterThanOrEqualTo(-53.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Dragging past threshold and then back cancels reply', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroSwipeToReply(
                threshold: 45.0,
                onReply: () => replied = true,
                child: const SizedBox(
                  key: ValueKey('msg_target'),
                  width: 200,
                  height: 50,
                  child: Text('Message Bubble'),
                ),
              ),
            ),
          ),
        ),
      );

      final msgFinder = find.byKey(const ValueKey('msg_target'));

      // Drag past threshold
      final gesture = await tester.startGesture(tester.getCenter(msgFinder));
      await gesture.moveBy(const Offset(-55, 0));
      await tester.pump();

      // Drag back to near origin (canceling reply)
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(replied, isFalse);
    });
  });
}
