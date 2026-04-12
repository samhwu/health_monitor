// lib/services/bluetooth_service.dart
//
// 支援的 BLE 標準 GATT Profile:
//   - Blood Pressure Monitor  (0x1810 / 0x2A35)
//   - Heart Rate Monitor      (0x180D / 0x2A37)
//   - Weight Scale            (0x181D / 0x2A9D)
//   - Pulse Oximeter          (0x1822 / 0x2A5F)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// ─── GATT UUIDs ──────────────────────────────────────────────────────────────

class GattUUIDs {
  // Services
  static const String heartRateService      = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String bloodPressureService  = '00001810-0000-1000-8000-00805f9b34fb';
  static const String weightScaleService    = '0000181d-0000-1000-8000-00805f9b34fb';
  static const String pulseOximeterService  = '00001822-0000-1000-8000-00805f9b34fb';
  static const String deviceInfoService     = '0000180a-0000-1000-8000-00805f9b34fb';

  // Characteristics
  static const String heartRateMeasurement    = '00002a37-0000-1000-8000-00805f9b34fb';
  static const String bloodPressureMeasure    = '00002a35-0000-1000-8000-00805f9b34fb';
  static const String intermediateCuffPressure= '00002a36-0000-1000-8000-00805f9b34fb';
  static const String weightMeasurement       = '00002a9d-0000-1000-8000-00805f9b34fb';
  static const String plxContinuousMeasure    = '00002a5f-0000-1000-8000-00805f9b34fb';
  static const String plxSpotCheckMeasure     = '00002a5e-0000-1000-8000-00805f9b34fb';

  // YUNMAI Custom UUIDs
  static const String yunmaiService           = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String yunmaiMeasurement       = '0000ffe4-0000-1000-8000-00805f9b34fb';
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class BluetoothHealthData {
  final int? systolic;
  final int? diastolic;
  final int? meanArterialPressure;
  final int? heartRate;
  final double? weight;
  final double? bmi;
  final double? spo2;
  final double? pulseRate;
  final String deviceType;
  final DateTime timestamp;

  const BluetoothHealthData({
    this.systolic,
    this.diastolic,
    this.meanArterialPressure,
    this.heartRate,
    this.weight,
    this.bmi,
    this.spo2,
    this.pulseRate,
    required this.deviceType,
    required this.timestamp,
  });
}

enum BleDeviceType { heartRate, bloodPressure, weightScale, pulseOximeter, unknown }
enum BleConnectionState { disconnected, scanning, connecting, connected, error }

// ─── Main Service ─────────────────────────────────────────────────────────────

class HealthBluetoothService extends ChangeNotifier {
  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice? _connectedDevice;
  String? _connectedDeviceName;
  String? _errorMessage;

  final _dataController = StreamController<BluetoothHealthData>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final List<ScanResult> _scanResults = [];
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription? _scanSubscription;

  BleConnectionState get state => _state;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get errorMessage => _errorMessage;
  Stream<BluetoothHealthData> get dataStream => _dataController.stream;
  Stream<List<ScanResult>> get scanResultsStream => _scanResultsController.stream;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  // ─── Scan ─────────────────────────────────────────────────────────────────

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == BleConnectionState.scanning) return;

    try {
      // 1. 檢查權限 (iOS/Android)
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
      }

      // 2. 等待藍牙硬體就緒 (修復 CBManagerStateUnknown)
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // 如果還在 Unknown，稍等一下再檢查
        if (adapterState == BluetoothAdapterState.unknown) {
           adapterState = await FlutterBluePlus.adapterState
              .map((s) { debugPrint('藍牙狀態變更: $s'); return s; })
              .firstWhere((s) => s != BluetoothAdapterState.unknown)
              .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
        }
        
