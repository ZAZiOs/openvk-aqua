import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/core.dart';
import 'ui/theme/retro_theme.dart';
import 'ui/views/login/login_view.dart';
import 'ui/views/media/audio_playlists_view.dart';
import 'ui/views/media/media_view.dart';
import 'ui/views/media/retro_audio_mini_player.dart';
import 'ui/views/messages/chat_conversation_view.dart';
import 'ui/views/messages/messages_view.dart';
import 'ui/views/newsfeed/newsfeed_view.dart';
import 'ui/views/oobe/oobe_view.dart';
import 'ui/views/settings/settings_view.dart';
import 'ui/views/wall/wall_view.dart';
import 'ui/widgets/retro_app_bar.dart';
import 'ui/widgets/retro_bottom_bar.dart';
import 'ui/widgets/retro_loading_indicator.dart';
import 'ui/widgets/retro_segmented_control.dart';
import 'ui/widgets/retro_sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.init();
  await NotificationDispatcher.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF000000),
      statusBarColor: Colors.black,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final client = OpenVkClient();
  final authHandler = AuthHandler(client: client);

  final savedAccount = await authHandler.restoreSession();
  final isOobeCompleted = await AppDatabase.instance.isOobeCompleted();

  runApp(
    OpenVkApp(
      authHandler: authHandler,
      client: client,
      initialAccount: savedAccount,
      initialOobeCompleted: isOobeCompleted,
    ),
  );
}

class _GoBackIntent extends Intent {
  const _GoBackIntent();
}

class OpenVkApp extends StatefulWidget {
  final AuthHandler authHandler;
  final OpenVkClient client;
  final SavedAccount? initialAccount;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool initialOobeCompleted;

  const OpenVkApp({
    super.key,
    required this.authHandler,
    required this.client,
    this.initialAccount,
    this.navigatorKey,
    this.initialOobeCompleted = true,
  });

  @override
  State<OpenVkApp> createState() => _OpenVkAppState();
}

