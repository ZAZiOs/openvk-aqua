import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/core.dart';
import 'package:openvk_flutter/main.dart';
import 'package:openvk_flutter/ui/views/settings/settings_view.dart';
import 'package:openvk_flutter/ui/widgets/retro_app_bar.dart';
import 'package:openvk_flutter/ui/widgets/retro_bottom_bar.dart';
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
}

void _dummyLogout() {}


