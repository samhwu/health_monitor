// lib/widgets/lab_metric_card.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/lab_result.dart';

class LabMetricCard extends StatefulWidget {
  final LabResult result;
  final double width;
  final VoidCallback? onTap;

  const LabMetricCard({
    super.key,
    required this.result,
    required this.width,
    this.onTap,
  });

  @override
  State<LabMetricCard> createState() => _LabMetricCardState();
}

class _LabMetricCardState extends State<LabMetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(_isHovered ? 1.02 : 1.0),
          width: widget.width,
          height: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered 
                  ? widget.result.statusColor.withValues(alpha: 0.8) 
                  : widget.result.statusColor.withValues(alpha: 0.2),
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.result.statusColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.result.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansTc(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildMiniChart()),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Container(
                    width: 85,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.result.status == 'normal' 
                          ? Colors.transparent 
                          : (widget.result.status == 'high' 
                              ? Colors.redAccent.withValues(alpha: 0.8) 
                              : Colors.greenAccent.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.result.value.toStringAsFixed(1),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSansTc(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: widget.result.status == 'normal' 
                          ? Theme.of(context).colorScheme.onSurface 
                          : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.result.unit,
                    style: GoogleFonts.notoSansTc(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'σ ${widget.result.standardDeviation.toStringAsFixed(2)}',
                    style: GoogleFonts.notoSansTc(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChart() {
    if (widget.result.history.isEmpty) return Center(child: Text('無資料', style: TextStyle(color: Theme.of(context).disabledColor.withValues(alpha: 0.3))));

    final dataMin = widget.result.history.reduce((a, b) => a < b ? a : b);
    final dataMax = widget.result.history.reduce((a, b) => a > b ? a : b);
    
    double minY, maxY;
    bool showNormalLines = widget.result.status == 'normal';
    
    if (showNormalLines) {
      final minVal = [dataMin, widget.result.minNormal].reduce((a, b) => a < b ? a : b);
      final maxVal = [dataMax, widget.result.maxNormal].reduce((a, b) => a > b ? a : b);
      final range = maxVal - minVal;
      minY = minVal - (range * 0.15);
      maxY = maxVal + (range * 0.15);
    } else {
      final range = dataMax - dataMin == 0 ? dataMax * 0.4 : dataMax - dataMin;
      minY = dataMin - (range * 0.3);
      maxY = dataMax + (range * 0.3);
    }

    final spots = widget.result.records.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    int highestIndex = -1;
    int lowestIndex = -1;
    if (widget.result.records.isNotEmpty) {
      double maxVal = widget.result.records[0].value;
      double minVal = widget.result.records[0].value;
      for (int i = 0; i < widget.result.records.length; i++) {
        final v = widget.result.records[i].value;
        if (v > maxVal) { maxVal = v; highestIndex = i; }
        if (v < minVal) { minVal = v; lowestIndex = i; }
      }
      if (highestIndex == -1) highestIndex = 0;
      if (lowestIndex == -1) lowestIndex = 0;
    }

    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: widget.result.statusColor.withValues(alpha: 0.8),
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) {
          final index = spot.x.toInt();
          return index == highestIndex || index == lowestIndex;
        },
        getDotPainter: (spot, percent, barData, index) {
          if (index == highestIndex) {
            return TrianglePainter(color: Colors.white, upward: true, size: 7);
          } else if (index == lowestIndex) {
            return TrianglePainter(color: Colors.white, upward: false, size: 7);
          }
          return FlDotCirclePainter(radius: 0);
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.result.statusColor.withValues(alpha: 0.15),
            widget.result.statusColor.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    return LineChart(
      LineChartData(
        extraLinesData: ExtraLinesData(
          horizontalLines: showNormalLines ? [
            HorizontalLine(
              y: widget.result.minNormal,
              color: Colors.greenAccent.withValues(alpha: 0.3),
              strokeWidth: 1.5,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.bottomRight,
                style: GoogleFonts.notoSansTc(fontSize: 7, color: Colors.greenAccent.withValues(alpha: 0.5)),
                labelResolver: (_) => 'MIN (${widget.result.minNormal.toStringAsFixed(1)})',
              ),
            ),
            HorizontalLine(
              y: widget.result.maxNormal,
              color: Colors.redAccent.withValues(alpha: 0.3),
              strokeWidth: 1.5,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: GoogleFonts.notoSansTc(fontSize: 7, color: Colors.redAccent.withValues(alpha: 0.5)),
                labelResolver: (_) => 'MAX (${widget.result.maxNormal.toStringAsFixed(1)})',
              ),
            ),
          ] : [],
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent && widget.onTap != null) {
              widget.onTap!();
            }
          },
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                const FlLine(color: Colors.transparent),
                FlDotData(show: false),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipMargin: 0,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt(); 
                if (index < 0 || index >= widget.result.records.length) return null;
                final record = widget.result.records[index];
                
                final isHigh = index == highestIndex;
                final isLow = index == lowestIndex;

                String prefix = "";
                if (isHigh) {
                  prefix = "▲ ";
                } else if (isLow) prefix = "▼ ";

                final dateStr = DateFormat('MM/dd').format(record.date);

                return LineTooltipItem(
                  '${dateStr}\n',
                  GoogleFonts.notoSansTc(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '$prefix${record.value.toStringAsFixed(1)}',
                      style: GoogleFonts.notoSansTc(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        showingTooltipIndicators: const [],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 3).abs().clamp(0.1, 1000.0),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.03),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.notoSansTc(
                    fontSize: 8,
                    color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (!showNormalLines) return const SizedBox.shrink();
                if ((value - widget.result.minNormal).abs() < 0.1 || (value - widget.result.maxNormal).abs() < 0.1) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      value.toStringAsFixed(1),
                      style: GoogleFonts.notoSansTc(
                        fontSize: 8,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (widget.result.history.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [barData],
      ),
    );
  }
}

class TrianglePainter extends FlDotPainter {
  final Color color;
  final bool upward;
  final double size;

  TrianglePainter({required this.color, required this.upward, this.size = 8.0});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offset) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (upward) {
      path.moveTo(offset.dx, offset.dy - size / 2);
      path.lineTo(offset.dx - size / 2, offset.dy + size / 2);
      path.lineTo(offset.dx + size / 2, offset.dy + size / 2);
    } else {
      path.moveTo(offset.dx, offset.dy + size / 2);
      path.lineTo(offset.dx - size / 2, offset.dy - size / 2);
      path.lineTo(offset.dx + size / 2, offset.dy - size / 2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  Color get mainColor => color;

  @override
  Size getSize(FlSpot spot) => Size(size, size);

  @override
  List<Object?> get props => [color, upward, size];

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is TrianglePainter && b is TrianglePainter) {
      return TrianglePainter(
        color: Color.lerp(a.color, b.color, t) ?? color,
        upward: t < 0.5 ? a.upward : b.upward,
        size: a.size + (b.size - a.size) * t,
      );
    }
    return this;
  }
}
