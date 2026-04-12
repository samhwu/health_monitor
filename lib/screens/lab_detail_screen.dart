// lib/screens/lab_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/lab_result.dart';

class LabDetailScreen extends StatelessWidget {
  final LabResult result;

  const LabDetailScreen({super.key, required this.result});

  @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          title: Text(
            result.name,
            style: GoogleFonts.notoSansTc(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _buildMainChartSection(context)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildHistoryTable(context)),
            ],
          ),
        ),
      );
    }

  Widget _buildMainChartSection(BuildContext context) {
    if (result.history.isEmpty) return const SizedBox.shrink();

    final dataMin = result.history.reduce((a, b) => a < b ? a : b);
    final dataMax = result.history.reduce((a, b) => a > b ? a : b);
    
    // 詳情頁一律顯示完整邊界以利對比
    final minVal = [dataMin, result.minNormal].reduce((a, b) => a < b ? a : b);
    final maxVal = [dataMax, result.maxNormal].reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    double minY = minVal - (range * 0.2);
    // 若數據與標準值皆大於等於 0，則 Y 軸最小不低於 0
    if (minVal >= 0 && minY < 0) minY = 0;
    final maxY = maxVal + (range * 0.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('趨勢圖 (所有紀錄)', style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)),
              Text(
                '範圍: ${result.minNormal} - ${result.maxNormal} ${result.unit}',
                style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: result.minNormal,
                      color: Colors.greenAccent.withValues(alpha: 0.4),
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.bottomRight,
                        style: GoogleFonts.notoSansTc(fontSize: 8, color: Colors.greenAccent),
                        labelResolver: (_) => 'MIN (${result.minNormal.toStringAsFixed(1)})',
                      ),
                    ),
                    HorizontalLine(
                      y: result.maxNormal,
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: GoogleFonts.notoSansTc(fontSize: 8, color: Colors.redAccent),
                        labelResolver: (_) => 'MAX (${result.maxNormal.toStringAsFixed(1)})',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Theme.of(context).cardColor.withValues(alpha: 0.95),
                    tooltipBorder: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final index = barSpot.x.toInt();
                        if (index < 0 || index >= result.records.length) return null;
                        final record = result.records[index];
                        final dateStr = DateFormat('yyyy/MM/dd').format(record.date);
                        return LineTooltipItem(
                          '$dateStr\n',
                          GoogleFonts.notoSansTc(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${record.value.toStringAsFixed(1)} ${result.unit}',
                              style: GoogleFonts.notoSansTc(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: TextStyle(color: Theme.of(context).disabledColor.withValues(alpha: 0.5), fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= result.records.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MM/dd').format(result.records[idx].date),
                            style: TextStyle(fontSize: 9, color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: result.records.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.value);
                    }).toList(),
                    isCurved: true,
                    color: result.statusColor,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: result.statusColor.withValues(alpha: 0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, p, b, i) => FlDotCirclePainter(
                        radius: 4,
                        color: result.statusColor,
                        strokeColor: const Color(0xFF1C1C1E),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('歷史紀錄', style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
                Text('單位: ${result.unit}', style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)),
              ],
            ),
          ),
          // 凍結的表頭
          DataTable(
            columnSpacing: 16,
            horizontalMargin: 20,
            headingTextStyle: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor, fontSize: 13, fontWeight: FontWeight.bold),
            columns: const [
              DataColumn(label: SizedBox(width: 80, child: Text('檢查日期'))),
              DataColumn(label: SizedBox(width: 50, child: Text('數值'))),
              DataColumn(label: Text('狀態')),
            ],
            rows: const [], // 只有表頭
          ),
          // 可滾動的內容
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 0, // 隱藏內容區域的表頭
                columnSpacing: 16,
                horizontalMargin: 20,
                dataTextStyle: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                columns: const [
                  DataColumn(label: Text('')),
                  DataColumn(label: Text('')),
                  DataColumn(label: Text('')),
                ],
                rows: result.records.reversed.map((r) {
                  final status = _calculateStatus(r.value, result.minNormal, result.maxNormal);
                  final statusColor = _getStatusColor(status);
                  
                  return DataRow(cells: [
                    DataCell(SizedBox(width: 80, child: Text(DateFormat('yyyy/MM/dd').format(r.date)))),
                    DataCell(SizedBox(width: 50, child: Text(r.value.toStringAsFixed(1), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)))),
                    DataCell(Text(_getStatusLabel(status), style: TextStyle(color: statusColor))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _calculateStatus(double val, double min, double max) {
    if (val < min) return 'low';
    if (val > max) return 'high';
    return 'normal';
  }

  Color _getStatusColor(String status) {
    if (status == 'normal') return const Color(0xFF30D158);
    return const Color(0xFFFF453A);
  }

  String _getStatusLabel(String status) {
    if (status == 'high') return '偏高';
    if (status == 'low') return '偏低';
    return '正常';
  }
}
