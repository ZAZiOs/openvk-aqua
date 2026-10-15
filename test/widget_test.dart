import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/core.dart';
import 'package:openvk_aqua/main.dart';
import 'package:openvk_aqua/ui/views/settings/settings_view.dart';
import 'package:openvk_aqua/ui/widgets/retro_app_bar.dart';
import 'package:openvk_aqua/ui/widgets/retro_bottom_bar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('OpenVkApp smoke test displays LoginView by default', (
    WidgetTester tester,
  ) async {
    final client = OpenVkClient();
    final authHandler = AuthHandler(client: client);

    await tester.pumpWidget(
      OpenVkApp(authHandler: authHandler, client: client),
    );

    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Телефон или e-mail'), findsOneWidget);
  });

  testWidgets('RetroHomeScreen displays RetroAppBar without overflow', (
    WidgetTester tester,
  ) async {
    const account = SavedAccount(
      id: 1,
      userId: 12345,
      name: 'Павел Дуров',
      avatarUrl: '',
      accessToken: 'test_token',
      instanceId: 1,
      isActive: true,
    );

    final client = OpenVkClient();

    await tester.pumpWidget(
      MaterialApp(
        home: RetroHomeScreen(
          account: account,
          client: client,
          onLogout: _dummyLogout,
        ),
      ),
    );

    expect(find.byType(RetroAppBar), findsOneWidget);
    expect(find.text('Павел Дуров'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RetroHomeScreen hides RetroBottomBar when width > 850', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const account = SavedAccount(
      id: 1,
      userId: 12345,
      name: 'Павел Дуров',
      avatarUrl: '',
      accessToken: 'test_token',
      instanceId: 1,
      isActive: true,
    );
    final client = OpenVkClient();

    await tester.pumpWidget(
      MaterialApp(
        home: RetroHomeScreen(
          account: account,
          client: client,
          onLogout: _dummyLogout,
        ),
      ),
    );

    expect(find.byType(RetroBottomBar), findsNothing);
  });

  testWidgets('RetroHomeScreen shows RetroBottomBar when width <= 850', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const account = SavedAccount(
      id: 1,
      userId: 12345,
      name: 'Павел Дуров',
      avatarUrl: '',
      accessToken: 'test_token',
      instanceId: 1,
      isActive: true,
    );
    final client = OpenVkClient();

    await tester.pumpWidget(
      MaterialApp(
        home: RetroHomeScreen(
          account: account,
          client: client,
          onLogout: _dummyLogout,
        ),
      ),
    );

    expect(find.byType(RetroBottomBar), findsOneWidget);
  });

  testWidgets('SettingsView displays logout item and invokes onLogout', (
    WidgetTester tester,
  ) async {
    bool logoutTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsView(onLogout: () => logoutTriggered = true),
        ),
      ),
    );

    expect(find.text('Выход'), findsOneWidget);
    await tester.tap(find.text('Выход'));
    expect(logoutTriggered, isTrue);
  });

  testWidgets('OpenVkApp displays OobeView when initialOobeCompleted is false, then transitions to LoginView', (
    WidgetTester tester,
  ) async {
    await AppDatabase.instance.init(inMemory: true);
    final client = OpenVkClient();
    final authHandler = AuthHandler(client: client);

    await tester.pumpWidget(
      OpenVkApp(
        authHandler: authHandler,
        client: client,
        initialOobeCompleted: false,
      ),
    );
    await tester.pump();

    // Verify OOBE elements
    expect(find.text('Ассистент настройки'), findsOneWidget);
    expect(find.text('OpenVK Aqua'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Начать использование'), findsOneWidget);

    // Tap "Начать использование"
    await tester.tap(find.text('Начать использование'));
    await tester.pumpAndSettle();

    // Verify transition to LoginView
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Телефон или e-mail'), findsOneWidget);

    // Verify database flag was persisted
    final completedInDb = await AppDatabase.instance.isOobeCompleted();
    expect(completedInDb, isTrue);
  });
}

void _dummyLogout() {}


