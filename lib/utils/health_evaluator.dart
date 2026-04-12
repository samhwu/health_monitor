// lib/utils/health_evaluator.dart
//
// 根據 WHO / ACC/AHA 2017 指引，對各健康指標做風險評估，
// 並產生個人化建議文字。

import '../models/health_record.dart';

// ─── Risk Level ───────────────────────────────────────────────────────────────

enum RiskLevel { good, caution, warning, critical }

class MetricEvaluation {
  final RiskLevel risk;
  final String label;
  final String description;
  final String advice;
  final String emoji;

  const MetricEvaluation({
    required this.risk,
    required this.label,
    required this.description,
    required this.advice,
    required this.emoji,
  });
}

// ─── Evaluator ────────────────────────────────────────────────────────────────

class HealthEvaluator {
  // ─── Blood Pressure ───────────────────────────────────────────────────────

  static MetricEvaluation evaluateBP(int systolic, int diastolic) {
    if (systolic < 90 || diastolic < 60) {
      return const MetricEvaluation(
        risk: RiskLevel.warning,
        label: '血壓偏低',
        description: '低血壓可能導致頭暈或昏厥',
        advice: '請補充水分，如持續建議就醫',
        emoji: '💙',
      );
    }
    if (systolic < 120 && diastolic < 80) {
      return const MetricEvaluation(
        risk: RiskLevel.good,
        label: '血壓正常',
        description: '收縮壓 < 120、舒張壓 < 80 mmHg',
        advice: '繼續保持健康生活習慣',
        emoji: '💚',
      );
    }
    if (systolic < 130 && diastolic < 80) {
      return const MetricEvaluation(
        risk: RiskLevel.caution,
        label: '血壓偏高前期',
        description: '收縮壓 120–129 mmHg',
        advice: '減少鹽分攝取，增加有氧運動',
        emoji: '🟡',
      );
    }
    if (systolic < 140 || diastolic < 90) {
      return const MetricEvaluation(
        risk: RiskLevel.warning,
        label: '高血壓一期',
        description: '收縮壓 130–139 或舒張壓 80–89 mmHg',
        advice: '建議改變生活方式，定期追蹤，必要時就醫',
        emoji: '🟠',
      );
    }
    if (systolic < 180 && diastolic < 120) {
      return const MetricEvaluation(
        risk: RiskLevel.critical,
        label: '高血壓二期',
        description: '收縮壓 ≥ 140 或舒張壓 ≥ 90 mmHg',
        advice: '強烈建議就醫評估，可能需要藥物治療',
        emoji: '🔴',
      );
    }
    return const MetricEvaluation(
      risk: RiskLevel.critical,
      label: '高血壓危象',
      description: '收縮壓 ≥ 180 或舒張壓 ≥ 120 mmHg',
      advice: '請立即就醫！',
      emoji: '🚨',
    );
  }

  // ─── Heart Rate ───────────────────────────────────────────────────────────

  static MetricEvaluation evaluateHR(int hr, {int? ageYears}) {
    final hrMax = ageYears != null ? 220 - ageYears : 200;

    if (hr < 40) {
      return const MetricEvaluation(
        risk: RiskLevel.critical,
        label: '嚴重心跳過緩',
        description: '心率 < 40 bpm，可能有心律不整',
        advice: '請立即就醫！',
        emoji: '🚨',
      );
    }
    if (hr < 60) {
      return MetricEvaluation(
        risk: RiskLevel.caution,
        label: '心跳偏慢',
        description: '心率 $hr bpm，靜態時略低',
        advice: '若無症狀且為運動員可屬正常，否則建議追蹤',
        emoji: '💙',
      );
    }
    if (hr <= 100) {
      return MetricEvaluation(
        risk: RiskLevel.good,
        label: '心率正常',
        description: '心率 $hr bpm（正常範圍：60–100）',
        advice: '繼續維持健康的生活型態',
        emoji: '💚',
      );
    }
    if (hr <= 120) {
      return MetricEvaluation(
        risk: RiskLevel.caution,
        label: '心跳略快',
        description: '心率 $hr bpm，偏高',
        advice: '確認是否因運動或壓力引起，若安靜時仍高請追蹤',
        emoji: '🟡',
      );
    }
    return MetricEvaluation(
      risk: RiskLevel.warning,
      label: '心跳過速',
      description: '心率 $hr bpm（> 120 bpm 安靜狀態）',
      advice: '建議就醫排除心律問題',
      emoji: '🟠',
    );
  }

