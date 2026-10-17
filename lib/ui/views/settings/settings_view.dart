import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../theme/retro_theme.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback? onLogout;

  const SettingsView({
    super.key,
    this.onLogout,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _backgroundSyncEnabled = true;
  bool _isBatteryOptIgnored = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bg = await BackgroundServiceManager.instance.isBackgroundSyncEnabled();
    final opt = await BackgroundServiceManager.instance.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = bg;
        _isBatteryOptIgnored = opt;
      });
    }
  }

  Future<void> _onToggleBackgroundSync(bool value) async {
    setState(() => _backgroundSyncEnabled = value);
    await BackgroundServiceManager.instance.setBackgroundSyncEnabled(value);
  }

  Future<void> _onRequestBatteryOpt() async {
    await BackgroundServiceManager.instance.requestIgnoreBatteryOptimizations();
    await Future.delayed(const Duration(seconds: 1));
    final opt = await BackgroundServiceManager.instance.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() => _isBatteryOptIgnored = opt);
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationDispatcher.instance.requestPermissions();
    await NotificationDispatcher.instance.showMessageNotification(
      peerId: 0,
      title: 'OpenVK Aqua',
      body: 'Фоновые уведомления работают успешно!',
      messageId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тестовое уведомление отправлено'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildSectionHeader('УВЕДОМЛЕНИЯ И ФОНОВАЯ РАБОТА'),
        Container(
          decoration: _cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 22,
                          color: RetroTheme.vkBlue,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Работа в фоне',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  color: Color(0xFF222222),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Служба для приёма сообщений при свёрнутом приложении',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF777777),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoSwitch(
                          value: _backgroundSyncEnabled,
                          activeTrackColor: RetroTheme.vkBlue,
                          onChanged: _onToggleBackgroundSync,
                        ),
                      ],
                    ),
                  ),
                  if (isAndroid) ...[
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE4E8EE), indent: 50),
                    InkWell(
                      onTap: _onRequestBatteryOpt,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(
                          children: [
                            Icon(
                              Icons.battery_charging_full_rounded,
                              size: 22,
                              color: _isBatteryOptIgnored
                                  ? const Color(0xFF27AE60)
                                  : const Color(0xFFE67E22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Оптимизация батареи',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      color: Color(0xFF222222),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isBatteryOptIgnored
                                        ? 'Фоновая работа разрешена без ограничений'
                                        : 'Нажмите, чтобы отключить засыпание в фоне',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: _isBatteryOptIgnored
                                          ? const Color(0xFF27AE60)
                                          : const Color(0xFFE67E22),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFFB0BDCB),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE4E8EE), indent: 50),
                  InkWell(
                    onTap: _sendTestNotification,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: RetroTheme.vkBlue,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Отправить тестовое уведомление',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF222222),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Color(0xFFB0BDCB),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('АККАУНТ'),
        Container(
          decoration: _cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        size: 20,
                        color: Color(0xFFD33A3A),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Выход',
                          style: TextStyle(
                            fontSize: 15.5,
                            color: Color(0xFFD33A3A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFFB0BDCB),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5E6E80),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static final BoxDecoration _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFC3D1E0), width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0C000000),
        offset: Offset(0, 1),
        blurRadius: 3,
      ),
    ],
  );
}
