// lib/screens/lab_report_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/lab_result.dart';
import '../widgets/lab_metric_card.dart';
import '../providers/theme_provider.dart';
import 'lab_detail_screen.dart';

class LabReportScreen extends StatefulWidget {
  const LabReportScreen({super.key});

  @override
  State<LabReportScreen> createState() => _LabReportScreenState();
}

class _LabReportScreenState extends State<LabReportScreen> {
  final List<String> _filters = ['所有', '肝膽功能', '腎功能', '三高指標', '電解質', '血液相關'];
  int _activeFilter = 0;
  bool _isLoaded = false;

  late List<LabResult> _displayList;
  bool _isDragging = false;
  
  static List<LabRecord> _generateRecords(List<double> values) {
    final now = DateTime.now();
    return values.asMap().entries.map((e) {
      return LabRecord(
        date: DateTime(now.year, now.month - (values.length - 1 - e.key), now.day),
        value: e.value,
      );
    }).toList();
  }

  final List<LabResult> _allMetrics = [
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

  @override
  void initState() {
    super.initState();
    _loadSavedOrder();
  }

  Future<void> _loadSavedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('lab_report_order');
    
    setState(() {
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final Map<String, LabResult> metricMap = {for (var m in _allMetrics) m.name: m};
        List<LabResult> orderedList = [];
        for (var name in savedOrder) {
          if (metricMap.containsKey(name)) {
            orderedList.add(metricMap[name]!);
            metricMap.remove(name);
          }
        }
        orderedList.addAll(metricMap.values);
        _displayList = orderedList;
      } else {
        _displayList = List.from(_allMetrics);
      }
      _isLoaded = true;
    });
  }

  Future<void> _saveCurrentOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = _displayList.map((m) => m.name).toList();
    await prefs.setStringList('lab_report_order', order);
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
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF))),
      );
    }

    final filteredList = _activeFilter == 0 
        ? _displayList 
        : _displayList.where((m) => m.category == _filters[_activeFilter]).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF000000), 
      appBar: AppBar(
        title: Text(
          '檢驗報告 Dashboard',
          style: GoogleFonts.notoSansTc(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _showThemePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Listener(
          onPointerUp: (_) {
            if (_isDragging) setState(() => _isDragging = false);
          },
          child: AnimatedScale(
            scale: _isDragging ? 0.90 : 1.0, 
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack, 
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(_isDragging ? 28 : 0),
              ),
              child: Column(
                children: [
                   _buildFilterTabs(),
                   Expanded(child: _buildGridLayout(filteredList)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isActive = _activeFilter == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_filters[index]),
              selected: isActive,
              onSelected: (val) {
                if (val) setState(() => _activeFilter = index);
              },
              backgroundColor: Colors.transparent,
              selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              labelStyle: GoogleFonts.notoSansTc(
                fontSize: 12,
                color: isActive ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isActive ? Theme.of(context).primaryColor : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
              showCheckmark: false,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGridLayout(List<LabResult> list) {
    return ReorderableGridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 6 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(16),
      childAspectRatio: 0.85,
      dragStartDelay: const Duration(milliseconds: 800),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final item = list.removeAt(oldIndex);
          list.insert(newIndex, item);
          
          if (_activeFilter == 0) {
            _displayList = list;
          } else {
            final Map<String, int> indexMap = {};
            for (int i = 0; i < list.length; i++) {
              indexMap[list[i].name] = i;
            }
            // Sync back to _displayList if needed
          }
          _saveCurrentOrder();
        });
      },
      onDragStart: (idx) {
        setState(() => _isDragging = true);
      },
      children: list.map((result) {
        return LabMetricCard(
          key: ValueKey(result.name),
          result: result,
          width: double.infinity,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LabDetailScreen(result: result),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
