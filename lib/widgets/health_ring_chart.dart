// lib/widgets/health_ring_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class HealthRingChart extends StatelessWidget {
  final Map<String, dynamic> stats;

  const HealthRingChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final avgBP = stats['avg_systolic'] as double?;
    final avgHR = stats['avg_heart_rate'] as double?;
    final avgSpO2 = stats['avg_spo2'] as double?;
    final avgWeight = stats['avg_weight'] as double?;
    final total = stats['total_records'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: _buildSections(avgBP, avgHR, avgSpO2, avgWeight),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: GoogleFonts.notoSansTc(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '筆',
                          style: GoogleFonts.notoSansTc(fontSize: 9, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    if (avgBP != null)
                      _StatRow('血壓', '${avgBP.toStringAsFixed(0)}/${(stats['avg_diastolic'] as double?)?.toStringAsFixed(0)}', 'mmHg', const Color(0xFFFF453A)),
                    if (avgHR != null)
                      _StatRow('心率', avgHR.toStringAsFixed(0), 'bpm', const Color(0xFFFF2D55)),
                    if (avgSpO2 != null)
                      _StatRow('血氧', avgSpO2.toStringAsFixed(1), '%', const Color(0xFF0A84FF)),
                    if (avgWeight != null)
                      _StatRow('體重', avgWeight.toStringAsFixed(1), 'kg', const Color(0xFF30D158)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(
    double? bp, double? hr, double? spo2, double? weight
  ) {
    final sections = <PieChartSectionData>[];
    final items = [
      (bp, const Color(0xFFFF453A)),
      (hr, const Color(0xFFFF2D55)),
      (spo2, const Color(0xFF0A84FF)),
      (weight, const Color(0xFF30D158)),
    ];

    int count = items.where((i) => i.$1 != null).length;
    if (count == 0) {
      return [PieChartSectionData(value: 1, color: Colors.white12, showTitle: false, radius: 12)];
    }

    for (final item in items) {
      if (item.$1 != null) {
        sections.add(PieChartSectionData(
          value: 1,
          color: item.$2,
          showTitle: false,
          radius: 14,
        ));
      }
    }
    return sections;
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatRow(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11)),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.notoSansTc(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(unit, style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
