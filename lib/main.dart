import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/core.dart';
import 'ui/theme/retro_theme.dart';
import 'ui/views/login/login_view.dart';
import 'ui/views/messages/messages_view.dart';
import 'ui/views/settings/settings_view.dart';
import 'ui/widgets/retro_app_bar.dart';
import 'ui/widgets/retro_bottom_bar.dart';
import 'ui/widgets/retro_loading_indicator.dart';
import 'ui/widgets/retro_pull_to_refresh.dart';
import 'ui/widgets/retro_segmented_control.dart';
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
      scrollBehavior: const RetroScrollBehavior(),
      home: _currentAccount == null
          ? LoginView(
              authHandler: widget.authHandler,
              onLoginSuccess: _onLoginSuccess,
            )
          : RetroHomeScreen(
              account: _currentAccount!,
              client: widget.client,
              onLogout: _onLogout,
            ),
    );
  }
}

class RetroScrollBehavior extends MaterialScrollBehavior {
  const RetroScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class RetroHomeScreen extends StatefulWidget {
  final SavedAccount account;
  final OpenVkClient client;
  final VoidCallback? onLogout;

  const RetroHomeScreen({
    super.key,
    required this.account,
    required this.client,
    this.onLogout,
  });

  @override
  State<RetroHomeScreen> createState() => _RetroHomeScreenState();
}

class _RetroHomeScreenState extends State<RetroHomeScreen>
    with SingleTickerProviderStateMixin {
  RetroSection _currentSection = RetroSection.news;
  String _messagesFilter = 'all';
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
                  screenWidth: constraints.maxWidth,
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
                  final bool isClosed = progress == 0;

                  return Transform.translate(
                    offset: Offset(xOffset, 0),
                    child: Opacity(
                      opacity: opacity,
                      child: IgnorePointer(
                        ignoring: isClosed,
                        child: ExcludeSemantics(
                          excluding: isClosed,
                          child: child,
                        ),
                      ),
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
                      decoration: BoxDecoration(
                        boxShadow: [
                          if (isOpen)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(-4, 0),
                            ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: Stack(
                  children: [
                    _buildMainContent(
                      isWide: false,
                      hideBottomBar: hideBottomBar,
                      screenWidth: constraints.maxWidth,
                    ),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _drawerController,
                        builder: (context, _) {
                          final double val = _drawerController.value;
                          final bool isClosed = val == 0;

                          return IgnorePointer(
                            ignoring: isClosed,
                            child: ExcludeSemantics(
                              excluding: isClosed,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _drawerController.animateTo(
                                  0.0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                ),
                                child: Container(
                                  color: Colors.black.withValues(
                                    alpha: 0.2 * val,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
    double screenWidth = double.infinity,
  }) {
    final bool isMessages = _currentSection == RetroSection.messages;
    final bool hideSidebar = isWide || (isMessages && screenWidth < 360);

    Widget? appBarTitleWidget;
    String? appBarTitle = _currentSection.title;

    if (isMessages) {
      appBarTitle = null;
      appBarTitleWidget = RetroSegmentedControl<String>(
        tabs: const {
          'all': 'Все',
          'unread': 'Непрочитанные',
        },
        selected: _messagesFilter,
        onSelected: (filter) => setState(() => _messagesFilter = filter),
        hasShadow: false,
      );
    }

    return Scaffold(
      appBar: RetroAppBar(
        title: appBarTitle,
        titleWidget: appBarTitleWidget,
        leading: hideSidebar ? null : RetroMenuButton(onPressed: _toggleDrawer),
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

    if (_currentSection == RetroSection.messages) {
      return MessagesView(
        key: const PageStorageKey('messages_view'),
        client: widget.client,
        account: widget.account,
        filter: _messagesFilter,
      );
    }
    if (_currentSection == RetroSection.news) {
      return RetroPullToRefresh(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 1000));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFD6DCE5), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0E000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF5B88BD), Color(0xFF386498)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'OVK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'тест openvk',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: RetroTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '6 минут назад',
                              style: TextStyle(
                                fontSize: 12,
                                color: RetroTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.more_vert,
                        color: Color(0xFF8B98A7),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Запись для проверки данных, потяните вниз чтобы запустить обновление.',
                    style: TextStyle(
                      fontSize: 14,
                      color: RetroTheme.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
