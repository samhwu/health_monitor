// lib/screens/manual_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/health_database.dart';
import '../models/health_record.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _heartRateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_systolicCtrl, _diastolicCtrl, _heartRateCtrl, _weightCtrl, _spo2Ctrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // At least one field must be filled
    if (_systolicCtrl.text.isEmpty && _heartRateCtrl.text.isEmpty &&
        _weightCtrl.text.isEmpty && _spo2Ctrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少填入一項數值'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);

    final db = context.read<HealthDatabase>();
    final record = HealthRecord(
      timestamp: DateTime.now(),
      systolic: _systolicCtrl.text.isNotEmpty ? int.parse(_systolicCtrl.text) : null,
      diastolic: _diastolicCtrl.text.isNotEmpty ? int.parse(_diastolicCtrl.text) : null,
      heartRate: _heartRateCtrl.text.isNotEmpty ? int.parse(_heartRateCtrl.text) : null,
      weight: _weightCtrl.text.isNotEmpty ? double.parse(_weightCtrl.text) : null,
      spo2: _spo2Ctrl.text.isNotEmpty ? double.parse(_spo2Ctrl.text) : null,
      source: 'manual',
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
    );

    await db.insertRecord(record);
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 已儲存'), backgroundColor: Color(0xFF30D158)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手動輸入')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(icon: Icons.favorite_rounded, color: const Color(0xFFFF453A), label: '血壓'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    controller: _systolicCtrl,
                    label: '收縮壓',
                    hint: '120',
                    unit: 'mmHg',
                    min: 60, max: 250,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null) return '請輸入數字';
                      if (_diastolicCtrl.text.isEmpty) return '請同時填入舒張壓';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumField(
                    controller: _diastolicCtrl,
                    label: '舒張壓',
                    hint: '80',
                    unit: 'mmHg',
                    min: 40, max: 150,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.monitor_heart_rounded, color: const Color(0xFFFF2D55), label: '心率'),
            const SizedBox(height: 10),
            _NumField(
              controller: _heartRateCtrl,
              label: '心率',
              hint: '72',
              unit: 'bpm',
              min: 30, max: 220,
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.water_drop_rounded, color: const Color(0xFF0A84FF), label: '血氧飽和度'),
            const SizedBox(height: 10),
            _NumField(
              controller: _spo2Ctrl,
              label: '血氧 SpO₂',
              hint: '98',
              unit: '%',
              min: 70, max: 100,
              isDecimal: true,
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.monitor_weight_rounded, color: const Color(0xFF30D158), label: '體重'),
            const SizedBox(height: 10),
            _NumField(
              controller: _weightCtrl,
              label: '體重',
              hint: '65.0',
              unit: 'kg',
              min: 10, max: 300,
              isDecimal: true,
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.notes_rounded, color: Colors.white38, label: '備註'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '可選填（如：飯後、運動後...）',
                hintStyle: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2)
                    : Text('儲存記錄', style: GoogleFonts.notoSansTc(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SectionHeader({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String unit;
  final double min;
  final double max;
  final bool isDecimal;
  final String? Function(String?)? validator;

  const _NumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.unit,
    required this.min,
    required this.max,
    this.isDecimal = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(isDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]')),
      ],
      validator: validator ?? (v) {
        if (v == null || v.isEmpty) return null;
        final n = double.tryParse(v);
        if (n == null) return '請輸入有效數字';
        if (n < min || n > max) return '範圍：$min ~ $max';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
        hintText: hint,
        hintStyle: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor),
        suffixText: unit,
        suffixStyle: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        errorStyle: GoogleFonts.notoSansTc(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
