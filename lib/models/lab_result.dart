import 'dart:math';
import 'package:flutter/material.dart';

class LabRecord {
  final DateTime date;
  final double value;

  LabRecord({required this.date, required this.value});
}

class LabResult {
  final String name;
  final double value;
  final String unit;
  final List<LabRecord> records; // 包含日期與數值
  final double minNormal;
  final double maxNormal;
  final String status; // 'normal', 'high', 'low'
  final String category;

  LabResult({
    required this.name,
    required this.value,
    required this.unit,
    required this.records,
    required this.minNormal,
    required this.maxNormal,
    required this.category,
  }) : status = _calculateStatus(value, minNormal, maxNormal);

  List<double> get history => records.map((r) => r.value).toList();

  LabRecord? get highestRecord {
    if (records.isEmpty) return null;
    return records.reduce((a, b) => a.value > b.value ? a : b);
  }

  LabRecord? get lowestRecord {
    if (records.isEmpty) return null;
    return records.reduce((a, b) => a.value < b.value ? a : b);
  }

  double get standardDeviation {
    if (records.isEmpty) return 0.0;
    final values = records.map((r) => r.value).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  static String _calculateStatus(double val, double min, double max) {
    if (val < min) return 'low';
    if (val > max) return 'high';
    return 'normal';
  }

  Color get statusColor {
    switch (status) {
      case 'high':
      case 'low':
        return const Color(0xFFFF453A); // iOS Red
      default:
        return const Color(0xFF30D158); // iOS Green
    }
  }

  String get statusLabel {
    switch (status) {
      case 'high': return '偏高';
      case 'low': return '偏低';
      default: return '正常';
    }
  }
}
