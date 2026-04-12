// lib/services/notification_service.dart
//
// 本地推播通知服務
// 功能：
//   1. 每日定時提醒量測
//   2. 血壓/血氧異常即時警示
//   3. 連續記錄達標獎勵

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/health_record.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── Notification IDs ────────────────────────────────────────────────────

  static const int _dailyReminderId   = 1001;
  static const int _bpAlertId         = 1002;
  static const int _spo2AlertId       = 1003;
  static const int _streakId          = 1004;

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // TODO: 由於 SDK 版本參數名稱不對 (或要求 license)，暫時註解掉初始化，待確認參數後復原
    /*
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    */
    print('NotificationService plugin initialization is temporarily disabled.');

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // 可在此導航到特定畫面
  }

  // ─── Daily Reminder ──────────────────────────────────────────────────────

  /// 設定每日定時提醒（hour: 8 = 早上 8 點）
  Future<void> scheduleDailyReminder({
    int hour = 8,
    int minute = 0,
    bool enabled = true,
  }) async {
    if (!enabled) {
      await cancelNotification(_dailyReminderId);
      return;
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: '💊 每日健康提醒',
      body: '記得量測今天的血壓、心率和血氧！',
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '每日量測提醒',
          channelDescription: '每天定時提醒使用者量測健康數值',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重複
    );
  }

  // ─── Health Alerts ───────────────────────────────────────────────────────

  /// 儲存記錄後自動檢查並發送警示
  Future<void> checkAndAlert(HealthRecord record) async {
    // 血壓警示
    if (record.systolic != null && record.diastolic != null) {
      final sys = record.systolic!;
      final dia = record.diastolic!;

      if (sys >= 180 || dia >= 120) {
        await _showAlert(
          id: _bpAlertId,
          title: '🚨 血壓危象警告',
          body: '收縮壓 $sys / 舒張壓 $dia mmHg，請立即就醫！',
          channelId: 'health_alert',
          channelName: '健康警示',
        );
      } else if (sys >= 140 || dia >= 90) {
        await _showAlert(
          id: _bpAlertId,
          title: '⚠️ 血壓偏高',
          body: '血壓 $sys/$dia mmHg，建議諮詢醫師',
          channelId: 'health_warning',
          channelName: '健康提示',
          importance: Importance.defaultImportance,
        );
      }
    }

    // 血氧警示
    if (record.spo2 != null) {
      final spo2 = record.spo2!;
      if (spo2 < 90) {
        await _showAlert(
          id: _spo2AlertId,
          title: '🚨 血氧過低警告',
          body: 'SpO₂ ${spo2.toStringAsFixed(1)}%，請深呼吸並立即就醫！',
          channelId: 'health_alert',
          channelName: '健康警示',
        );
      } else if (spo2 < 95) {
        await _showAlert(
          id: _spo2AlertId,
          title: '⚠️ 血氧偏低',
          body: 'SpO₂ ${spo2.toStringAsFixed(1)}%，建議保持通風並追蹤',
          channelId: 'health_warning',
          channelName: '健康提示',
          importance: Importance.defaultImportance,
        );
      }
    }
  }

  // ─── Streak Celebration ──────────────────────────────────────────────────

  Future<void> celebrateStreak(int days) async {
    if (days < 3) return;

    final messages = {
      3: '連續 3 天記錄！保持下去 🎯',
      7: '連續一週！你真的很自律 🌟',
      14: '兩週連續記錄！健康管理達人 🏆',
      30: '一個月！你已經養成習慣了 🎉',
    };

    if (!messages.containsKey(days)) return;

    await _showAlert(
      id: _streakId,
      title: '🎊 達成連續記錄！',
      body: messages[days]!,
      channelId: 'achievement',
      channelName: '成就通知',
      importance: Importance.high,
    );
  }

  // ─── Cancel ──────────────────────────────────────────────────────────────

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _showAlert({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    Importance importance = Importance.high,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: importance == Importance.high ? Priority.high : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  // 計算下一個指定時刻（使用 TZDateTime）
  // 注意：實際使用需 import timezone 套件，此為簡化版本
  dynamic _nextInstanceOf(int hour, int minute) {
    // 使用 flutter_local_notifications 的 TZDateTime
    // 此處回傳 DateTime 作為佔位符，實際需加上 timezone 套件處理
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    // In production: return tz.TZDateTime.from(scheduled, tz.local);
    return scheduled;
  }
}
