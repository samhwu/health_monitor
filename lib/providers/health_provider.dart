// lib/providers/health_provider.dart
//
// 全域狀態管理：整合資料庫操作、快取最新記錄、統計數據，
// 讓所有 Widget 透過 context.watch<HealthProvider>() 取得即時更新。

import 'package:flutter/foundation.dart';
import '../database/health_database.dart';
import '../models/health_record.dart';
import '../models/user_profile.dart';

class HealthProvider extends ChangeNotifier {
  final HealthDatabase _db;

  HealthProvider(this._db) {
    _init();
  }

  // ─── State ───────────────────────────────────────────────────────────────

  List<HealthRecord> _records = [];
  HealthRecord? _latestRecord;
  Map<String, dynamic> _stats30d = {};
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  List<HealthRecord> get records => _records;
  HealthRecord? get latestRecord => _latestRecord;
  Map<String, dynamic> get stats30d => _stats30d;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await refresh();
    await _loadProfile();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _records = await _db.getAllRecords(limit: 200);
      _latestRecord = _records.isNotEmpty ? _records.first : null;
      _stats30d = await _db.getStats(days: 30);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> addRecord(HealthRecord record) async {
    final id = await _db.insertRecord(record);
    await refresh();
    return id;
  }

  Future<void> deleteRecord(int id) async {
    await _db.deleteRecord(id);
    await refresh();
  }

  Future<void> updateRecord(HealthRecord record) async {
    await _db.updateRecord(record);
    await refresh();
  }

  // ─── Filtered Queries ────────────────────────────────────────────────────

  List<HealthRecord> recordsForRange(DateTime start, DateTime end) {
    return _records.where((r) =>
        r.timestamp.isAfter(start) && r.timestamp.isBefore(end)
    ).toList();
  }

  List<HealthRecord> get last7Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _records.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  // ─── User Profile ────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final name = await _db.getSetting('profile_name');
    final age = await _db.getSetting('profile_age');
    final gender = await _db.getSetting('profile_gender');
    final height = await _db.getSetting('profile_height');
    final targetHR = await _db.getSetting('target_hr_max');

    _profile = UserProfile(
      name: name ?? '',
      age: age != null ? int.tryParse(age) : null,
      gender: gender,
      heightCm: height != null ? double.tryParse(height) : null,
      targetHRMax: targetHR != null ? int.tryParse(targetHR) : null,
    );
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _db.setSetting('profile_name', profile.name);
    if (profile.age != null) await _db.setSetting('profile_age', profile.age.toString());
    if (profile.gender != null) await _db.setSetting('profile_gender', profile.gender!);
    if (profile.heightCm != null) await _db.setSetting('profile_height', profile.heightCm.toString());
    if (profile.targetHRMax != null) await _db.setSetting('target_hr_max', profile.targetHRMax.toString());
    _profile = profile;
    notifyListeners();
  }

  // ─── BMI Calculation ─────────────────────────────────────────────────────

  double? get currentBMI {
    if (_latestRecord?.weight == null) return null;
    if (_profile?.heightCm == null) return null;
    final h = _profile!.heightCm! / 100;
    return _latestRecord!.weight! / (h * h);
  }

  String get bmiCategory {
    final bmi = currentBMI;
    if (bmi == null) return '無資料';
    if (bmi < 18.5) return '體重過輕';
    if (bmi < 24.0) return '正常範圍';
    if (bmi < 27.0) return '過重';
    if (bmi < 30.0) return '輕度肥胖';
    return '中重度肥胖';
  }

  // ─── Streak (連續記錄天數) ────────────────────────────────────────────────

  int get currentStreak {
    if (_records.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = DateTime.now();
    final days = <String>{};
    for (final r in _records) {
      days.add('${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}');
    }
    while (true) {
      final key = '${cursor.year}-${cursor.month}-${cursor.day}';
      if (days.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
