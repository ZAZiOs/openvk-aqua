import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/ui/widgets/retro_status_badge.dart';

void main() {
  testWidgets('RetroStatusBadge displays checkmark when isSuccess is true', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetroStatusBadge(
            isSuccess: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(RetroStatusBadge), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.tap(find.byType(RetroStatusBadge));
    expect(tapped, isTrue);
  });

  testWidgets('RetroStatusBadge displays cross when isSuccess is false', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetroStatusBadge(
            isSuccess: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(RetroStatusBadge), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.byType(RetroStatusBadge));
    expect(tapped, isTrue);
  });
}
