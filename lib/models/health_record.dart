// lib/models/health_record.dart

class HealthRecord {
  final int? id;
  final DateTime timestamp;
  final int? systolic;      // 收縮壓 mmHg
  final int? diastolic;     // 舒張壓 mmHg
  final int? heartRate;     // 心率 bpm
  final double? weight;     // 體重 kg
  final double? spo2;       // 血氧 %
  final String source;      // 'bluetooth' | 'camera' | 'manual'
  final String? deviceName;
  final String? notes;

  HealthRecord({
    this.id,
    required this.timestamp,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.weight,
    this.spo2,
    this.source = 'bluetooth',
    this.deviceName,
    this.notes,
  });

  // 血壓狀態評估
  BloodPressureStatus get bpStatus {
    if (systolic == null || diastolic == null) return BloodPressureStatus.unknown;
    if (systolic! < 120 && diastolic! < 80) return BloodPressureStatus.normal;
    if (systolic! < 130 && diastolic! < 80) return BloodPressureStatus.elevated;
    if (systolic! < 140 || diastolic! < 90) return BloodPressureStatus.highStage1;
    return BloodPressureStatus.highStage2;
  }

  // 心率狀態
  HeartRateStatus get hrStatus {
    if (heartRate == null) return HeartRateStatus.unknown;
    if (heartRate! < 60) return HeartRateStatus.low;
    if (heartRate! <= 100) return HeartRateStatus.normal;
    return HeartRateStatus.high;
  }

  // 血氧狀態
  SpO2Status get spo2Status {
    if (spo2 == null) return SpO2Status.unknown;
    if (spo2! >= 95) return SpO2Status.normal;
    if (spo2! >= 90) return SpO2Status.low;
    return SpO2Status.critical;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'systolic': systolic,
      'diastolic': diastolic,
      'heart_rate': heartRate,
      'weight': weight,
      'spo2': spo2,
      'source': source,
      'device_name': deviceName,
      'notes': notes,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      systolic: map['systolic'],
      diastolic: map['diastolic'],
      heartRate: map['heart_rate'],
      weight: map['weight']?.toDouble(),
      spo2: map['spo2']?.toDouble(),
      source: map['source'] ?? 'bluetooth',
      deviceName: map['device_name'],
      notes: map['notes'],
    );
  }

  HealthRecord copyWith({
    int? id,
    DateTime? timestamp,
    int? systolic,
    int? diastolic,
    int? heartRate,
    double? weight,
    double? spo2,
    String? source,
    String? deviceName,
    String? notes,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      heartRate: heartRate ?? this.heartRate,
      weight: weight ?? this.weight,
      spo2: spo2 ?? this.spo2,
      source: source ?? this.source,
      deviceName: deviceName ?? this.deviceName,
      notes: notes ?? this.notes,
    );
  }
}

enum BloodPressureStatus { normal, elevated, highStage1, highStage2, unknown }
enum HeartRateStatus { low, normal, high, unknown }
enum SpO2Status { normal, low, critical, unknown }

extension BloodPressureStatusExtension on BloodPressureStatus {
  String get label {
    switch (this) {
      case BloodPressureStatus.normal: return '正常';
      case BloodPressureStatus.elevated: return '偏高';
      case BloodPressureStatus.highStage1: return '高血壓一期';
      case BloodPressureStatus.highStage2: return '高血壓二期';
      case BloodPressureStatus.unknown: return '未知';
    }
  }
}
