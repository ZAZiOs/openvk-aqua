import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/notifications/notification_dispatcher.dart';
import '../../../core/utils/download_helper.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_status_badge.dart';

class OobeView extends StatefulWidget {
  final Future<void> Function() onCompleted;

  const OobeView({
    super.key,
    required this.onCompleted,
  });

  @override
  State<OobeView> createState() => _OobeViewState();
}

class _OobeViewState extends State<OobeView> {
  bool _notificationsEnabled = false;
  bool _isRequesting = false;
  bool _isCompleting = false;

  bool _storageEnabled = true;
  bool _isRequestingStorage = false;
  String _storagePathText = 'Загрузки/OpenVK';

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  void _checkInitialStatus() async {
    final displayPath = await DownloadHelper.getDisplayPath();
    bool canWrite = true;
    if (!kIsWeb) {
      canWrite = await DownloadHelper.ensureDirectoryAndVerify();
    }

    if (mounted) {
      setState(() {
        _storagePathText = displayPath;
        _storageEnabled = canWrite;
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
          _notificationsEnabled = true;
        }
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      final granted = await NotificationDispatcher.instance.requestPermissions();
      if (mounted) {
        setState(() {
          _notificationsEnabled = granted;
        });
      }
    } catch (e) {
      debugPrint('[OobeView] Error requesting notification permissions: $e');
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _toggleOrRequestStoragePermission() async {
    if (_isRequestingStorage) return;

    if (_storageEnabled) {
      setState(() => _storageEnabled = false);
      return;
    }

    setState(() => _isRequestingStorage = true);
    try {
      final success = await DownloadHelper.ensureDirectoryAndVerify();
      if (mounted) {
        setState(() {
          _storageEnabled = success;
        });
      }
    } catch (e) {
      debugPrint('[OobeView] Error requesting storage permission: $e');
    } finally {
      if (mounted) {
        setState(() => _isRequestingStorage = false);
      }
    }
  }

  Future<void> _completeOobe() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    // If notifications were not yet requested on Android/iOS, try requesting
    if (!_notificationsEnabled && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final granted = await NotificationDispatcher.instance.requestPermissions();
        _notificationsEnabled = granted;
      } catch (_) {}
    }

    if (_storageEnabled) {
      try {
        await DownloadHelper.ensureDirectoryAndVerify();
      } catch (_) {}
    }

    try {
      await widget.onCompleted();
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E323B),
      appBar: const RetroAppBar(
        title: 'Ассистент настройки',
        centerMiddle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Authentic iOS 6 Dark Linen background texture
          ExcludeSemantics(
            child: Image.asset(
              'assets/splash/bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF383C46),
                      Color(0xFF22252B),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildPermissionsGroup(),
                      const SizedBox(height: 28),
                      _buildFooterAction(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // iOS 6 App Icon with authentic gloss and shadow
        ExcludeSemantics(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 6),
                  blurRadius: 14,
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.5),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/icon/app_icon_full.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF3B6799),
                        child: const Center(
                          child: Text(
                            'O',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gloss effect on icon
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'OpenVK Aqua',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.4,
            shadows: [
              Shadow(
                color: Color(0xB3000000),
                offset: Offset(0, -1),
                blurRadius: 1,
              ),
              Shadow(
                color: Color(0x66000000),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Для начала работы настроим базовые разрешения и службы приложения.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFFD6DBE4),
            height: 1.35,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsGroup() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC3C7CE), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          children: [
            // Row 1: Notifications
            _buildSettingRow(
              onTap: _notificationsEnabled ? null : _requestNotificationPermission,
              iconWidget: _buildGlossIcon(
                icon: Icons.notifications_active,
                gradientColors: const [Color(0xFFE54D42), Color(0xFFB52319)],
              ),
              title: 'Уведомления',
              subtitle: 'Оповещения о входящих сообщениях и беседах',
              trailing: RetroStatusBadge(
                isSuccess: _notificationsEnabled,
              ),
            ),
            _buildEtchedDivider(),

            // Row 2: Photos / Media Library
            _buildSettingRow(
              iconWidget: _buildGlossIcon(
                icon: Icons.photo_library,
                gradientColors: const [Color(0xFF4BA3E3), Color(0xFF1E62B3)],
              ),
              title: 'Фотографии и файлы',
              subtitle: 'Прикрепление картинок и выбор медиафайлов',
              trailing: const RetroStatusBadge(isSuccess: true),
            ),
            _buildEtchedDivider(),

            // Row 3: OpenVK Downloads Folder
            _buildSettingRow(
              onTap: _storageEnabled ? null : _toggleOrRequestStoragePermission,
              iconWidget: _buildGlossIcon(
                icon: Icons.folder_special_rounded,
                gradientColors: const [Color(0xFFFFB300), Color(0xFFE65100)],
              ),
              title: 'Папка загрузок',
              subtitle: 'Сохранение данных в $_storagePathText',
              trailing: RetroStatusBadge(
                isSuccess: _storageEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF656565),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: rowContent,
      ),
    );
  }

  Widget _buildGlossIcon({
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            children: [
              Center(
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEtchedDivider() {
    return const ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(
            height: 1,
            child: ColoredBox(color: Color(0xFFE2E4E8)),
          ),
          SizedBox(
            height: 1,
            child: ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterAction() {
    return RetroButton(
      text: 'Начать использование',
      isLoading: _isCompleting,
      fontSize: 18,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
      onPressed: _completeOobe,
    );
  }
}
