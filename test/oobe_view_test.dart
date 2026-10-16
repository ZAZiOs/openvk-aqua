import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/utils/download_helper.dart';
import 'package:openvk_aqua/ui/views/oobe/oobe_view.dart';

void main() {
  test('DownloadHelper returns non-empty directory and display path', () async {
    final dir = await DownloadHelper.getOpenVkDownloadDirectory();
    expect(dir.path, isNotEmpty);
    expect(dir.path.contains('OpenVK'), isTrue);

    final displayPath = await DownloadHelper.getDisplayPath();
    expect(displayPath, isNotEmpty);
    expect(displayPath.contains('OpenVK'), isTrue);
  });

  testWidgets('OobeView renders download folder permission row without hardcoded network encryption', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool isCompleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OobeView(
          onCompleted: () async {
            isCompleted = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and title
    expect(find.text('Ассистент настройки'), findsOneWidget);
    expect(find.text('OpenVK Aqua'), findsOneWidget);

    // Verify row 1 & 2
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Фотографии и файлы'), findsOneWidget);

    // Verify hardcoded network encryption row was removed
    expect(find.text('Сеть OpenVK'), findsNothing);
    expect(find.text('api.openvk.org'), findsNothing);
    expect(find.text('Шифрованное соединение с сервером api.openvk.org'), findsNothing);

    // Verify new download folder row exists
    expect(find.text('Папка загрузок'), findsOneWidget);

    // Toggle download folder permission
    await tester.tap(find.text('Папка загрузок'));
    await tester.pump();

    // Tap "Начать использование"
    await tester.ensureVisible(find.text('Начать использование'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Начать использование'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(isCompleted, isTrue);
  });

  testWidgets('OobeView semantics tree preserves all nodes without isHidden during scroll', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: OobeView(
          onCompleted: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialTree =
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!.toStringDeep();
    expect(initialTree, contains('OpenVK Aqua'));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();

    final scrolledTree =
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!.toStringDeep();
    expect(scrolledTree, contains('OpenVK Aqua'));
    expect(scrolledTree.contains('flags: isHidden'), isFalse);
    expect(scrolledTree.contains('HIDDEN'), isFalse);

    handle.dispose();
  });
}
