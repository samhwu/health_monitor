// lib/utils/export_helper.dart
//
// 將 health_records 匯出為 CSV 或純文字，
// 透過 share_plus 讓使用者分享或儲存。

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/health_record.dart';

class ExportHelper {
  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  // ─── CSV Export ──────────────────────────────────────────────────────────

  /// 將記錄轉為 CSV 並透過系統分享單
  static Future<void> exportCSV(List<HealthRecord> records) async {
    final rows = <List<dynamic>>[
      // Header
      ['日期時間', '收縮壓(mmHg)', '舒張壓(mmHg)', '心率(bpm)', '血氧(%)', '體重(kg)', '來源', '裝置', '備註'],
    ];

    for (final r in records) {
      rows.add([
        _dateFmt.format(r.timestamp),
        r.systolic ?? '',
        r.diastolic ?? '',
        r.heartRate ?? '',
        r.spo2 != null ? r.spo2!.toStringAsFixed(1) : '',
        r.weight != null ? r.weight!.toStringAsFixed(2) : '',
        _sourceLabel(r.source),
        r.deviceName ?? '',
        r.notes ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final path = await _writeTempFile(
      content: '\uFEFF$csvString', // BOM for Excel UTF-8
      filename: 'health_records_${DateFormat("yyyyMMdd").format(DateTime.now())}.csv',
    );

    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/csv')],
      subject: '健康記錄匯出',
      text: '共 ${records.length} 筆健康量測記錄',
    );
  }

  // ─── Plain Text Summary ──────────────────────────────────────────────────

  /// 產生純文字摘要（適合傳給醫師）
  static Future<void> exportTextSummary(
    List<HealthRecord> records, {
    String? patientName,
    Map<String, dynamic>? stats,
  }) async {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════');
    buf.writeln('    健康監測記錄摘要');
    buf.writeln('═══════════════════════════════════');
    if (patientName != null && patientName.isNotEmpty) {
      buf.writeln('姓名：$patientName');
    }
    buf.writeln('產生時間：${_dateFmt.format(DateTime.now())}');
    buf.writeln('記錄筆數：${records.length} 筆');
    buf.writeln();

    // 統計摘要
    if (stats != null && stats.isNotEmpty) {
      buf.writeln('【30天平均值】');
      if (stats['avg_systolic'] != null) {
        buf.writeln('  血壓：${(stats['avg_systolic'] as double).toStringAsFixed(0)}/'
            '${(stats['avg_diastolic'] as double).toStringAsFixed(0)} mmHg');
      }
      if (stats['avg_heart_rate'] != null) {
        buf.writeln('  心率：${(stats['avg_heart_rate'] as double).toStringAsFixed(0)} bpm');
      }
      if (stats['avg_spo2'] != null) {
        buf.writeln('  血氧：${(stats['avg_spo2'] as double).toStringAsFixed(1)}%');
      }
      if (stats['avg_weight'] != null) {
        buf.writeln('  體重：${(stats['avg_weight'] as double).toStringAsFixed(1)} kg');
      }
      buf.writeln();
    }

    // 最近 20 筆詳細記錄
    buf.writeln('【最近 ${records.take(20).length} 筆記錄】');
    for (final r in records.take(20)) {
      buf.writeln('─────────────────────');
      buf.writeln('  時間：${_dateFmt.format(r.timestamp)}');
      if (r.systolic != null) buf.writeln('  血壓：${r.systolic}/${r.diastolic} mmHg');
      if (r.heartRate != null) buf.writeln('  心率：${r.heartRate} bpm');
      if (r.spo2 != null) buf.writeln('  血氧：${r.spo2!.toStringAsFixed(1)}%');
      if (r.weight != null) buf.writeln('  體重：${r.weight!.toStringAsFixed(1)} kg');
      if (r.notes != null) buf.writeln('  備註：${r.notes}');
    }

    buf.writeln('═══════════════════════════════════');
    buf.writeln('此報告由「健康監測 App」自動產生，供參考用途。');

    final path = await _writeTempFile(
      content: buf.toString(),
      filename: 'health_summary_${DateFormat("yyyyMMdd").format(DateTime.now())}.txt',
    );

    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/plain')],
      subject: '健康摘要報告',
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static Future<String> _writeTempFile({
    required String content,
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static String _sourceLabel(String source) {
    switch (source) {
      case 'bluetooth': return '藍芽裝置';
      case 'camera': return '相機測量';
      case 'manual': return '手動輸入';
      default: return source;
    }
  }
}
