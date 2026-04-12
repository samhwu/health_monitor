// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminderEnabled = false;
  bool _bpAlertEnabled = true;
  bool _spo2AlertEnabled = true;
  int _reminderHour = 8;
  int _reminderMinute = 0;
  String _bpUnit = 'mmHg';
  String _weightUnit = 'kg';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyReminderEnabled = prefs.getBool('daily_reminder') ?? false;
      _bpAlertEnabled       = prefs.getBool('bp_alert') ?? true;
      _spo2AlertEnabled     = prefs.getBool('spo2_alert') ?? true;
      _reminderHour         = prefs.getInt('reminder_hour') ?? 8;
      _reminderMinute       = prefs.getInt('reminder_minute') ?? 0;
      _bpUnit               = prefs.getString('bp_unit') ?? 'mmHg';
      _weightUnit           = prefs.getString('weight_unit') ?? 'kg';
      _loading              = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder', _dailyReminderEnabled);
    await prefs.setBool('bp_alert', _bpAlertEnabled);
    await prefs.setBool('spo2_alert', _spo2AlertEnabled);
    await prefs.setInt('reminder_hour', _reminderHour);
    await prefs.setInt('reminder_minute', _reminderMinute);
    await prefs.setString('bp_unit', _bpUnit);
    await prefs.setString('weight_unit', _weightUnit);

    // 同步通知設定
    await NotificationService().scheduleDailyReminder(
      hour: _reminderHour,
      minute: _reminderMinute,
      enabled: _dailyReminderEnabled,
    );
  }

  Future<void> _pickReminderTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: Theme.of(context).primaryColor,
            onSurface: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() {
        _reminderHour = t.hour;
        _reminderMinute = t.minute;
      });
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // ─── Notifications ──────────────────────────────────────────
                _GroupHeader('通知與提醒'),
                _SettingCard(
                  children: [
                    _SwitchTile(
                      icon: Icons.alarm_rounded,
                      color: const Color(0xFF30B0C7),
                      label: '每日量測提醒',
                      subtitle: _dailyReminderEnabled
                          ? '每天 ${_reminderHour.toString().padLeft(2, "0")}:${_reminderMinute.toString().padLeft(2, "0")} 提醒'
                          : '已停用',
                      value: _dailyReminderEnabled,
                      onChanged: (v) async {
                        setState(() => _dailyReminderEnabled = v);
                        await _saveSettings();
                      },
                    ),
                    if (_dailyReminderEnabled) ...[
                      Divider(color: Theme.of(context).dividerColor, height: 1),
                      _TapTile(
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFF30B0C7),
                        label: '提醒時間',
                        trailing: Text(
                          '${_reminderHour.toString().padLeft(2, "0")}:${_reminderMinute.toString().padLeft(2, "0")}',
                          style: GoogleFonts.notoSansTc(color: Theme.of(context).primaryColor, fontSize: 15),
                        ),
                        onTap: _pickReminderTime,
                      ),
                    ],
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    _SwitchTile(
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFFF453A),
                      label: '血壓異常警示',
                      subtitle: '收縮壓 ≥ 140 mmHg 時通知',
                      value: _bpAlertEnabled,
                      onChanged: (v) async {
                        setState(() => _bpAlertEnabled = v);
                        await _saveSettings();
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _SwitchTile(
                      icon: Icons.water_drop_rounded,
                      color: const Color(0xFF0A84FF),
                      label: '血氧過低警示',
                      subtitle: 'SpO₂ < 95% 時通知',
                      value: _spo2AlertEnabled,
                      onChanged: (v) async {
                        setState(() => _spo2AlertEnabled = v);
                        await _saveSettings();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── Units ──────────────────────────────────────────────────
                _GroupHeader('單位設定'),
                _SettingCard(
                  children: [
                    _SegmentTile(
                      icon: Icons.monitor_heart_rounded,
                      color: const Color(0xFFFF453A),
                      label: '血壓單位',
                      options: const ['mmHg', 'kPa'],
                      selected: _bpUnit,
                      onChanged: (v) async {
                        setState(() => _bpUnit = v);
                        await _saveSettings();
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _SegmentTile(
                      icon: Icons.monitor_weight_rounded,
                      color: const Color(0xFF30D158),
                      label: '體重單位',
                      options: const ['kg', 'lbs'],
                      selected: _weightUnit,
                      onChanged: (v) async {
                        setState(() => _weightUnit = v);
                        await _saveSettings();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── About ──────────────────────────────────────────────────
                _GroupHeader('關於'),
                _SettingCard(
                  children: [
                    _InfoTile(icon: Icons.info_outline_rounded, label: '版本', value: '1.0.0'),
                    const Divider(color: Colors.white12, height: 1),
                    _InfoTile(icon: Icons.code_rounded, label: '開發者', value: 'Health Monitor'),
                    const Divider(color: Colors.white12, height: 1),
                    _TapTile(
                      icon: Icons.privacy_tip_outlined,
                      color: Colors.white38,
                      label: '隱私政策',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    '⚠️ 本應用程式僅供健康記錄參考用途，不能替代專業醫療診斷。如有任何健康疑慮，請諮詢合格醫療人員。',
                    style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor.withValues(alpha: 0.5), fontSize: 11, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── UI Helpers ──────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.notoSansTc(fontSize: 11, color: Theme.of(context).disabledColor, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon, required this.color,
    required this.label, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                Text(subtitle, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget trailing;
  final VoidCallback onTap;

  const _TapTile({
    required this.icon, required this.color,
    required this.label, required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontSize: 14))),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentTile({
    required this.icon, required this.color,
    required this.label, required this.options,
    required this.selected, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface, fontSize: 14))),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options.map((o) {
                final isSelected = o == selected;
                return GestureDetector(
                  onTap: () => onChanged(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(o, style: GoogleFonts.notoSansTc(color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor, fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).disabledColor, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14))),
          Text(value, style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor, fontSize: 13)),
        ],
      ),
    );
  }
}