class _OpenVkAppState extends State<OpenVkApp> with WidgetsBindingObserver {
  late final GlobalKey<NavigatorState> _navigatorKey;
  SavedAccount? _currentAccount;
  late bool _isOobeCompleted;
  StreamSubscription<LongPollNotificationEvent>? _longPollSub;
  StreamSubscription<AppNotification>? _notificationTapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isOobeCompleted = widget.initialOobeCompleted;
    _navigatorKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();
    _currentAccount = widget.initialAccount;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _setupNotifications();
    _initBackgroundService();
  }

  void _initBackgroundService() {
    BackgroundServiceManager.instance.initialize(
      onBackgroundFetch: () async {
        await widget.client.longPollService.performQuickSync();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      BackgroundServiceManager.instance.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      BackgroundServiceManager.instance.onAppResumed();
      widget.client.longPollService.reconnect();
    }
  }

  Future<void> _onOobeCompleted() async {
    await AppDatabase.instance.setOobeCompleted(true);
    if (mounted) {
      setState(() {
        _isOobeCompleted = true;
      });
    }
  }

  void _setupNotifications() {
    NotificationDispatcher.instance.requestPermissions();

    _longPollSub = widget.client.longPollService.notifications.listen((event) {
      if (!event.isOut) {
        NotificationDispatcher.instance.showMessageNotification(
          peerId: event.peerId,
          title: event.title,
          body: event.text,
          messageId: event.messageId,
        );
      }
    });

    _notificationTapSub = NotificationDispatcher.instance.onNotificationTap.listen((notification) {
      _handleNotificationTap(notification);
    });
  }

  void _handleNotificationTap(AppNotification notification) {
    final peerId = notification.peerId;
    if (peerId == null || _currentAccount == null) return;

    final store = widget.client.messengerStore;
    var conv = store.getConversationNotifier(peerId)?.value;
    conv ??= ConversationItem(
      peerId: peerId,
      peerType: peerId > 2000000000 ? 'chat' : (peerId < 0 ? 'group' : 'user'),
      inRead: 0,
      outRead: 0,
      unreadCount: 1,
      isImportant: false,
      isUnanswered: false,
      lastMessage: Message(
        id: notification.messageId ?? 0,
        date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        peerId: peerId,
        fromId: peerId,
        text: notification.body,
        isOut: false,
        isImportant: false,
        isUnread: true,
        attachments: const [],
        fwdMessages: const [],
        conversationMessageId: 0,
        updateTime: 0,
      ),
    );

    final nav = _navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatConversationView(
            client: widget.client,
            account: _currentAccount!,
            conversation: conv!,
            title: store.getTitle(conv),
            avatarUrl: store.getAvatarUrl(conv),
            currentUserId: _currentAccount!.userId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _longPollSub?.cancel();
    _notificationTapSub?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      final nav = _navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.maybePop();
        return true;
      }
    }
    return false;
  }

  void _onLoginSuccess() async {
    final account = await widget.authHandler.restoreSession();
    NotificationDispatcher.instance.requestPermissions();
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
      navigatorKey: _navigatorKey,
      title: 'OpenVK',
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.themeData,
      scrollBehavior: const RetroScrollBehavior(),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): const _GoBackIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        _GoBackIntent: CallbackAction<_GoBackIntent>(
          onInvoke: (intent) {
            final nav = _navigatorKey.currentState;
            if (nav != null && nav.canPop()) {
              nav.maybePop();
            }
            return null;
          },
        ),
      },
      home: !_isOobeCompleted
          ? OobeView(
              onCompleted: _onOobeCompleted,
            )
          : _currentAccount == null
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
  MediaTab _mediaTab = MediaTab.photos;
  String _newsFilter = 'my';
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
    _initUnreadCount();
  }

  void _initUnreadCount() {
    if (widget.account.accessToken.isNotEmpty) {
      unawaited(
        MessagesHandler(widget.client).getConversations(
          count: 20,
          cachePolicy: CachePolicy.networkFirst,
        ),
      );
    }
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _canDrag = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_canDrag) return;
    final delta = details.primaryDelta ?? 0;
    // When closed, only react to swiping right
    if (_drawerController.value <= 0 && delta <= 0) {
      return;
    }
    final nextVal =
        (_drawerController.value + delta / _currentSidebarWidth).clamp(0.0, 1.0);
    _drawerController.value = nextVal;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_canDrag) return;
    _canDrag = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 300) {
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
      if (_drawerController.value >= 0.4) {
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

  void _handleDragCancel() {
    _canDrag = false;
    if (_drawerController.value > 0 && _drawerController.value < 1.0) {
      if (_drawerController.value >= 0.4) {
        _drawerController.animateTo(1.0, curve: Curves.easeOutCubic);
      } else {
        _drawerController.animateTo(0.0, curve: Curves.easeOutCubic);
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      if (notification is OverscrollNotification) {
        final dx = notification.dragDetails?.delta.dx;
        if (dx != null && dx > 0) {
          _drawerController.value =
              (_drawerController.value + dx / _currentSidebarWidth).clamp(0.0, 1.0);
        }
      } else if (notification is ScrollUpdateNotification) {
        if (_drawerController.value > 0) {
          final dx = notification.dragDetails?.delta.dx;
          if (dx != null && dx < 0) {
            _drawerController.value =
                (_drawerController.value + dx / _currentSidebarWidth).clamp(0.0, 1.0);
          }
        }
      } else if (notification is ScrollEndNotification) {
        if (_drawerController.value > 0 && _drawerController.value < 1.0) {
          final velocity = notification.dragDetails?.primaryVelocity ?? 0;
          if (velocity > 300) {
            _drawerController.animateTo(
              1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          } else if (velocity < -300) {
            _drawerController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          } else if (_drawerController.value >= 0.35) {
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
    }
    return false;
  }

  void _onSelectSection(RetroSection section, {required bool isWide}) {
    if (section == RetroSection.photos) {
      _currentSection = RetroSection.media;
      _mediaTab = MediaTab.photos;
    } else if (section == RetroSection.videos) {
      _currentSection = RetroSection.media;
      _mediaTab = MediaTab.videos;
    } else if (section == RetroSection.audio) {
      _currentSection = RetroSection.media;
      _mediaTab = MediaTab.audio;
    } else {
      _currentSection = section;
    }
    setState(() {});
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

        return Stack(
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
                  NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: _buildMainContent(
                      isWide: false,
                      hideBottomBar: hideBottomBar,
                      screenWidth: constraints.maxWidth,
                    ),
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
                              onHorizontalDragStart: _handleDragStart,
                              onHorizontalDragUpdate: _handleDragUpdate,
                              onHorizontalDragEnd: _handleDragEnd,
                              onHorizontalDragCancel: _handleDragCancel,
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
                  // Left-edge drag detector to open drawer from screen edge
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 20,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _handleDragStart,
                      onHorizontalDragUpdate: _handleDragUpdate,
                      onHorizontalDragEnd: _handleDragEnd,
                      onHorizontalDragCancel: _handleDragCancel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent({
    required bool isWide,
    required bool hideBottomBar,
    double screenWidth = double.infinity,
  }) {
    final bool isWall = _currentSection == RetroSection.profile;
    final bool isNews = _currentSection == RetroSection.news;
    final bool isMedia = _currentSection == RetroSection.media ||
        _currentSection == RetroSection.photos ||
        _currentSection == RetroSection.videos ||
        _currentSection == RetroSection.audio;

    Widget? appBarTitleWidget;
    String? appBarTitle = _currentSection.title;
    Widget? appBarLeading;
    List<Widget>? appBarActions;
    bool centerMiddle = true;

    if (isNews) {
      appBarTitle = null;
      appBarTitleWidget = RetroSegmentedControl<String>(
        tabs: const {
          'my': 'Мои новости',
          'global': 'Все новости',
        },
        selected: _newsFilter,
        onSelected: (filter) => setState(() => _newsFilter = filter),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        hasShadow: false,
      );
      appBarLeading = null;
    } else if (isWall) {
      appBarTitle = 'Моя Стена';
      appBarLeading = RetroHeaderButton(
        text: 'Настройки',
        onPressed: () => setState(() => _currentSection = RetroSection.settings),
      );
      appBarActions = [
        RetroHeaderButton(
          text: 'Редакт.',
          onPressed: () => setState(() => _currentSection = RetroSection.settings),
        ),
      ];
    } else if (isMedia) {
      appBarTitle = null;
      appBarTitleWidget = RetroSegmentedControl<MediaTab>(
        tabs: const {
          MediaTab.photos: 'Фото',
          MediaTab.videos: 'Видео',
          MediaTab.audio: 'Аудио',
        },
        selected: _mediaTab,
        onSelected: (tab) => setState(() => _mediaTab = tab),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        hasShadow: false,
      );
      appBarLeading = null;
      if (_mediaTab == MediaTab.audio) {
        appBarActions = [
          RetroHeaderButton(
            icon: Icons.queue_music_rounded,
            text: 'Плейлисты',
            onPressed: () => AudioPlaylistsView.open(
              context,
              client: widget.client,
              account: widget.account,
              ownerId: widget.account.userId,
            ),
          ),
        ];
      }
    } else {
      appBarLeading = null;
    }

    return Scaffold(
      appBar: RetroAppBar(
        title: appBarTitle,
        titleWidget: appBarTitleWidget,
        leading: appBarLeading,
        actions: appBarActions,
        centerMiddle: centerMiddle,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMessages = _currentSection == RetroSection.messages;
          final bool isConstrained = !isMessages && constraints.maxWidth > 850;

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
                constraints: BoxConstraints(
                  maxWidth: isMessages ? double.infinity : 850,
                ),
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
                child: _buildSectionBody(isWide: isWide),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: hideBottomBar
          ? const RetroAudioMiniPlayer()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RetroAudioMiniPlayer(),
                ListenableBuilder(
                  listenable: widget.client.messengerStore.totalUnreadCount,
                  builder: (context, _) {
                    final count =
                        widget.client.messengerStore.totalUnreadCount.value;
                    return RetroBottomBar(
                      currentTab: _currentSection.bottomTab,
                      unreadMessagesCount: count,
                      onTabSelected: (tab) => setState(
                        () => _currentSection = RetroSection.fromTab(tab),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionBody({required bool isWide}) {
    Widget body;
    if (_currentSection == RetroSection.settings) {
      body = SettingsView(onLogout: widget.onLogout);
    } else if (_currentSection == RetroSection.messages) {
      body = MessagesView(
        key: const PageStorageKey('messages_view'),
        client: widget.client,
        account: widget.account,
      );
    } else if (_currentSection == RetroSection.profile) {
      body = WallView(
        key: const PageStorageKey('wall_view'),
        client: widget.client,
        account: widget.account,
        onOpenSettings: () => setState(() => _currentSection = RetroSection.settings),
        onOpenEditProfile: () => setState(() => _currentSection = RetroSection.settings),
      );
    } else if (_currentSection == RetroSection.news) {
      body = NewsfeedView(
        key: const PageStorageKey('newsfeed_view'),
        client: widget.client,
        account: widget.account,
        filter: _newsFilter,
        onFilterChanged: (filter) {
          if (_newsFilter != filter) {
            setState(() => _newsFilter = filter);
          }
        },
      );
    } else if (_currentSection == RetroSection.media ||
        _currentSection == RetroSection.photos ||
        _currentSection == RetroSection.videos ||
        _currentSection == RetroSection.audio) {
      body = MediaView(
        key: const PageStorageKey('media_view'),
        client: widget.client,
        account: widget.account,
        tab: _mediaTab,
        onTabChanged: (tab) {
          if (_mediaTab != tab) {
            setState(() => _mediaTab = tab);
          }
        },
        hideAppBar: true,
      );
    } else {
      body = Center(
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

    if (!isWide &&
        (_currentSection == RetroSection.profile ||
            _currentSection == RetroSection.settings ||
            _currentSection == RetroSection.messages)) {
      body = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: body,
      );
    }

    return body;
  }
}
