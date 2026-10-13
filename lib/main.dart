import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/core.dart';
import 'ui/theme/retro_theme.dart';
import 'ui/views/login/login_view.dart';
import 'ui/views/settings/settings_view.dart';
import 'ui/widgets/retro_app_bar.dart';
import 'ui/widgets/retro_bottom_bar.dart';
import 'ui/widgets/retro_loading_indicator.dart';
import 'ui/widgets/retro_sidebar.dart';

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
  final VoidCallback? onLogout;

  const RetroHomeScreen({
    super.key,
    required this.account,
    this.onLogout,
  });

  @override
  State<RetroHomeScreen> createState() => _RetroHomeScreenState();
}

class _RetroHomeScreenState extends State<RetroHomeScreen>
    with SingleTickerProviderStateMixin {
  RetroSection _currentSection = RetroSection.news;
  late final AnimationController _drawerController;
  double _currentSidebarWidth = 260.0;
  bool _canDrag = false;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _canDrag = _drawerController.value > 0 || details.localPosition.dx < 48;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_canDrag) return;
    final delta = details.primaryDelta ?? 0;
    _drawerController.value += delta / _currentSidebarWidth;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_canDrag) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 365) {
      if (velocity > 0) {
        _drawerController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _drawerController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      if (_drawerController.value >= 0.5) {
        _drawerController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _drawerController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _toggleDrawer() {
    if (_drawerController.isCompleted || _drawerController.value > 0.5) {
      _drawerController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    } else {
      _drawerController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSelectSection(RetroSection section, {required bool isWide}) {
    setState(() => _currentSection = section);
    if (!isWide && _drawerController.value > 0) {
      _drawerController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 720;
        final bool hideBottomBar = constraints.maxWidth > 850;
        final double sidebarWidth = isWide
            ? 260.0
            : (constraints.maxWidth - 52.0).clamp(240.0, 320.0);
        _currentSidebarWidth = sidebarWidth;

        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: RetroSidebar(
                  account: widget.account,
                  onLogout: widget.onLogout,
                  currentSection: _currentSection,
                  onSectionSelected: (section) =>
                      _onSelectSection(section, isWide: true),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFF131820),
              ),
              Expanded(
                child: _buildMainContent(
                  isWide: true,
                  hideBottomBar: hideBottomBar,
                ),
              ),
            ],
          );
        }

        return GestureDetector(
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  final double progress = _drawerController.value;
                  final double xOffset = -50.0 * (1.0 - progress);
                  final double opacity =
                      (0.4 + 0.6 * progress).clamp(0.0, 1.0);

                  return Transform.translate(
                    offset: Offset(xOffset, 0),
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: sidebarWidth,
                  child: RetroSidebar(
                    account: widget.account,
                    onLogout: widget.onLogout,
                    currentSection: _currentSection,
                    onSectionSelected: (section) =>
                        _onSelectSection(section, isWide: false),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  final double x = _drawerController.value * sidebarWidth;
                  final bool isOpen = _drawerController.value > 0;

                  return Transform.translate(
                    offset: Offset(x, 0),
                    child: Container(
                      decoration: isOpen
                          ? BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(-4, 0),
                                ),
                              ],
                            )
                          : null,
                      child: child,
                    ),
                  );
                },
                child: Stack(
                  children: [
                    _buildMainContent(
                      isWide: false,
                      hideBottomBar: hideBottomBar,
                    ),
                    AnimatedBuilder(
                      animation: _drawerController,
                      builder: (context, _) {
                        if (_drawerController.value == 0) {
                          return const SizedBox.shrink();
                        }
                        return Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _drawerController.animateTo(
                              0.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                            ),
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: 0.2 * _drawerController.value,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent({
    required bool isWide,
    required bool hideBottomBar,
  }) {
    return Scaffold(
      appBar: RetroAppBar(
        title: _currentSection.title,
        leading: isWide ? null : RetroMenuButton(onPressed: _toggleDrawer),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isConstrained = constraints.maxWidth > 850;

          return Container(
            color: isConstrained
                ? const Color(0xFFCAD4DF)
                : const Color(0xFFF0F2F5),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                constraints: const BoxConstraints(maxWidth: 850),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  border: isConstrained
                      ? const Border.symmetric(
                          vertical: BorderSide(
                            color: Color(0xFFB8C5D3),
                            width: 1,
                          ),
                        )
                      : null,
                  boxShadow: isConstrained
                      ? const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: _buildSectionBody(),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: hideBottomBar
          ? null
          : RetroBottomBar(
              currentTab: _currentSection.bottomTab,
              onTabSelected: (tab) => setState(
                () => _currentSection = RetroSection.fromTab(tab),
              ),
            ),
    );
  }

  Widget _buildSectionBody() {
    if (_currentSection == RetroSection.settings) {
      return SettingsView(onLogout: widget.onLogout);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC3D1E0), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Work in progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: RetroTheme.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            RetroLoadingIndicator(size: 24),
          ],
        ),
      ),
    );
  }
}
