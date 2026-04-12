// lib/providers/step_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/health_database.dart';
import '../services/pedometer_service.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';

class StepProvider extends ChangeNotifier {
  final HealthDatabase _db;
  final PedometerService _service = PedometerService();

  int _todaySteps = 0;
  int _lastHardwareSteps = -1;
  String? _status;
  bool _isAvailable = false;
  String _currentDateString = '';

  int get todaySteps => _todaySteps;
  String get status => _status ?? '未知';
  bool get isAvailable => _isAvailable;

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  StepProvider(this._db) {
    _init();
  }

  Future<void> _init() async {
    _currentDateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _loadFromDb();
    
    _isAvailable = await _service.requestPermission();
    if (_isAvailable) {
      _startListening();
    }
    notifyListeners();
  }

  Future<void> _loadFromDb() async {
    final data = await _db.getDailySteps(_currentDateString);
    if (data != null) {
      _todaySteps = data['steps'] ?? 0;
      _lastHardwareSteps = data['base_steps'] ?? -1;
    } else {
      _todaySteps = 0;
      _lastHardwareSteps = -1;
    }
  }

  void _startListening() {
    _stepSubscription = _service.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
    );
    
    _statusSubscription = _service.pedestrianStatusStream.listen(
      _onStatusUpdate,
      onError: _onStatusError,
    );
  }

  void _onStepCount(StepCount event) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    // 檢查日期是否變換
    if (dateStr != _currentDateString) {
      // 跨日了，結算昨日到資料庫
      await _db.updateDailySteps(
        date: _currentDateString,
        steps: _todaySteps,
        baseSteps: _lastHardwareSteps,
      );
      
      // 重置今日
      _currentDateString = dateStr;
      _todaySteps = 0;
      _lastHardwareSteps = event.steps;
    }

    if (_lastHardwareSteps == -1) {
      // 第一次啟動，紀錄基準值
      _lastHardwareSteps = event.steps;
    } else {
      final diff = event.steps - _lastHardwareSteps;
      if (diff > 0) {
        _todaySteps += diff;
        _lastHardwareSteps = event.steps;
      } else if (diff < 0) {
        // 可能重啟手機了，重置基準值
        _lastHardwareSteps = event.steps;
      }
    }

    // 即時更新到資料庫（可選，增加穩定性）
    await _db.updateDailySteps(
      date: _currentDateString,
      steps: _todaySteps,
      baseSteps: _lastHardwareSteps,
    );

    notifyListeners();
  }

  void _onStatusUpdate(PedestrianStatus event) {
    _status = event.status;
    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint('Pedometer Step Error: $error');
  }

  void _onStatusError(error) {
    debugPrint('Pedometer Status Error: $error');
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}
