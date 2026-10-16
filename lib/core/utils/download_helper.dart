import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Helper utility for resolving and preparing OpenVK download directory
/// across Windows, Android, iOS, macOS, and Linux.
class DownloadHelper {
  DownloadHelper._();

  /// Resolves the dedicated OpenVK downloads directory.
  /// - Windows: {User Downloads}/OpenVK
  /// - Android: /storage/emulated/0/Download/OpenVK (or app downloads/OpenVK)
  /// - iOS: {Application Documents}/OpenVK (accessible in Files app)
  /// - macOS / Linux: {User Downloads}/OpenVK
  static Future<Directory> getOpenVkDownloadDirectory() async {
    if (kIsWeb) {
      return Directory('OpenVK');
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      Directory? downloadsDir;
      try {
        downloadsDir = await getDownloadsDirectory();
      } catch (_) {}
      try {
        downloadsDir ??= await getApplicationDocumentsDirectory();
      } catch (_) {}
      if (downloadsDir == null) {
        final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
        downloadsDir = Directory(p.join(home, 'Downloads'));
      }
      return Directory(p.join(downloadsDir.path, 'OpenVK'));
    } else if (Platform.isAndroid) {
      try {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (await publicDownload.exists()) {
          return Directory(p.join(publicDownload.path, 'OpenVK'));
        }
      } catch (_) {}

      Directory? downloadsDir;
      try {
        downloadsDir = await getDownloadsDirectory();
      } catch (_) {}
      try {
        downloadsDir ??= await getExternalStorageDirectory();
      } catch (_) {}
      try {
        downloadsDir ??= await getApplicationDocumentsDirectory();
      } catch (_) {}
      downloadsDir ??= Directory('/storage/emulated/0/Download');
      return Directory(p.join(downloadsDir.path, 'OpenVK'));
    } else if (Platform.isIOS) {
      Directory? docsDir;
      try {
        docsDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
      docsDir ??= Directory('Documents');
      return Directory(p.join(docsDir.path, 'OpenVK'));
    } else {
      Directory? docsDir;
      try {
        docsDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
      docsDir ??= Directory('.');
      return Directory(p.join(docsDir.path, 'OpenVK'));
    }
  }

  /// Returns a clean user-facing path representation tailored to the current platform.
  static Future<String> getDisplayPath() async {
    if (kIsWeb) return 'Загрузки/OpenVK';

    if (Platform.isWindows) {
      return 'Загрузки\\OpenVK';
    } else if (Platform.isAndroid) {
      return 'Downloads/OpenVK';
    } else if (Platform.isIOS) {
      return 'Файлы: Документы/OpenVK';
    } else if (Platform.isMacOS || Platform.isLinux) {
      return 'Загрузки/OpenVK';
    }
    return 'Загрузки/OpenVK';
  }

  /// Ensures the directory exists and verifies write access.
  static Future<bool> ensureDirectoryAndVerify() async {
    if (kIsWeb) return true;
    try {
      final dir = await getOpenVkDownloadDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Test write permission with a hidden temporary file
      final testFile = File(p.join(dir.path, '.test_perm'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (e) {
      debugPrint('[DownloadHelper] Error verifying directory permissions: $e');
      return false;
    }
  }
}
