import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/ui/widgets/retro_switch.dart';

void main() {
  testWidgets('RetroSwitch displays labels and triggers onChanged when tapped', (
    WidgetTester tester,
  ) async {
    bool currentValue = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return RetroSwitch(
                value: currentValue,
                onChanged: (val) {
                  setState(() {
                    currentValue = val;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial state: OFF (shows ВЫКЛ)
    expect(find.byType(RetroSwitch), findsOneWidget);
    expect(find.text('ВЫКЛ'), findsOneWidget);

    // Tap to turn ON
    await tester.tap(find.byType(RetroSwitch));
    await tester.pumpAndSettle();

    expect(currentValue, isTrue);
    expect(find.text('ВКЛ'), findsOneWidget);

    // Tap to turn OFF
    await tester.tap(find.byType(RetroSwitch));
    await tester.pumpAndSettle();

    expect(currentValue, isFalse);
  });

  testWidgets('RetroSwitch does not toggle when disabled (onChanged is null)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RetroSwitch(
            value: true,
            onChanged: null,
          ),
        ),
      ),
    );

    expect(find.byType(RetroSwitch), findsOneWidget);
    await tester.tap(find.byType(RetroSwitch));
    await tester.pumpAndSettle();
  });
}
