// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/health_provider.dart';
import '../models/health_record.dart';
import '../models/lab_result.dart';
import '../widgets/metric_card.dart';
import '../widgets/health_ring_chart.dart';
import '../widgets/lab_metric_card.dart';
import '../providers/step_provider.dart';
import '../providers/theme_provider.dart';
import 'bluetooth_scan_screen.dart';
import 'camera_measurement_screen.dart';
import 'history_screen.dart';
import 'manual_entry_screen.dart';
import 'lab_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<LabResult> _labMetrics = [];
  bool _isLabLoaded = false;
  final List<String> _filters = ['所有', '肝膽功能', '腎功能', '三高指標', '電解質', '血液相關'];
  int _activeFilter = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadLabMetrics();
  }

  Future<void> _loadLabMetrics() async {
    final List<LabResult> allRaw = [
      LabResult(category: '血液相關', name: 'WBC (白血球)', value: 7.01, unit: '10^3/uL', minNormal: 4.0, maxNormal: 10.0, records: _generateRecords([5.2, 4.8, 6.1, 5.5, 4.9, 7.2, 6.8, 5.9, 6.5, 4.5, 6.2, 5.8, 7.5, 6.9, 7.0, 7.01])),
      LabResult(category: '血液相關', name: 'Hb (血紅素)', value: 13.7, unit: 'g/dL', minNormal: 13.0, maxNormal: 17.5, records: _generateRecords([14.2, 13.9, 13.5, 14.0, 13.8, 12.8, 13.2, 13.5, 12.9, 13.8, 13.7])),
      LabResult(category: '腎功能', name: 'Ferritin (鐵蛋白)', value: 139.0, unit: 'ng/mL', minNormal: 30.0, maxNormal: 400.0, records: _generateRecords([180, 160, 145, 130, 200, 175, 120, 150, 110, 139])),
      LabResult(category: '腎功能', name: 'TSAT (%)', value: 33.7, unit: '%', minNormal: 20.0, maxNormal: 50.0, records: _generateRecords([25, 28, 30, 32, 22, 28, 35, 33, 33.7])),
      LabResult(category: '腎功能', name: 'BUN (尿素氮)', value: 57.0, unit: 'mg/dL', minNormal: 8.0, maxNormal: 23.0, records: _generateRecords([15, 18, 22, 25, 40, 55, 62, 55, 65, 57])),
      LabResult(category: '腎功能', name: 'Cr (肌酸酐)', value: 13.3, unit: 'mg/dL', minNormal: 0.7, maxNormal: 1.3, records: _generateRecords([1.1, 1.2, 5.5, 8.2, 11.5, 12.8, 14.2, 13.3])),
      LabResult(category: '肝膽功能', name: 'Albumin (白蛋白)', value: 3.9, unit: 'g/dL', minNormal: 3.5, maxNormal: 5.2, records: _generateRecords([4.2, 4.1, 3.8, 4.0, 3.9])),
      LabResult(category: '腎功能', name: 'UA (尿酸)', value: 7.4, unit: 'mg/dL', minNormal: 3.0, maxNormal: 7.2, records: _generateRecords([6.2, 6.8, 7.0, 6.5, 7.2, 7.8, 7.4])),
      LabResult(category: '肝膽功能', name: 'AST (肝功能)', value: 17, unit: 'U/L', minNormal: 10.0, maxNormal: 40.0, records: _generateRecords([25, 20, 15, 22, 18, 17])),
      LabResult(category: '電解質', name: 'Na (鈉)', value: 135, unit: 'mEq/L', minNormal: 136.0, maxNormal: 145.0, records: _generateRecords([142, 140, 138, 137, 136, 135])),
      LabResult(category: '電解質', name: 'K (鉀)', value: 4.6, unit: 'mEq/L', minNormal: 3.5, maxNormal: 5.1, records: _generateRecords([3.8, 4.0, 4.2, 4.8, 4.5, 4.6])),
      LabResult(category: '三高指標', name: 'HbA1c (醣化血紅素)', value: 5.4, unit: '%', minNormal: 4.0, maxNormal: 6.0, records: _generateRecords([5.6, 5.4, 5.2, 5.5, 5.3, 5.4])),
    ];

    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('lab_report_order');
    
    setState(() {
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final Map<String, LabResult> metricMap = {for (var m in allRaw) m.name: m};
        List<LabResult> orderedList = [];
        for (var name in savedOrder) {
          if (metricMap.containsKey(name)) {
            orderedList.add(metricMap[name]!);
            metricMap.remove(name);
          }
        }
        orderedList.addAll(metricMap.values);
        _labMetrics = orderedList;
      } else {
        _labMetrics = allRaw;
      }
      _isLabLoaded = true;
    });
  }

  static List<LabRecord> _generateRecords(List<double> values) {
    final now = DateTime.now();
    return values.asMap().entries.map((e) {
      return LabRecord(
        date: DateTime(now.year, now.month - (values.length - 1 - e.key), now.day),
        value: e.value,
      );
    }).toList();
  }

  Future<void> _saveLabOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = _labMetrics.map((m) => m.name).toList();
    await prefs.setStringList('lab_report_order', order);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final themeProvider = ctx.watch<ThemeProvider>();
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('選擇主題風格', style: GoogleFonts.notoSansTc(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildThemeOption(ctx, AppThemeType.modernTech, '現代科技', Icons.dark_mode_rounded, themeProvider),
              _buildThemeOption(ctx, AppThemeType.warmService, '溫馨服務', Icons.wb_sunny_rounded, themeProvider),
              _buildThemeOption(ctx, AppThemeType.calmMedical, '平靜醫療', Icons.medical_services_rounded, themeProvider),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(BuildContext context, AppThemeType type, String name, IconData icon, ThemeProvider provider) {
    final isSelected = provider.currentTheme == type;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
      title: Text(name, style: GoogleFonts.notoSansTc(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor) : null,
      onTap: () {
        provider.setTheme(type);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<HealthProvider>(
        builder: (_, provider, __) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await provider.refresh();
                await _loadLabMetrics();
              },
              color: Theme.of(context).primaryColor,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(provider),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildStepsSection(context),
                        const SizedBox(height: 20),
                        _buildLatestSection(provider),
                        const SizedBox(height: 20),
                        Text(
                          '檢驗報告 Dashboard',
                          style: GoogleFonts.notoSansTc(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLabFilterBar(),
                      ]),
                    ),
                  ),
                  _buildLabGridSection(),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 20),
                        _buildStatsSection(provider),
                        const SizedBox(height: 20),
                        _buildHistory(provider),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(HealthProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          '健康監測',
          style: GoogleFonts.notoSansTc(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                ? [theme.primaryColor, theme.scaffoldBackgroundColor]
                : [theme.primaryColor.withValues(alpha: 0.1), theme.scaffoldBackgroundColor],
              stops: const [0.0, 0.8],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: '切換主題',
          icon: const Icon(Icons.palette_outlined),
          onPressed: () => _showThemePicker(context),
        ),
        IconButton(
          tooltip: '藍芽掃描',
          icon: const Icon(Icons.bluetooth_audio_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BluetoothScanScreen()),
          ).then((_) => provider.refresh()),
        ),
        IconButton(
          tooltip: '影像辨識',
          icon: const Icon(Icons.camera_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraMeasurementScreen()),
          ).then((_) => provider.refresh()),
        ),
        IconButton(
          tooltip: '手動輸入',
          icon: const Icon(Icons.edit_note_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
          ).then((_) => provider.refresh()),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLabFilterBar() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final isSelected = _activeFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: GoogleFonts.notoSansTc(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabGridSection() {
    if (!_isLabLoaded) {
      return const SliverToBoxAdapter(
        child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      );
    }

    final filteredData = _activeFilter == 0 
        ? _labMetrics 
        : _labMetrics.where((d) => d.category == _filters[_activeFilter]).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2; 
    if (screenWidth > 1200) {
      crossAxisCount = 6; 
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: ReorderableSliverGridView(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            final item = filteredData.removeAt(oldIndex);
            filteredData.insert(newIndex, item);
            _labMetrics = List.from(_labMetrics);
            _saveLabOrder();
          });
        },
        children: filteredData.map((result) {
          return LabMetricCard(
            key: ValueKey('home_${result.name}'),
            result: result,
            width: 200,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LabDetailScreen(result: result)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepsSection(BuildContext context) {
    return Consumer<StepProvider>(
      builder: (context, stepProvider, child) {
        if (!stepProvider.isAvailable) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日活動',
              style: GoogleFonts.notoSansTc(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 10),
            MetricCard(
              width: double.infinity,
              icon: Icons.directions_walk_rounded,
              color: const Color(0xFFBF5AF2),
              label: '今日步數',
              value: '${stepProvider.todaySteps}',
              unit: '步',
              status: stepProvider.status,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLatestSection(HealthProvider provider) {
    if (provider.loading || provider.latestRecord == null) return const SizedBox.shrink();
    final r = provider.latestRecord!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最近健康數值', style: GoogleFonts.notoSansTc(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            Text(_formatDate(r.timestamp), style: GoogleFonts.notoSansTc(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (ctx, constraints) {
          final w = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (r.systolic != null)
                MetricCard(width: w, icon: Icons.favorite_rounded, color: const Color(0xFFFF453A), label: '血壓', value: '${r.systolic}/${r.diastolic}', unit: 'mmHg', status: r.bpStatus.label),
              if (r.heartRate != null)
                MetricCard(width: w, icon: Icons.monitor_heart_rounded, color: const Color(0xFFFF2D55), label: '心率', value: '${r.heartRate}', unit: 'bpm', status: r.hrStatus == HeartRateStatus.normal ? '正常' : '異常', animation: _pulseAnimation),
              if (r.spo2 != null)
                MetricCard(width: w, icon: Icons.water_drop_rounded, color: const Color(0xFF0A84FF), label: '血氧', value: r.spo2!.toStringAsFixed(1), unit: '%', status: r.spo2Status == SpO2Status.normal ? '正常' : '偏低'),
              if (r.weight != null)
                MetricCard(width: w, icon: Icons.monitor_weight_rounded, color: const Color(0xFF30D158), label: '體重', value: r.weight!.toStringAsFixed(1), unit: 'kg', status: '已記錄'),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStatsSection(HealthProvider provider) {
    if (provider.stats30d.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('30天平均狀態', style: GoogleFonts.notoSansTc(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 10),
        HealthRingChart(stats: provider.stats30d),
      ],
    );
  }

  Widget _buildHistory(HealthProvider provider) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('歷史記錄', style: GoogleFonts.notoSansTc(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())).then((_) => provider.refresh()),
          child: Text('查看全部', style: GoogleFonts.notoSansTc(color: theme.primaryColor, fontSize: 13)),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
    if (diff.inDays < 1) return '${diff.inHours} 小時前';
    return '${dt.month}/${dt.day}';
  }
}
