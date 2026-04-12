// lib/database/health_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/health_record.dart';

class HealthDatabase {
  static final HealthDatabase _instance = HealthDatabase._internal();
  factory HealthDatabase() => _instance;
  HealthDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // 在 Web 上暫時回傳一個 dummy 或是使用 sqflite_common_ffi_web
      // 為了不讓畫面空白，我們先丟出異常但會被 Provider 捕捉
      throw UnsupportedError('Web 平台暫不支援本地資料庫 (sqflite)');
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'health_monitor.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // 健康記錄主表
    await db.execute('''
      CREATE TABLE health_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        systolic INTEGER,
        diastolic INTEGER,
        heart_rate INTEGER,
        weight REAL,
        spo2 REAL,
        source TEXT DEFAULT 'bluetooth',
        device_name TEXT,
        notes TEXT
      )
    ''');

    // 裝置配對記錄表
    await db.execute('''
      CREATE TABLE paired_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT UNIQUE NOT NULL,
        device_name TEXT NOT NULL,
        device_type TEXT NOT NULL,
        last_connected INTEGER,
        is_favorite INTEGER DEFAULT 0
      )
    ''');

    // 用戶設定表
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 步數紀錄表
    await db.execute('''
      CREATE TABLE daily_steps (
        date TEXT PRIMARY KEY,
        steps INTEGER DEFAULT 0,
        base_steps INTEGER DEFAULT 0
      )
    ''');

    // 建立索引加速查詢
    await db.execute(
      'CREATE INDEX idx_timestamp ON health_records(timestamp DESC)'
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE health_records ADD COLUMN notes TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE daily_steps (
          date TEXT PRIMARY KEY,
          steps INTEGER DEFAULT 0,
          base_steps INTEGER DEFAULT 0
        )
      ''');
    }
  }

  // ─── CRUD for health_records ─────────────────────────────────────────────

  Future<int> insertRecord(HealthRecord record) async {
    final db = await database;
    return await db.insert(
      'health_records',
      record.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HealthRecord>> getAllRecords({int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      'health_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  Future<List<HealthRecord>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'health_records',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  Future<HealthRecord?> getLatestRecord() async {
    final db = await database;
    final maps = await db.query(
      'health_records',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HealthRecord.fromMap(maps.first);
  }

  Future<int> updateRecord(HealthRecord record) async {
    final db = await database;
    return await db.update(
      'health_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return await db.delete(
      'health_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Statistics ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats({int days = 30}) async {
    final db = await database;
    final since = DateTime.now().subtract(Duration(days: days));
    final maps = await db.query(
      'health_records',
      where: 'timestamp > ?',
      whereArgs: [since.millisecondsSinceEpoch],
    );

    if (maps.isEmpty) return {};

    double avgSystolic = 0, avgDiastolic = 0, avgHR = 0, avgSpO2 = 0, avgWeight = 0;
    int bpCount = 0, hrCount = 0, spo2Count = 0, weightCount = 0;

    for (final m in maps) {
      if (m['systolic'] != null) { avgSystolic += m['systolic'] as int; bpCount++; }
      if (m['diastolic'] != null) avgDiastolic += m['diastolic'] as int;
      if (m['heart_rate'] != null) { avgHR += m['heart_rate'] as int; hrCount++; }
      if (m['spo2'] != null) { avgSpO2 += m['spo2'] as double; spo2Count++; }
      if (m['weight'] != null) { avgWeight += m['weight'] as double; weightCount++; }
    }

    return {
      'total_records': maps.length,
      'avg_systolic': bpCount > 0 ? avgSystolic / bpCount : null,
      'avg_diastolic': bpCount > 0 ? avgDiastolic / bpCount : null,
      'avg_heart_rate': hrCount > 0 ? avgHR / hrCount : null,
      'avg_spo2': spo2Count > 0 ? avgSpO2 / spo2Count : null,
      'avg_weight': weightCount > 0 ? avgWeight / weightCount : null,
    };
  }

  // ─── Paired Devices ──────────────────────────────────────────────────────

  Future<void> savePairedDevice({
    required String deviceId,
    required String deviceName,
    required String deviceType,
  }) async {
    final db = await database;
    await db.insert(
      'paired_devices',
      {
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType,
        'last_connected': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    final db = await database;
    return await db.query('paired_devices', orderBy: 'last_connected DESC');
  }

  // ─── User Settings ───────────────────────────────────────────────────────

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  // ─── Daily Steps ─────────────────────────────────────────────────────────

  Future<void> updateDailySteps({
    required String date,
    required int steps,
    required int baseSteps,
  }) async {
    final db = await database;
    await db.insert(
      'daily_steps',
      {
        'date': date,
        'steps': steps,
        'base_steps': baseSteps,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getDailySteps(String date) async {
    final db = await database;
    final maps = await db.query(
      'daily_steps',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getStepsHistory({int limit = 30}) async {
    final db = await database;
    return await db.query(
      'daily_steps',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
