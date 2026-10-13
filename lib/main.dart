import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/core.dart';
import 'ui/theme/retro_theme.dart';
import 'ui/views/login/login_view.dart';
import 'ui/widgets/retro_app_bar.dart';
import 'ui/widgets/retro_bottom_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF000000),
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final client = OpenVkClient();
  final authHandler = AuthHandler(client: client);

  final savedAccount = await authHandler.restoreSession();

  runApp(
    OpenVkApp(
      authHandler: authHandler,
      client: client,
      initialAccount: savedAccount,
    ),
  );
}

class OpenVkApp extends StatefulWidget {
  final AuthHandler authHandler;
  final OpenVkClient client;
  final SavedAccount? initialAccount;

  const OpenVkApp({
    super.key,
    required this.authHandler,
    required this.client,
    this.initialAccount,
  });

  @override
  State<OpenVkApp> createState() => _OpenVkAppState();
}

class _OpenVkAppState extends State<OpenVkApp> {
  SavedAccount? _currentAccount;

  @override
  void initState() {
    super.initState();
    _currentAccount = widget.initialAccount;
  }

  void _onLoginSuccess() async {
    final account = await widget.authHandler.restoreSession();
    setState(() {
      _currentAccount = account;
    });
  }

  void _onLogout() async {
    await widget.authHandler.logout();
    setState(() {
      _currentAccount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenVK',
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.themeData,
      home: _currentAccount == null
          ? LoginView(
              authHandler: widget.authHandler,
              onLoginSuccess: _onLoginSuccess,
            )
          : RetroHomeScreen(account: _currentAccount!, onLogout: _onLogout),
    );
  }
}

class RetroHomeScreen extends StatefulWidget {
  final SavedAccount account;
  final VoidCallback onLogout;

  const RetroHomeScreen({
    super.key,
    required this.account,
    required this.onLogout,
  });

  @override
  State<RetroHomeScreen> createState() => _RetroHomeScreenState();
}

class _RetroHomeScreenState extends State<RetroHomeScreen> {
  RetroTab _currentTab = RetroTab.news;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RetroAppBar(
        title: _getTabTitle(_currentTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Выйти',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Добро пожаловать, ${widget.account.name}!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: RetroTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID пользователя: ${widget.account.userId}',
              style: const TextStyle(
                fontSize: 14,
                color: RetroTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RetroBottomBar(
        currentTab: _currentTab,
        onTabSelected: (tab) => setState(() => _currentTab = tab),
      ),
    );
  }

  String _getTabTitle(RetroTab tab) {
    switch (tab) {
      case RetroTab.news:
        return 'Новости';
      case RetroTab.wall:
        return 'Стена';
      case RetroTab.messages:
        return 'Сообщения';
      case RetroTab.friends:
        return 'Друзья';
      case RetroTab.media:
        return 'Медиа';
    }
  }
}
