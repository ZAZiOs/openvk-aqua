import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_payload.dart';

/// Single unified dispatcher for notifications across Android, iOS, Windows, macOS, and Linux.
class NotificationDispatcher {
  NotificationDispatcher._();
  static final NotificationDispatcher instance = NotificationDispatcher._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final StreamController<AppNotification> _notificationTapController =
      StreamController<AppNotification>.broadcast();

  /// Stream of notification tap events for deep-linking (e.g. opening a chat).
  Stream<AppNotification> get onNotificationTap => _notificationTapController.stream;

  /// Default notification channel for Android
  static const String channelId = 'openvk_aqua_messages';
  static const String channelName = 'Сообщения';
  static const String channelDescription = 'Уведомления о новых личных сообщениях и беседах';

  /// Currently active conversation peerId (to avoid spamming notifications
  /// if the user is already viewing that chat).
  int? activePeerId;

  /// Initializes notification services for all platforms.
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Открыть',
    );

    const windowsSettings = WindowsInitializationSettings(
      appName: 'OpenVK Aqua',
      appUserModelId: 'oss.zazios.ovkaqua',
      guid: '9a6d0c41-9a7e-40e9-bbf7-1dfb003a2741',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    _isInitialized = true;
    debugPrint('[NotificationDispatcher] Initialized successfully');
  }

  /// Requests notification permissions (Android 13+, iOS, macOS).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      } else if (Platform.isMacOS) {
        final macPlugin = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final granted = await macPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true; // Windows / Linux don't require explicit runtime prompt
    } catch (e) {
      debugPrint('[NotificationDispatcher] Error requesting permissions: $e');
      return false;
    }
  }

  /// Dispatches a notification across the current platform.
  Future<void> show(AppNotification notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Don't show if the user is currently reading this chat
    if (notification.peerId != null && notification.peerId == activePeerId) {
      debugPrint('[NotificationDispatcher] Skipped notification: chat ${notification.peerId} is currently active');
      return;
    }

    final details = _createPlatformDetails(notification);

    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: notification.effectivePayload,
      );
      debugPrint('[NotificationDispatcher] Dispatched notification #${notification.id} for peer ${notification.peerId}');
    } catch (e) {
      debugPrint('[NotificationDispatcher] Error showing notification: $e');
    }
  }

  /// Helper for dispatching a message notification.
  Future<void> showMessageNotification({
    required int peerId,
    required String title,
    required String body,
    int? messageId,
    Map<String, dynamic>? extra,
  }) async {
    final id = messageId != null && messageId > 0
        ? messageId
        : (peerId.abs() % 100000);

    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      peerId: peerId,
      messageId: messageId,
      extra: extra,
    );

    await show(notification);
  }

  /// Cancel a specific notification.
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('[NotificationDispatcher] Error cancelling notification $id: $e');
    }
  }

  /// Cancel all active notifications.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationDispatcher] Error cancelling all notifications: $e');
    }
  }

  NotificationDetails _createPlatformDetails(AppNotification notification) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      tag: notification.peerId != null ? 'peer_${notification.peerId}' : null,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails();

    const windowsDetails = WindowsNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
      windows: windowsDetails,
    );
  }

  void _handleNotificationTap(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    final notification = AppNotification.fromPayload(rawPayload);
    if (notification != null) {
      _notificationTapController.add(notification);
    }
  }

  void dispose() {
    _notificationTapController.close();
  }
}
