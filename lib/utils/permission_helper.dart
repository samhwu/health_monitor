// lib/utils/permission_helper.dart
//
// 統一管理 Bluetooth 與 Camera 的 runtime 權限請求，
// 並依 Android 版本自動選擇正確的 permission group。

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// 請求藍芽所需的所有權限
  /// Android 12+ : BLUETOOTH_SCAN + BLUETOOTH_CONNECT
  /// Android 11- : BLUETOOTH + ACCESS_FINE_LOCATION
  static Future<bool> requestBluetooth(BuildContext context) async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
      Permission.location,
    ];

    final statuses = await permissions.request();

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (!allGranted && context.mounted) {
      final denied = statuses.entries
          .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
          .map((e) => _permissionName(e.key))
          .toList();

      final anyPermanent = statuses.values.any((s) => s.isPermanentlyDenied);

      await _showDeniedDialog(
        context,
        title: '藍芽權限不足',
        message: '需要以下權限才能連接健康裝置：\n${denied.join("、")}',
        showSettings: anyPermanent,
      );
    }

    return allGranted;
  }

  /// 請求相機權限
  static Future<bool> requestCamera(BuildContext context) async {
    final status = await Permission.camera.request();

    if (!status.isGranted && context.mounted) {
      await _showDeniedDialog(
        context,
        title: '相機權限不足',
        message: '需要相機權限才能使用影像心率測量功能。',
        showSettings: status.isPermanentlyDenied,
      );
    }

    return status.isGranted;
  }

  /// 檢查藍芽是否已被授權（不彈出請求）
  static Future<bool> checkBluetooth() async {
    final scan = await Permission.bluetoothScan.isGranted;
    final connect = await Permission.bluetoothConnect.isGranted;
    return scan && connect;
  }

  /// 檢查相機是否已被授權
  static Future<bool> checkCamera() async {
    return await Permission.camera.isGranted;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static String _permissionName(Permission p) {
    if (p == Permission.bluetoothScan) return '藍芽掃描';
    if (p == Permission.bluetoothConnect) return '藍芽連接';
    if (p == Permission.bluetooth) return '藍芽';
    if (p == Permission.location) return '位置（藍芽需要）';
    if (p == Permission.camera) return '相機';
    return p.toString();
  }

  static Future<void> _showDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool showSettings = false,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9F0A), size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          if (showSettings)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF)),
              child: const Text('前往設定'),
            ),
        ],
      ),
    );
  }
}
