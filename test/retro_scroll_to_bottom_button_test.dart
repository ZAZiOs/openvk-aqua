import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/ui/widgets/retro_scroll_to_bottom_button.dart';

void main() {
  group('RetroScrollToBottomButton Tests', () {
    testWidgets('Renders iOS 6 button and triggers onPressed on tap', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroScrollToBottomButton(
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      // Verify down chevron icon is present
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Tap button
      await tester.tap(find.byType(RetroScrollToBottomButton));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('Does not display badge when unreadCount is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroScrollToBottomButton(
                unreadCount: 0,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('Displays retro unread badge when unreadCount > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroScrollToBottomButton(
                unreadCount: 7,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('Displays 99+ badge when unreadCount > 99', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroScrollToBottomButton(
                unreadCount: 150,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });
  });
}
