// lib/screens/bluetooth_scan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../database/health_database.dart';
import '../models/health_record.dart';
import 'dart:async';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanAnim;
  StreamSubscription? _dataSubscription;
  BluetoothHealthData? _receivedData;
  bool _saving = false;
  String _statusText = '搜尋附近的健康裝置...';

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  void _startScan() {
    final ble = context.read<HealthBluetoothService>();
    _dataSubscription = ble.dataStream.listen(_onDataReceived);
    ble.startScan();
  }

  void _onDataReceived(BluetoothHealthData data) {
    setState(() {
      _receivedData = data;
      _statusText = '收到資料！';
    });
    _showSaveDialog(data);
  }

  Future<void> _showSaveDialog(BluetoothHealthData data) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SaveDialog(data: data),
    );
    if (confirmed == true) await _saveRecord(data);
  }

  Future<void> _saveRecord(BluetoothHealthData data) async {
    setState(() => _saving = true);
    final db = context.read<HealthDatabase>();
    final ble = context.read<HealthBluetoothService>();

    final record = HealthRecord(
      timestamp: data.timestamp,
      systolic: data.systolic,
      diastolic: data.diastolic,
      heartRate: data.heartRate,
      weight: data.weight,
      spo2: data.spo2,
      source: 'bluetooth',
      deviceName: ble.connectedDeviceName,
    );

    await db.insertRecord(record);
    if (ble.connectedDeviceName != null && ble.connectedDevice != null) {
      await db.savePairedDevice(
        deviceId: ble.connectedDevice!.remoteId.str,
        deviceName: ble.connectedDeviceName!,
        deviceType: data.deviceType,
      );
    }

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 已儲存到資料庫'),
          backgroundColor: Color(0xFF30D158),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _dataSubscription?.cancel();
    context.read<HealthBluetoothService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('藍芽健康裝置'),
        actions: [
          Consumer<HealthBluetoothService>(
            builder: (_, ble, __) {
              if (ble.state == BleConnectionState.connected) {
                return TextButton(
                  onPressed: ble.disconnect,
                  child: Text('中斷', style: GoogleFonts.notoSansTc(color: Colors.redAccent)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<HealthBluetoothService>(
        builder: (_, ble, __) {
          return Column(
            children: [
              _buildStatusBanner(ble),
              Expanded(child: _buildBody(ble)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(HealthBluetoothService ble) {
    Color color;
    String text;

    switch (ble.state) {
      case BleConnectionState.scanning:
        color = Theme.of(context).primaryColor;
        text = '掃標中...';
        break;
      case BleConnectionState.connecting:
        color = const Color(0xFFFF9F0A);
        text = '連線中...';
        break;
      case BleConnectionState.connected:
        color = const Color(0xFF30D158);
        text = '已連線：${ble.connectedDeviceName ?? "裝置"}';
        break;
      case BleConnectionState.error:
        color = const Color(0xFFFF453A);
        text = ble.errorMessage ?? '發生錯誤';
        break;
      default:
        color = Colors.white24;
        text = '尚未連線';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: color.withOpacity(0.15),
      child: Row(
        children: [
          if (ble.state == BleConnectionState.scanning || ble.state == BleConnectionState.connecting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(
              ble.state == BleConnectionState.connected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.notoSansTc(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBody(HealthBluetoothService ble) {
    if (ble.state == BleConnectionState.connected) {
      return _buildConnectedView(ble);
    }
    return _buildScanResults(ble);
  }

  Widget _buildScanResults(HealthBluetoothService ble) {
    if (ble.scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Radar animation
            AnimatedBuilder(
              animation: _scanAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Opacity(
                      opacity: ((1 - (_scanAnim.value + i / 3) % 1.0)).clamp(0.0, 0.5),
                      child: Container(
                        width: 80 + ((_scanAnim.value + i / 3) % 1.0) * 80,
                        height: 80 + ((_scanAnim.value + i / 3) % 1.0) * 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  const Icon(Icons.bluetooth_searching_rounded,
                      size: 40, color: Color(0xFF0A84FF)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('搜尋中...', style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              '請確認裝置電源已開啟\n並進入配對模式',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: ble.startScan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新搜尋'),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ble.scanResults.length,
      itemBuilder: (ctx, i) {
        final result = ble.scanResults[i];
        final deviceType = HealthBluetoothService.classifyDevice(
          result.device,
          result.advertisementData.serviceUuids,
        );
        return _DeviceListTile(
          result: result,
          deviceType: deviceType,
          onTap: () => ble.connectToDevice(result.device),
        );
      },
    );
  }

  Widget _buildConnectedView(HealthBluetoothService ble) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth_connected_rounded,
                  size: 40, color: Color(0xFF30D158)),
            ),
            const SizedBox(height: 20),
            Text(
              ble.connectedDeviceName ?? '已連線',
              style: GoogleFonts.notoSansTc(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              '等待裝置傳送測量數據...\n請在裝置上開始測量',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansTc(color: Colors.white54, fontSize: 14, height: 1.6),
            ),
            if (_saving) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Color(0xFF30D158)),
              const SizedBox(height: 8),
              Text('儲存中...', style: GoogleFonts.notoSansTc(color: Colors.white54)),
            ],
            if (_receivedData != null) ...[
              const SizedBox(height: 24),
              _buildReceivedDataPreview(_receivedData!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedDataPreview(BluetoothHealthData data) {
    final items = <String>[];
    if (data.systolic != null) items.add('血壓: ${data.systolic}/${data.diastolic} mmHg');
    if (data.heartRate != null) items.add('心率: ${data.heartRate} bpm');
    if (data.spo2 != null) items.add('血氧: ${data.spo2!.toStringAsFixed(1)}%');
    if (data.weight != null) items.add('體重: ${data.weight!.toStringAsFixed(1)} kg');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30D158).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(item, style: GoogleFonts.notoSansTc(color: Colors.white70, fontSize: 14)),
        )).toList(),
      ),
    );
  }
}

// ─── Device List Tile ────────────────────────────────────────────────────────

class _DeviceListTile extends StatelessWidget {
  final ScanResult result;
  final BleDeviceType deviceType;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.result,
    required this.deviceType,
    required this.onTap,
  });

  IconData get _icon {
    switch (deviceType) {
      case BleDeviceType.bloodPressure: return Icons.favorite_rounded;
      case BleDeviceType.heartRate: return Icons.monitor_heart_rounded;
      case BleDeviceType.weightScale: return Icons.monitor_weight_rounded;
      case BleDeviceType.pulseOximeter: return Icons.water_drop_rounded;
      default: return Icons.bluetooth_rounded;
    }
  }

  String get _typeLabel {
    switch (deviceType) {
      case BleDeviceType.bloodPressure: return '血壓計';
      case BleDeviceType.heartRate: return '心率監測';
      case BleDeviceType.weightScale: return '體重計';
      case BleDeviceType.pulseOximeter: return '血氧儀';
      default: return '未知裝置';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.isEmpty
        ? '未命名裝置'
        : result.device.platformName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF30B0C7).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon, color: const Color(0xFF30B0C7), size: 22),
        ),
        title: Text(name, style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(_typeLabel, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${result.rssi} dBm',
              style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ─── Save Dialog ─────────────────────────────────────────────────────────────

class _SaveDialog extends StatelessWidget {
  final BluetoothHealthData data;

  const _SaveDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('收到測量數據', style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.systolic != null)
            _DataRow('血壓', '${data.systolic}/${data.diastolic} mmHg'),
          if (data.heartRate != null)
            _DataRow('心率', '${data.heartRate} bpm'),
          if (data.spo2 != null)
            _DataRow('血氧', '${data.spo2!.toStringAsFixed(1)}%'),
          if (data.weight != null)
            _DataRow('體重', '${data.weight!.toStringAsFixed(2)} kg'),
          const SizedBox(height: 8),
          Text('是否儲存此筆記錄？',
              style: GoogleFonts.notoSansTc(color: Colors.white54, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('取消', style: GoogleFonts.notoSansTc(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          child: Text('儲存', style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface)),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSansTc(color: Colors.white54, fontSize: 13)),
          Text(value, style: GoogleFonts.notoSansTc(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