        if (adapterState != BluetoothAdapterState.on) {
          throw '藍牙未開啟或權限不足 (狀態: $adapterState)';
        }
      }

      _scanResults.clear();
      _setState(BleConnectionState.scanning);

      // 3. 開始掃描 (移除 withServices 過濾，在 macOS 上全域掃描較穩定)
      await FlutterBluePlus.startScan(
        timeout: timeout,
      );

      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        // 在 macOS 上，有些裝置的名稱可能在 advertisementData 中
        final name = r.advertisementData.localName.isNotEmpty 
            ? r.advertisementData.localName 
            : r.device.platformName;
            
        debugPrint('發現裝置: $name [${r.device.remoteId}] UUIDs: ${r.advertisementData.serviceUuids}');

        // 檢查是否已在列表中
        bool isNew = !_scanResults.any((e) => e.device.remoteId == r.device.remoteId);
        
        if (isNew) {
          // 過濾邏輯：有名稱，或者是我們感興趣的健康 Service
          bool isHealthDevice = _checkIsHealthDevice(r);
          
          if (name.isNotEmpty || isHealthDevice) {
            _scanResults.add(r);
            notifyListeners();
          }
        }
      }
    });
    _subscriptions.add(_scanSubscription!); // Add the new subscription to the list

      // 超時後停止
      await Future.delayed(timeout);
      await stopScan();
    } catch (e) {
      _setError('掃描失敗: $e');
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (_state == BleConnectionState.scanning) {
      _setState(BleConnectionState.disconnected);
    }
  }

  // ─── Connect ──────────────────────────────────────────────────────────────

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _setState(BleConnectionState.connecting);
      await stopScan();

      // TODO: 由於自定義 SDK 需要 license 參數，暫時註解掉連線功能
      // await device.connect(timeout: const Duration(seconds: 10));
      debugPrint('Bluetooth connection is temporarily disabled.');
      _connectedDevice = device;
      _connectedDeviceName = device.platformName;
      _setState(BleConnectionState.connected);

      // 監聽連線狀態
      final connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectedDeviceName = null;
          _setState(BleConnectionState.disconnected);
        }
      });
      _subscriptions.add(connSub);

      await _discoverAndSubscribe(device);
    } catch (e) {
      _setError('連線失敗: $e');
    }
  }

  Future<void> disconnect() async {
    _connectedDevice?.disconnect();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _connectedDevice = null;
    _connectedDeviceName = null;
    _setState(BleConnectionState.disconnected);
  }

  // ─── GATT Discovery & Subscribe ──────────────────────────────────────────

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      final uuid = service.serviceUuid.toString().toLowerCase();

      if (uuid.contains('180d')) {
        await _subscribeHeartRate(service);
      } else if (uuid.contains('1810')) {
        await _subscribeBloodPressure(service);
      } else if (uuid.contains('181d') || uuid.contains('181b')) {
        await _subscribeWeightScale(service);
      } else if (uuid.contains('ffe0')) {
        await _subscribeYunmaiScale(service);
      } else if (uuid.contains('1822')) {
        await _subscribePulseOximeter(service);
      }
    }
  }

  // ─── Heart Rate (0x180D) ─────────────────────────────────────────────────

  Future<void> _subscribeHeartRate(BluetoothService service) async {
    for (final char in service.characteristics) {
      if (!char.uuid.toString().contains('2a37')) continue;
      if (!char.properties.notify) continue;

      await char.setNotifyValue(true);
      final sub = char.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        final hr = _parseHeartRate(data);
        if (hr == null) return;
        _dataController.add(BluetoothHealthData(
          heartRate: hr,
          deviceType: 'heart_rate',
          timestamp: DateTime.now(),
        ));
      });
      _subscriptions.add(sub);
      break;
    }
  }

  /// Heart Rate Measurement characteristic format (Bluetooth spec):
  /// Byte 0: Flags
  ///   bit0=0 → HR in uint8 (byte 1)
  ///   bit0=1 → HR in uint16 (bytes 1-2)
  int? _parseHeartRate(List<int> data) {
    if (data.isEmpty) return null;
    final flags = data[0];
    if (flags & 0x01 == 0) {
      return data.length > 1 ? data[1] : null;
    } else {
      return data.length > 2
          ? ByteData.sublistView(Uint8List.fromList(data), 1, 3).getUint16(0, Endian.little)
          : null;
    }
  }

  // ─── Blood Pressure (0x1810) ─────────────────────────────────────────────

  Future<void> _subscribeBloodPressure(BluetoothService service) async {
    for (final char in service.characteristics) {
      final uuid = char.uuid.toString();
      if (!uuid.contains('2a35') && !uuid.contains('2a36')) continue;
      if (!char.properties.indicate && !char.properties.notify) continue;

      await char.setNotifyValue(true);
      final sub = char.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        final result = _parseBloodPressure(data);
        if (result == null) return;
        _dataController.add(BluetoothHealthData(
          systolic: result['systolic'],
          diastolic: result['diastolic'],
          meanArterialPressure: result['map'],
          heartRate: result['hr'],
          deviceType: 'blood_pressure',
          timestamp: DateTime.now(),
        ));
      });
      _subscriptions.add(sub);
    }
  }

  /// Blood Pressure Measurement format:
  /// Byte 0: Flags
  /// Bytes 1-2: Systolic (SFLOAT)
  /// Bytes 3-4: Diastolic (SFLOAT)
  /// Bytes 5-6: MAP (SFLOAT)
  /// Optional bytes 7-8: HR (SFLOAT) if flags bit2=1
  Map<String, int>? _parseBloodPressure(List<int> data) {
    if (data.length < 7) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(data));
    final flags = data[0];
    final bool mmHg = (flags & 0x01) == 0;

    double sfloat(int offset) {
      final raw = bd.getUint16(offset, Endian.little);
      final mantissa = (raw & 0x0FFF).toSigned(12);
      final exponent = (raw >> 12).toSigned(4);
      return mantissa * _pow10(exponent);
    }

    final systolic = sfloat(1).round();
    final diastolic = sfloat(3).round();
    final map = sfloat(5).round();
    int? hr;
    if ((flags & 0x04) != 0 && data.length >= 9) {
      hr = sfloat(7).round();
    }

    if (!mmHg) return null; // kPa 暫不支援
    return {'systolic': systolic, 'diastolic': diastolic, 'map': map, if (hr != null) 'hr': hr};
  }

  double _pow10(int exp) {
    if (exp == 0) return 1.0;
    double result = 1.0;
    for (int i = 0; i < exp.abs(); i++) {
      result *= 10.0;
    }
    return exp > 0 ? result : 1.0 / result;
  }

  // ─── Weight Scale (0x181D) ───────────────────────────────────────────────

  Future<void> _subscribeWeightScale(BluetoothService service) async {
    for (final char in service.characteristics) {
      if (!char.uuid.toString().contains('2a9d')) continue;
      if (!char.properties.indicate && !char.properties.notify) continue;

      await char.setNotifyValue(true);
      final sub = char.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        final result = _parseWeightMeasurement(data);
        if (result == null) return;
        _dataController.add(BluetoothHealthData(
          weight: result['weight'],
          bmi: result['bmi'],
          deviceType: 'weight_scale',
          timestamp: DateTime.now(),
        ));
      });
      _subscriptions.add(sub);
      break;
    }
  }

  /// Weight Measurement format:
  /// Byte 0: Flags (bit0=0 → SI unit kg)
  /// Bytes 1-2: Weight (uint16, resolution 0.005 kg for SI)
  /// Optional: BMI, height
  Map<String, double>? _parseWeightMeasurement(List<int> data) {
    if (data.length < 3) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(data));
    final flags = data[0];
    final isSI = (flags & 0x01) == 0;
    final rawWeight = bd.getUint16(1, Endian.little);
    final weight = isSI ? rawWeight * 0.005 : rawWeight * 0.01 * 0.453592;

    double? bmi;
    if ((flags & 0x02) != 0 && data.length >= 7) {
      final rawBmi = bd.getUint16(5, Endian.little);
      bmi = rawBmi * 0.1;
    }

    return {'weight': weight, if (bmi != null) 'bmi': bmi};
  }

  // ─── YUNMAI Scale (0xFFE0) ───────────────────────────────────────────────

  Future<void> _subscribeYunmaiScale(BluetoothService service) async {
    for (final char in service.characteristics) {
      final uuid = char.uuid.toString().toLowerCase();
      if (!uuid.contains('ffe4')) continue;
      if (!char.properties.notify && !char.properties.indicate) continue;

      await char.setNotifyValue(true);
      final sub = char.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        debugPrint('YUNMAI 原始數據: $data');
        final result = _parseYunmaiWeight(data);
        if (result == null) return;
        _dataController.add(BluetoothHealthData(
          weight: result['weight'],
          bmi: result['bmi'],
          deviceType: 'weight_scale',
          timestamp: DateTime.now(),
        ));
      });
      _subscriptions.add(sub);
      break;
    }
  }

  Map<String, double>? _parseYunmaiWeight(List<int> data) {
    // YUNMAI 穩定數據格式 (通常長度 20，以 0x01 開頭)
    if (data.length >= 15 && data[0] == 0x01) {
      final rawWeight = (data[13] << 8) | data[14];
      return {'weight': rawWeight / 100.0};
    } 
    // YUNMAI 即時數據格式 (以 0x02 或 0x0d 開頭，長度較短或相等)
    else if (data.length >= 10 && (data[0] == 0x02 || data[0] == 0x0d)) {
      final rawWeight = (data[8] << 8) | data[9];
      return {'weight': rawWeight / 100.0};
    }
    return null;
  }

  // ─── Pulse Oximeter (0x1822) ─────────────────────────────────────────────

  Future<void> _subscribePulseOximeter(BluetoothService service) async {
    for (final char in service.characteristics) {
      if (!char.uuid.toString().contains('2a5f') && !char.uuid.toString().contains('2a5e')) continue;
      if (!char.properties.notify && !char.properties.indicate) continue;

      await char.setNotifyValue(true);
      final sub = char.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        final result = _parsePulseOximeter(data);
        if (result == null) return;
        _dataController.add(BluetoothHealthData(
          spo2: result['spo2'],
          pulseRate: result['pulse_rate'],
          heartRate: result['pulse_rate']?.round(),
          deviceType: 'pulse_oximeter',
          timestamp: DateTime.now(),
        ));
      });
      _subscriptions.add(sub);
      break;
    }
  }

  /// PLX Continuous Measurement format:
  /// Byte 0-1: Flags
  /// Bytes 2-3: SpO2 (SFLOAT, %)
  /// Bytes 4-5: Pulse Rate (SFLOAT, bpm)
  Map<String, double>? _parsePulseOximeter(List<int> data) {
    if (data.length < 6) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(data));

    double sfloat(int offset) {
      final raw = bd.getUint16(offset, Endian.little);
      final mantissa = (raw & 0x0FFF).toSigned(12);
      final exponent = (raw >> 12).toSigned(4);
      return mantissa * _pow10(exponent);
    }

    final spo2 = sfloat(2);
    final pulseRate = sfloat(4);

    if (spo2 < 50 || spo2 > 100) return null;
    return {'spo2': spo2, 'pulse_rate': pulseRate};
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static BleDeviceType classifyDevice(BluetoothDevice device, List<Guid> serviceUUIDs) {
    final uuids = serviceUUIDs.map((g) => g.toString().toLowerCase()).toList();
    if (uuids.any((u) => u.contains('1810'))) return BleDeviceType.bloodPressure;
    if (uuids.any((u) => u.contains('180d'))) return BleDeviceType.heartRate;
    if (uuids.any((u) => u.contains('181d') || u.contains('181b'))) return BleDeviceType.weightScale;
    if (uuids.any((u) => u.contains('1822'))) return BleDeviceType.pulseOximeter;
    return BleDeviceType.unknown;
  }

  void _setState(BleConnectionState state) {
    _state = state;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = BleConnectionState.error;
    notifyListeners();
  }

  bool _checkIsHealthDevice(ScanResult r) {
    final targetUuids = [
      Guid(GattUUIDs.heartRateService),
      Guid(GattUUIDs.bloodPressureService),
      Guid(GattUUIDs.weightScaleService),
      Guid(GattUUIDs.yunmaiService),
      Guid(GattUUIDs.pulseOximeterService),
    ];
    return r.advertisementData.serviceUuids.any((uuid) => targetUuids.contains(uuid));
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _dataController.close();
    _scanResultsController.close();
    super.dispose();
  }
}
