import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static AppDatabase? _instance;
  Database? _db;

  AppDatabase._();

  static AppDatabase get instance => _instance ??= AppDatabase._();

  @visibleForTesting
  static void setMockInstance(AppDatabase mock) {
    _instance = mock;
  }

  Database get db {
    if (_db == null) {
      throw StateError(
        'База данных не инициализирована. Вызовите `await AppDatabase.instance.init()` перед обращением к БД.',
      );
    }
    return _db!;
  }

  bool get isInitialized => _db != null && _db!.isOpen;

  Future<Database> init({
    String dbName = 'openvk.db',
    bool inMemory = false,
  }) async {
    if (_db != null && _db!.isOpen) return _db!;

    if (inMemory ||
        !kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      path = p.join(docsDir.path, dbName);
    }

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _db!.rawUpdate(
      "UPDATE instances SET base_url = 'https://api.openvk.org' WHERE base_url = 'https://openvk.org'",
    );

    await _db!.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_entries (
        key TEXT PRIMARY KEY,
        instance_id TEXT NOT NULL,
        tag TEXT,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        ttl_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cache_instance ON cache_entries(instance_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cache_tag ON cache_entries(tag)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS instances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        base_url TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        instance_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        name TEXT,
        avatar_url TEXT,
        access_token TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.insert('instances', {
      'name': 'OpenVK Official',
      'base_url': 'https://api.openvk.org',
      'is_active': 1,
    });
  }

  Future<bool> isOobeCompleted() async {
    if (!isInitialized) return false;
    try {
      final res = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['oobe_completed'],
      );
      if (res.isEmpty) return false;
      return res.first['value'] == '1' || res.first['value'] == 'true';
    } catch (e) {
      debugPrint('[AppDatabase] Error reading oobe_completed: $e');
      return false;
    }
  }

  Future<void> setOobeCompleted(bool completed) async {
    if (!isInitialized) return;
    try {
      await db.insert(
        'app_settings',
        {'key': 'oobe_completed', 'value': completed ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[AppDatabase] Error saving oobe_completed: $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
