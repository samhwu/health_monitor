// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/health_database.dart';
import '../models/health_record.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  List<HealthRecord> _records = [];
  bool _loading = true;
  late TabController _tabController;
  String _activeMetric = 'bp'; // bp, hr, spo2, weight

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final db = context.read<HealthDatabase>();
    final records = await db.getAllRecords(limit: 200);
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _deleteRecord(HealthRecord record) async {
    final db = context.read<HealthDatabase>();
    await db.deleteRecord(record.id!);
    await _loadRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('記錄已刪除')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歷史記錄'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Theme.of(context).disabledColor,
          tabs: [
            Tab(child: Text('圖表', style: GoogleFonts.notoSansTc())),
            Tab(child: Text('清單', style: GoogleFonts.notoSansTc())),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChartTab(),
                _buildListTab(),
              ],
            ),
    );
  }

  // ─── Chart Tab ────────────────────────────────────────────────────────────

  Widget _buildChartTab() {
    if (_records.isEmpty) return _buildEmpty();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMetricSelector(),
          const SizedBox(height: 16),
          _buildChart(),
          const SizedBox(height: 24),
          _buildSummaryCards(),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    final metrics = [
      ('bp', '血壓', Icons.favorite_rounded, const Color(0xFFFF453A)),
      ('hr', '心率', Icons.monitor_heart_rounded, const Color(0xFFFF2D55)),
      ('spo2', '血氧', Icons.water_drop_rounded, const Color(0xFF0A84FF)),
      ('weight', '體重', Icons.monitor_weight_rounded, const Color(0xFF30D158)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: metrics.map((m) {
          final isSelected = _activeMetric == m.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeMetric = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? m.$4.withOpacity(0.2) : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? m.$4 : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(m.$3, color: isSelected ? m.$4 : Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(m.$2,
                        style: GoogleFonts.notoSansTc(
                          color: isSelected ? m.$4 : Colors.white38,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    final dataPoints = _getChartData();
    if (dataPoints.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('此項目無資料', style: GoogleFonts.notoSansTc(color: Colors.white38)),
        ),
      );
    }

    final color = _getMetricColor();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (dataPoints.length / 5).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= _records.length) return const SizedBox();
                  final r = _records[_records.length - 1 - idx];
                  return Text(
                    DateFormat('M/d').format(r.timestamp),
                    style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor.withValues(alpha: 0.5), fontSize: 9),
                  );
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor.withValues(alpha: 0.5), fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: _activeMetric == 'bp'
              ? [
                  _buildLine(dataPoints['systolic']!, const Color(0xFFFF453A)),
                  _buildLine(dataPoints['diastolic']!, const Color(0xFFFF9F0A)),
                ]
              : [_buildLine(dataPoints['main']!, color)],
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: spots.length <= 20,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.08),
      ),
    );
  }

  Map<String, List<FlSpot>> _getChartData() {
    final sorted = _records.reversed.toList();
    switch (_activeMetric) {
      case 'bp':
        final sys = <FlSpot>[], dia = <FlSpot>[];
        for (int i = 0; i < sorted.length; i++) {
          if (sorted[i].systolic != null) {
            sys.add(FlSpot(i.toDouble(), sorted[i].systolic!.toDouble()));
            dia.add(FlSpot(i.toDouble(), sorted[i].diastolic!.toDouble()));
          }
        }
        if (sys.isEmpty) return {};
        return {'systolic': sys, 'diastolic': dia};
      case 'hr':
        final pts = <FlSpot>[];
        for (int i = 0; i < sorted.length; i++) {
          if (sorted[i].heartRate != null) pts.add(FlSpot(i.toDouble(), sorted[i].heartRate!.toDouble()));
        }
        return pts.isEmpty ? {} : {'main': pts};
      case 'spo2':
        final pts = <FlSpot>[];
        for (int i = 0; i < sorted.length; i++) {
          if (sorted[i].spo2 != null) pts.add(FlSpot(i.toDouble(), sorted[i].spo2!));
        }
        return pts.isEmpty ? {} : {'main': pts};
      case 'weight':
        final pts = <FlSpot>[];
        for (int i = 0; i < sorted.length; i++) {
          if (sorted[i].weight != null) pts.add(FlSpot(i.toDouble(), sorted[i].weight!));
        }
        return pts.isEmpty ? {} : {'main': pts};
      default:
        return {};
    }
  }

  Color _getMetricColor() {
    switch (_activeMetric) {
      case 'bp': return const Color(0xFFFF453A);
      case 'hr': return const Color(0xFFFF2D55);
      case 'spo2': return const Color(0xFF0A84FF);
      case 'weight': return const Color(0xFF30D158);
      default: return const Color(0xFF0A84FF);
    }
  }

  Widget _buildSummaryCards() {
    final validBP = _records.where((r) => r.systolic != null).toList();
    final validHR = _records.where((r) => r.heartRate != null).toList();
    final validSpO2 = _records.where((r) => r.spo2 != null).toList();
    final validW = _records.where((r) => r.weight != null).toList();

    avg(List<double> list) => list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (validBP.isNotEmpty)
          _StatCard(
            label: '平均血壓',
            value: '${avg(validBP.map((r) => r.systolic!.toDouble()).toList())!.toStringAsFixed(0)}/'
                '${avg(validBP.map((r) => r.diastolic!.toDouble()).toList())!.toStringAsFixed(0)}',
            unit: 'mmHg',
            color: const Color(0xFFFF453A),
            count: validBP.length,
          ),
        if (validHR.isNotEmpty)
          _StatCard(
            label: '平均心率',
            value: avg(validHR.map((r) => r.heartRate!.toDouble()).toList())!.toStringAsFixed(0),
            unit: 'bpm',
            color: const Color(0xFFFF2D55),
            count: validHR.length,
          ),
        if (validSpO2.isNotEmpty)
          _StatCard(
            label: '平均血氧',
            value: avg(validSpO2.map((r) => r.spo2!).toList())!.toStringAsFixed(1),
            unit: '%',
            color: const Color(0xFF0A84FF),
            count: validSpO2.length,
          ),
        if (validW.isNotEmpty)
          _StatCard(
            label: '平均體重',
            value: avg(validW.map((r) => r.weight!).toList())!.toStringAsFixed(1),
            unit: 'kg',
            color: const Color(0xFF30D158),
            count: validW.length,
          ),
      ],
    );
  }

  // ─── List Tab ─────────────────────────────────────────────────────────────

  Widget _buildListTab() {
    if (_records.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _records.length,
      itemBuilder: (ctx, i) {
        final r = _records[i];
        return _RecordCard(
          record: r,
          onDelete: () => _deleteRecord(r),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 60, color: Colors.white12),
          const SizedBox(height: 12),
          Text('尚無記錄', style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 15)),
        ],
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final int count;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            '$value $unit',
            style: GoogleFonts.notoSansTc(color: color, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text('共 $count 筆', style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor.withValues(alpha: 0.5), fontSize: 10)),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final HealthRecord record;
  final VoidCallback onDelete;

  const _RecordCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    return Dismissible(
      key: Key('record_${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF453A).withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF453A)),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    record.source == 'camera'
                        ? Icons.camera_alt_rounded
                        : record.source == 'manual'
                            ? Icons.edit_rounded
                            : Icons.bluetooth_rounded,
                    size: 14,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(record.timestamp),
                    style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11),
                  ),
                  if (record.deviceName != null) ...[
                    const SizedBox(width: 6),
                    Text('· ${record.deviceName}', style: GoogleFonts.notoSansTc(color: Colors.white24, fontSize: 11)),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (record.systolic != null)
                    _MetricChip('血壓', '${record.systolic}/${record.diastolic}', 'mmHg', const Color(0xFFFF453A)),
                  if (record.heartRate != null)
                    _MetricChip('心率', '${record.heartRate}', 'bpm', const Color(0xFFFF2D55)),
                  if (record.spo2 != null)
                    _MetricChip('血氧', record.spo2!.toStringAsFixed(1), '%', const Color(0xFF0A84FF)),
                  if (record.weight != null)
                    _MetricChip('體重', record.weight!.toStringAsFixed(1), 'kg', const Color(0xFF30D158)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricChip(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.notoSansTc(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 2),
        Text(unit, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10)),
      ],
    );
  }
}
