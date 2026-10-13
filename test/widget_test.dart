import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/core.dart';
import 'package:openvk_flutter/main.dart';
import 'package:openvk_flutter/ui/widgets/retro_app_bar.dart';
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

    await tester.pumpWidget(
      const MaterialApp(
        home: RetroHomeScreen(account: account, onLogout: _dummyLogout),
      ),
    );

    expect(find.byType(RetroAppBar), findsOneWidget);
    expect(find.text('Добро пожаловать, Павел Дуров!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _dummyLogout() {}
