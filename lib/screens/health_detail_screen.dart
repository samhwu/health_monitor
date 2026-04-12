// lib/screens/health_detail_screen.dart
//
// 深入分析單一健康指標：趨勢圖、風險評估、AI 建議

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/health_record.dart';
import '../providers/health_provider.dart';
import '../utils/health_evaluator.dart';

enum HealthMetric { bloodPressure, heartRate, spo2, weight }

class HealthDetailScreen extends StatefulWidget {
  final HealthMetric metric;

  const HealthDetailScreen({super.key, required this.metric});

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  int _rangeDays = 30;

  String get _title {
    switch (widget.metric) {
      case HealthMetric.bloodPressure: return '血壓分析';
      case HealthMetric.heartRate: return '心率分析';
      case HealthMetric.spo2: return '血氧分析';
      case HealthMetric.weight: return '體重分析';
    }
  }

  Color get _color {
    switch (widget.metric) {
      case HealthMetric.bloodPressure: return const Color(0xFFFF453A);
      case HealthMetric.heartRate: return const Color(0xFFFF2D55);
      case HealthMetric.spo2: return const Color(0xFF0A84FF);
      case HealthMetric.weight: return const Color(0xFF30D158);
    }
  }

  IconData get _icon {
    switch (widget.metric) {
      case HealthMetric.bloodPressure: return Icons.favorite_rounded;
      case HealthMetric.heartRate: return Icons.monitor_heart_rounded;
      case HealthMetric.spo2: return Icons.water_drop_rounded;
      case HealthMetric.weight: return Icons.monitor_weight_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          PopupMenuButton<int>(
            color: const Color(0xFF1C1C1E),
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            onSelected: (v) => setState(() => _rangeDays = v),
            itemBuilder: (_) => [
              _menuItem(7, '最近 7 天'),
              _menuItem(30, '最近 30 天'),
              _menuItem(90, '最近 3 個月'),
              _menuItem(365, '最近一年'),
            ],
          ),
        ],
      ),
      body: Consumer<HealthProvider>(
        builder: (_, provider, __) {
          final cutoff = DateTime.now().subtract(Duration(days: _rangeDays));
          final records = provider.records.where((r) => r.timestamp.isAfter(cutoff)).toList();
          final filtered = _filterByMetric(records);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHeader(filtered),
                const SizedBox(height: 16),
                _buildChart(filtered),
                const SizedBox(height: 20),
                _buildRiskSection(filtered, provider.profile?.age),
                const SizedBox(height: 20),
                _buildTrendSection(filtered),
                const SizedBox(height: 20),
                _buildRecordList(filtered),
              ],
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<int> _menuItem(int val, String label) {
    return PopupMenuItem<int>(
      value: val,
      child: Text(label, style: GoogleFonts.notoSansTc(color: Colors.white70, fontSize: 13)),
    );
  }

  List<HealthRecord> _filterByMetric(List<HealthRecord> records) {
    switch (widget.metric) {
      case HealthMetric.bloodPressure: return records.where((r) => r.systolic != null).toList();
      case HealthMetric.heartRate: return records.where((r) => r.heartRate != null).toList();
      case HealthMetric.spo2: return records.where((r) => r.spo2 != null).toList();
      case HealthMetric.weight: return records.where((r) => r.weight != null).toList();
    }
  }

  double _getValue(HealthRecord r) {
    switch (widget.metric) {
      case HealthMetric.bloodPressure: return r.systolic!.toDouble();
      case HealthMetric.heartRate: return r.heartRate!.toDouble();
      case HealthMetric.spo2: return r.spo2!;
      case HealthMetric.weight: return r.weight!;
    }
  }

  // ─── Summary Header ───────────────────────────────────────────────────────

  Widget _buildSummaryHeader(List<HealthRecord> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('此時間範圍無資料', style: GoogleFonts.notoSansTc(color: Colors.white38)),
        ),
      );
    }

    final values = records.map(_getValue).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.25), const Color(0xFF1C1C1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(_icon, color: _color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${records.length} 筆 · $_rangeDays 天', style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11)),
                Text(
                  widget.metric == HealthMetric.bloodPressure
                      ? '${avg.toStringAsFixed(0)} mmHg 均值'
                      : _formatValue(avg),
                  style: GoogleFonts.notoSansTc(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MinMaxChip('最高', maxV, _color),
              const SizedBox(height: 4),
              _MinMaxChip('最低', minV, Colors.white38),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    switch (widget.metric) {
      case HealthMetric.bloodPressure: return '${v.toStringAsFixed(0)} mmHg';
      case HealthMetric.heartRate: return '${v.toStringAsFixed(0)} bpm';
      case HealthMetric.spo2: return '${v.toStringAsFixed(1)}%';
      case HealthMetric.weight: return '${v.toStringAsFixed(1)} kg';
    }
  }

  // ─── Chart ────────────────────────────────────────────────────────────────

  Widget _buildChart(List<HealthRecord> records) {
    if (records.isEmpty) return const SizedBox.shrink();

    final sorted = records.reversed.toList();
    final spots = <FlSpot>[];
    final spots2 = <FlSpot>[]; // diastolic for BP

    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), _getValue(sorted[i])));
      if (widget.metric == HealthMetric.bloodPressure) {
        spots2.add(FlSpot(i.toDouble(), sorted[i].diastolic!.toDouble()));
      }
    }

    final allVals = spots.map((s) => s.y).toList();
    if (spots2.isNotEmpty) allVals.addAll(spots2.map((s) => s.y));
    final minY = (allVals.reduce((a, b) => a < b ? a : b) - 5).floorToDouble();
    final maxY = (allVals.reduce((a, b) => a > b ? a : b) + 5).ceilToDouble();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: GoogleFonts.notoSansTc(color: Colors.white24, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (sorted.length / 5).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= sorted.length) return const SizedBox();
                  return Text(
                    DateFormat('M/d').format(sorted[idx].timestamp),
                    style: GoogleFonts.notoSansTc(color: Colors.white24, fontSize: 9),
                  );
                },
                reservedSize: 20,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _color,
              barWidth: 2.5,
              dotData: FlDotData(show: spots.length <= 15),
              belowBarData: BarAreaData(show: true, color: _color.withOpacity(0.08)),
            ),
            if (spots2.isNotEmpty)
              LineChartBarData(
                spots: spots2,
                isCurved: true,
                color: const Color(0xFFFF9F0A),
                barWidth: 2,
                dotData: const FlDotData(show: false),
                dashArray: [4, 3],
              ),
          ],
          // Reference lines
          extraLinesData: _buildReferenceLines(),
        ),
      ),
    );
  }

  ExtraLinesData _buildReferenceLines() {
    switch (widget.metric) {
      case HealthMetric.bloodPressure:
        return ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 120, color: const Color(0xFF30D158).withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4],
              label: HorizontalLineLabel(show: true, labelResolver: (_) => '正常上限',
                  style: const TextStyle(color: Color(0xFF30D158), fontSize: 8))),
          HorizontalLine(y: 140, color: const Color(0xFFFF9F0A).withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
        ]);
      case HealthMetric.heartRate:
        return ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 60, color: const Color(0xFF0A84FF).withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
          HorizontalLine(y: 100, color: const Color(0xFF0A84FF).withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
        ]);
      case HealthMetric.spo2:
        return ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 95, color: const Color(0xFF30D158).withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
          HorizontalLine(y: 90, color: const Color(0xFFFF453A).withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
        ]);
      default:
        return const ExtraLinesData();
    }
  }

  // ─── Risk ─────────────────────────────────────────────────────────────────

  Widget _buildRiskSection(List<HealthRecord> records, int? age) {
    if (records.isEmpty) return const SizedBox.shrink();
    final latest = records.first;
    MetricEvaluation? eval;

    switch (widget.metric) {
      case HealthMetric.bloodPressure:
        if (latest.systolic != null) eval = HealthEvaluator.evaluateBP(latest.systolic!, latest.diastolic!);
        break;
      case HealthMetric.heartRate:
        if (latest.heartRate != null) eval = HealthEvaluator.evaluateHR(latest.heartRate!, ageYears: age);
        break;
      case HealthMetric.spo2:
        if (latest.spo2 != null) eval = HealthEvaluator.evaluateSpO2(latest.spo2!);
        break;
      case HealthMetric.weight:
        return const SizedBox.shrink();
    }

    if (eval == null) return const SizedBox.shrink();

    final riskColors = {
      RiskLevel.good: const Color(0xFF30D158),
      RiskLevel.caution: const Color(0xFFFF9F0A),
      RiskLevel.warning: const Color(0xFFFF6B35),
      RiskLevel.critical: const Color(0xFFFF453A),
    };
    final c = riskColors[eval.risk]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(eval.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(eval.label, style: GoogleFonts.notoSansTc(color: c, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(eval.description, style: GoogleFonts.notoSansTc(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(child: Text(eval.advice, style: GoogleFonts.notoSansTc(color: Colors.white54, fontSize: 12))),
          ]),
        ],
      ),
    );
  }

  // ─── Trend ────────────────────────────────────────────────────────────────

  Widget _buildTrendSection(List<HealthRecord> records) {
    if (records.length < 3) return const SizedBox.shrink();
    final vals = records.map(_getValue).toList();
    final trend = HealthEvaluator.analyzeTrend(vals);

    final trendColor = widget.metric == HealthMetric.weight || widget.metric == HealthMetric.bloodPressure
        ? (trend == TrendResult.falling ? const Color(0xFF30D158) : trend == TrendResult.rising ? const Color(0xFFFF453A) : Colors.white54)
        : (trend == TrendResult.stable ? const Color(0xFF30D158) : Colors.white54);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(trend.icon, style: TextStyle(fontSize: 20, color: trendColor)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('近期趨勢', style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11)),
              Text(trend.label, style: GoogleFonts.notoSansTc(color: trendColor, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Record List ──────────────────────────────────────────────────────────

  Widget _buildRecordList(List<HealthRecord> records) {
    if (records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('詳細記錄', style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...records.take(50).map((r) => _RecordRow(r, widget.metric)),
      ],
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _MinMaxChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MinMaxChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 10)),
        const SizedBox(width: 4),
        Text(value.toStringAsFixed(0), style: GoogleFonts.notoSansTc(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final HealthRecord record;
  final HealthMetric metric;
  const _RecordRow(this.record, this.metric);

  String _val() {
    switch (metric) {
      case HealthMetric.bloodPressure: return '${record.systolic}/${record.diastolic} mmHg';
      case HealthMetric.heartRate: return '${record.heartRate} bpm';
      case HealthMetric.spo2: return '${record.spo2!.toStringAsFixed(1)}%';
      case HealthMetric.weight: return '${record.weight!.toStringAsFixed(1)} kg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(fmt.format(record.timestamp), style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          Text(_val(), style: GoogleFonts.notoSansTc(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
