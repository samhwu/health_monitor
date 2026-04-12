// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/health_provider.dart';
import '../utils/export_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _gender = 'male';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<HealthProvider>().profile;
    if (p != null) {
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age?.toString() ?? '';
      _heightCtrl.text = p.heightCm?.toString() ?? '';
      _gender = p.gender ?? 'male';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = UserProfile(
      name: _nameCtrl.text,
      age: _ageCtrl.text.isNotEmpty ? int.tryParse(_ageCtrl.text) : null,
      gender: _gender,
      heightCm: _heightCtrl.text.isNotEmpty ? double.tryParse(_heightCtrl.text) : null,
    );
    await context.read<HealthProvider>().saveProfile(profile);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 個人資料已儲存'), backgroundColor: Color(0xFF30D158)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: Text('儲存', style: GoogleFonts.notoSansTc(color: const Color(0xFF0A84FF))),
            ),
        ],
      ),
      body: Consumer<HealthProvider>(
        builder: (_, provider, __) {
          final bmi = provider.currentBMI;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar area
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFF1C1C1E),
                      child: Text(
                        _nameCtrl.text.isNotEmpty
                            ? _nameCtrl.text.characters.first.toUpperCase()
                            : '?',
                        style: GoogleFonts.notoSansTc(fontSize: 36, color: const Color(0xFF0A84FF)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (bmi != null) ...[
                      Text(
                        'BMI ${bmi.toStringAsFixed(1)}',
                        style: GoogleFonts.notoSansTc(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        provider.bmiCategory,
                        style: GoogleFonts.notoSansTc(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Form
              _SectionLabel('基本資料'),
              const SizedBox(height: 10),
              _buildField(
                controller: _nameCtrl,
                label: '姓名',
                hint: '輸入您的姓名',
                icon: Icons.person_rounded,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _ageCtrl,
                      label: '年齡',
                      hint: '25',
                      icon: Icons.cake_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _heightCtrl,
                      label: '身高 (cm)',
                      hint: '170',
                      icon: Icons.height_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Gender picker
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('性別', style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _GenderChip(label: '男性', value: 'male', selected: _gender == 'male',
                            onTap: () => setState(() { _gender = 'male'; _dirty = true; })),
                        const SizedBox(width: 8),
                        _GenderChip(label: '女性', value: 'female', selected: _gender == 'female',
                            onTap: () => setState(() { _gender = 'female'; _dirty = true; })),
                        const SizedBox(width: 8),
                        _GenderChip(label: '其他', value: 'other', selected: _gender == 'other',
                            onTap: () => setState(() { _gender = 'other'; _dirty = true; })),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              _SectionLabel('資料管理'),
              const SizedBox(height: 10),

              _ActionTile(
                icon: Icons.download_rounded,
                color: const Color(0xFF0A84FF),
                label: '匯出 CSV',
                subtitle: '將所有記錄匯出為試算表格式',
                onTap: () async {
                  final records = provider.records;
                  if (records.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('尚無記錄可匯出')),
                    );
                    return;
                  }
                  await ExportHelper.exportCSV(records);
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.description_rounded,
                color: const Color(0xFF30D158),
                label: '匯出健康報告',
                subtitle: '產生純文字摘要，適合分享給醫師',
                onTap: () async {
                  final records = provider.records;
                  if (records.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('尚無記錄可匯出')),
                    );
                    return;
                  }
                  await ExportHelper.exportTextSummary(
                    records,
                    patientName: provider.profile?.name,
                    stats: provider.stats30d,
                  );
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.delete_forever_rounded,
                color: const Color(0xFFFF453A),
                label: '清除所有記錄',
                subtitle: '此操作無法復原',
                onTap: () => _confirmDelete(context, provider),
              ),

              const SizedBox(height: 28),
              // Stats summary
              _StatsCard(provider: provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.notoSansTc(color: Colors.white, fontSize: 15),
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        labelStyle: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 12),
        hintStyle: GoogleFonts.notoSansTc(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0A84FF)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, HealthProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('確認刪除', style: GoogleFonts.notoSansTc(color: Colors.white)),
        content: Text(
          '將刪除所有 ${provider.records.length} 筆健康記錄，此操作無法復原。',
          style: GoogleFonts.notoSansTc(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF453A)),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final r in List.from(provider.records)) {
        await provider.deleteRecord(r.id!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除所有記錄'), backgroundColor: Color(0xFFFF453A)),
        );
      }
    }
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.notoSansTc(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white38,
        letterSpacing: 1,
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0A84FF) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.notoSansTc(color: selected ? Colors.white : Colors.white54, fontSize: 13)),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon, required this.color,
    required this.label, required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.notoSansTc(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final HealthProvider provider;
  const _StatsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A4A), Color(0xFF1C1C1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0A84FF).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('統計概覽', style: GoogleFonts.notoSansTc(color: const Color(0xFF0A84FF), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatItem('總記錄', '${provider.records.length}', '筆'),
              const SizedBox(width: 24),
              _StatItem('連續天數', '${provider.currentStreak}', '天'),
              if (provider.currentBMI != null) ...[
                const SizedBox(width: 24),
                _StatItem('BMI', provider.currentBMI!.toStringAsFixed(1), ''),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatItem(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: GoogleFonts.notoSansTc(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: GoogleFonts.notoSansTc(fontSize: 10, color: Colors.white38)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
