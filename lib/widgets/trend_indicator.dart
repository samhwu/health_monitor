// lib/widgets/trend_indicator.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/health_evaluator.dart';

class TrendIndicator extends StatelessWidget {
  final List<double> values;
  final bool invertColors; // true for metrics where lower=better (BP, weight)

  const TrendIndicator({
    super.key,
    required this.values,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 3) return const SizedBox.shrink();

    final trend = HealthEvaluator.analyzeTrend(values);

    Color color;
    IconData icon;

    switch (trend) {
      case TrendResult.rising:
        color = invertColors ? const Color(0xFFFF453A) : const Color(0xFFFF9F0A);
        icon = Icons.trending_up_rounded;
        break;
      case TrendResult.falling:
        color = invertColors ? const Color(0xFF30D158) : const Color(0xFF0A84FF);
        icon = Icons.trending_down_rounded;
        break;
      case TrendResult.stable:
        color = Colors.white38;
        icon = Icons.trending_flat_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            trend.label,
            style: GoogleFonts.notoSansTc(color: color, fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
