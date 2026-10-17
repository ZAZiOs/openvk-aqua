import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db/app_database.dart';

class BackgroundServiceManager {
  static final BackgroundServiceManager instance = BackgroundServiceManager._();

  BackgroundServiceManager._();

  static const MethodChannel _channel =
      MethodChannel('oss.zazios.ovkaqua/background_service');

  AsyncCallback? _onBackgroundFetch;
  bool _isInitialized = false;

  /// Initializes the background service manager and listens to native triggers (e.g. iOS background fetch).
  Future<void> initialize({AsyncCallback? onBackgroundFetch}) async {
    if (_isInitialized) return;
    _isInitialized = true;
    _onBackgroundFetch = onBackgroundFetch;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onBackgroundFetch') {
        if (_onBackgroundFetch != null) {
          try {
            await _onBackgroundFetch!();
          } catch (e) {
            debugPrint('[BackgroundServiceManager] Error in onBackgroundFetch: $e');
          }
        }
      }
    });

    final isEnabled = await isBackgroundSyncEnabled();
    if (isEnabled && !kIsWeb && Platform.isAndroid) {
      await startService();
    }
  }

  /// Whether the user enabled background service in app settings (defaults to true).
  Future<bool> isBackgroundSyncEnabled() async {
    try {
      final db = AppDatabase.instance.db;
      final res = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['background_sync_enabled'],
      );
      if (res.isEmpty) return true; // Enabled by default for reliable notifications
      return res.first['value'] == '1' || res.first['value'] == 'true';
    } catch (e) {
      return true;
    }
  }

  /// Toggles background service setting.
  Future<void> setBackgroundSyncEnabled(bool enabled) async {
    try {
      final db = AppDatabase.instance.db;
      await db.insert(
        'app_settings',
        {'key': 'background_sync_enabled', 'value': enabled ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (enabled) {
        await startService();
      } else {
        await stopService();
      }
    } catch (e) {
      debugPrint('[BackgroundServiceManager] Error saving background sync setting: $e');
    }
  }

  /// Starts the persistent background foreground service (Android) or requests background task (iOS).
  Future<void> startService({
    String title = 'OpenVK Aqua',
    String text = 'Фоновая служба сообщений активна',
  }) async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('startService', {
          'title': title,
          'text': text,
        });
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('beginBackgroundTask');
      }
    } catch (e) {
      debugPrint('[BackgroundServiceManager] Error starting service: $e');
    }
  }

  /// Stops the background service.
  Future<void> stopService() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopService');
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('endBackgroundTask');
      }
    } catch (e) {
      debugPrint('[BackgroundServiceManager] Error stopping service: $e');
    }
  }

  /// Checks if Android foreground service is actively running.
  Future<bool> isServiceRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isServiceRunning');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Checks whether battery optimization is disabled on Android.
  Future<bool> isBatteryOptimizationIgnored() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res =
          await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Prompts Android system dialog to disable battery optimization.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[BackgroundServiceManager] Error requesting battery opt: $e');
    }
  }

  /// Called when Flutter application enters background.
  Future<void> onAppPaused() async {
    if (kIsWeb) return;
    final isEnabled = await isBackgroundSyncEnabled();
    if (!isEnabled) return;

    if (Platform.isAndroid) {
      await startService();
    } else if (Platform.isIOS) {
      await _channel.invokeMethod('beginBackgroundTask');
    }
  }

  /// Called when Flutter application returns to foreground.
  Future<void> onAppResumed() async {
    if (kIsWeb) return;
    if (Platform.isIOS) {
      await _channel.invokeMethod('endBackgroundTask');
    }
  }
}