  // ─── SpO2 ────────────────────────────────────────────────────────────────

  static MetricEvaluation evaluateSpO2(double spo2) {
    if (spo2 >= 95) {
      return MetricEvaluation(
        risk: RiskLevel.good,
        label: '血氧正常',
        description: 'SpO₂ ${spo2.toStringAsFixed(1)}%（正常 ≥ 95%）',
        advice: '血氧飽和度良好',
        emoji: '💚',
      );
    }
    if (spo2 >= 90) {
      return MetricEvaluation(
        risk: RiskLevel.warning,
        label: '血氧偏低',
        description: 'SpO₂ ${spo2.toStringAsFixed(1)}%（輕度低氧）',
        advice: '請保持深呼吸，並到通風處，若未改善請就醫',
        emoji: '🟠',
      );
    }
    return MetricEvaluation(
      risk: RiskLevel.critical,
      label: '血氧危險',
      description: 'SpO₂ ${spo2.toStringAsFixed(1)}%（嚴重低氧血症）',
      advice: '請立即就醫或撥打急救電話！',
      emoji: '🚨',
    );
  }

  // ─── BMI ─────────────────────────────────────────────────────────────────

  static MetricEvaluation evaluateBMI(double bmi) {
    if (bmi < 18.5) {
      return MetricEvaluation(
        risk: RiskLevel.caution,
        label: '體重過輕',
        description: 'BMI ${bmi.toStringAsFixed(1)}（< 18.5）',
        advice: '適當增加均衡飲食，必要時諮詢營養師',
        emoji: '💙',
      );
    }
    if (bmi < 24.0) {
      return MetricEvaluation(
        risk: RiskLevel.good,
        label: '體重正常',
        description: 'BMI ${bmi.toStringAsFixed(1)}（18.5–23.9）',
        advice: '保持良好飲食與規律運動',
        emoji: '💚',
      );
    }
    if (bmi < 27.0) {
      return MetricEvaluation(
        risk: RiskLevel.caution,
        label: '體重過重',
        description: 'BMI ${bmi.toStringAsFixed(1)}（24.0–26.9）',
        advice: '建議控制飲食，每週運動 150 分鐘以上',
        emoji: '🟡',
      );
    }
    if (bmi < 30.0) {
      return MetricEvaluation(
        risk: RiskLevel.warning,
        label: '輕度肥胖',
        description: 'BMI ${bmi.toStringAsFixed(1)}（27.0–29.9）',
        advice: '建議諮詢醫師或營養師制定減重計畫',
        emoji: '🟠',
      );
    }
    return MetricEvaluation(
      risk: RiskLevel.critical,
      label: '中重度肥胖',
      description: 'BMI ${bmi.toStringAsFixed(1)}（≥ 30）',
      advice: '請就醫評估，肥胖症可能需要醫療介入',
      emoji: '🔴',
    );
  }

  // ─── Trend Analysis ───────────────────────────────────────────────────────

  /// 分析近期趨勢（上升/下降/穩定）
  static TrendResult analyzeTrend(List<double> values, {int window = 7}) {
    if (values.length < 3) return TrendResult.stable;
    final recent = values.take(window).toList();
    final n = recent.length.toDouble();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < recent.length; i++) {
      sumX += i; sumY += recent[i];
      sumXY += i * recent[i]; sumX2 += i * i.toDouble();
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    if (slope > 0.5) return TrendResult.rising;
    if (slope < -0.5) return TrendResult.falling;
    return TrendResult.stable;
  }

  /// 評估一筆完整記錄，回傳所有適用的評估
  static List<MetricEvaluation> evaluateRecord(HealthRecord r, {int? age}) {
    final result = <MetricEvaluation>[];
    if (r.systolic != null && r.diastolic != null) {
      result.add(evaluateBP(r.systolic!, r.diastolic!));
    }
    if (r.heartRate != null) {
      result.add(evaluateHR(r.heartRate!, ageYears: age));
    }
    if (r.spo2 != null) {
      result.add(evaluateSpO2(r.spo2!));
    }
    return result;
  }
}

enum TrendResult { rising, falling, stable }

extension TrendResultExtension on TrendResult {
  String get label {
    switch (this) {
      case TrendResult.rising: return '上升趨勢';
      case TrendResult.falling: return '下降趨勢';
      case TrendResult.stable: return '維持穩定';
    }
  }

  String get icon {
    switch (this) {
      case TrendResult.rising: return '↑';
      case TrendResult.falling: return '↓';
      case TrendResult.stable: return '→';
    }
  }
}
