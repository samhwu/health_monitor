// lib/screens/camera_measurement_screen.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/camera_health_service.dart';
import '../database/health_database.dart';
import '../models/health_record.dart';

class CameraMeasurementScreen extends StatefulWidget {
  const CameraMeasurementScreen({super.key});

  @override
  State<CameraMeasurementScreen> createState() => _CameraMeasurementScreenState();
}

class _CameraMeasurementScreenState extends State<CameraMeasurementScreen>
    with TickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  StreamSubscription? _resultSub;
  StreamSubscription? _hrSub;
  CameraHealthResult? _lastResult;
  double? _currentHR;
  bool _saved = false;

  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnim;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _heartbeatAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _initCameras();
    _subscribeEvents();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    setState(() {});
  }

  void _subscribeEvents() {
    final svc = context.read<CameraHealthService>();
    _resultSub = svc.resultStream.listen(_onResult);
    _hrSub = svc.hrRealtimeStream.listen((hr) {
      setState(() => _currentHR = hr);
    });
  }

  void _onResult(CameraHealthResult result) {
    setState(() {
      _lastResult = result;
      _saved = false;
    });
  }

  Future<void> _startMeasurement() async {
    final svc = context.read<CameraHealthService>();
    setState(() { _lastResult = null; _currentHR = null; _saved = false; });
    await svc.startMeasurement(_cameras);
  }

  Future<void> _stopMeasurement() async {
    final svc = context.read<CameraHealthService>();
    await svc.stopMeasurement();
  }

  Future<void> _saveResult() async {
    if (_lastResult == null) return;
    final db = context.read<HealthDatabase>();
    final record = HealthRecord(
      timestamp: DateTime.now(),
      heartRate: _lastResult!.heartRate.round(),
      spo2: _lastResult!.spo2,
      source: 'camera',
      notes: '相機測量 (rPPG) 信心度: ${(_lastResult!.confidence * 100).toStringAsFixed(0)}%',
    );
    await db.insertRecord(record);
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 已儲存到資料庫'), backgroundColor: Color(0xFF30D158)),
    );
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _hrSub?.cancel();
    _heartbeatController.dispose();
    _waveController.dispose();
    context.read<CameraHealthService>().stopMeasurement();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('影像心率測量', style: GoogleFonts.notoSansTc(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: Consumer<CameraHealthService>(
        builder: (_, svc, __) {
          return Column(
            children: [
              _buildInstructions(),
              Expanded(child: _buildCameraView(svc)),
              _buildBottomPanel(svc),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF0A84FF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '請用手指輕輕覆蓋後置鏡頭，保持靜止約 30 秒',
              style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(CameraHealthService svc) {
    final controller = svc.cameraController;
    final isRunning = svc.isRunning;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview
        if (controller != null && controller.value.isInitialized)
          SizedBox.expand(
            child: CameraPreview(controller),
          )
        else
          Container(
            color: const Color(0xFF0D0D0D),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_rounded, size: 60, color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('相機未啟動', style: GoogleFonts.notoSansTc(color: Theme.of(context).disabledColor)),
                ],
              ),
            ),
          ),

        // Red overlay during measurement (simulates finger on lens)
        if (isRunning && controller != null)
          Container(
            color: Colors.red.withOpacity(0.15),
          ),

        // Center crosshair / finger guide
        if (!isRunning && _lastResult == null)
          _buildFingerGuide(),

        // Real-time HR display during measurement
        if (isRunning && _currentHR != null)
          _buildRealtimeHROverlay(),

        // Progress overlay
        if (isRunning)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildProgressOverlay(svc),
          ),

        // Result overlay
        if (_lastResult != null)
          _buildResultOverlay(_lastResult!),
      ],
    );
  }

  Widget _buildFingerGuide() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _waveController,
          builder: (_, __) => Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Opacity(
                  opacity: (1 - (_waveController.value + i / 3) % 1.0) * 0.4,
                  child: Container(
                    width: 100 + ((_waveController.value + i / 3) % 1.0) * 60,
                    height: 100 + ((_waveController.value + i / 3) % 1.0) * 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Icon(Icons.fingerprint_rounded, color: Theme.of(context).disabledColor, size: 40),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '將手指放在這裡',
          style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRealtimeHROverlay() {
    return AnimatedBuilder(
      animation: _heartbeatAnim,
      builder: (_, __) => Transform.scale(
        scale: _heartbeatAnim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFFFF453A), size: 20),
              const SizedBox(width: 8),
              Text(
                '${_currentHR!.round()} bpm',
                style: GoogleFonts.notoSansTc(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverlay(CameraHealthService svc) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: svc.progress,
                  backgroundColor: Colors.white24,
                  color: svc.sessionState == CameraSessionState.calibrating
                      ? const Color(0xFFFF9F0A)
                      : const Color(0xFF30D158),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(svc.progress * 100).toInt()}%',
              style: GoogleFonts.notoSansTc(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          svc.statusMessage,
          style: GoogleFonts.notoSansTc(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResultOverlay(CameraHealthResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('測量結果', style: GoogleFonts.notoSansTc(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResultItem(
                icon: Icons.favorite_rounded,
                color: const Color(0xFFFF453A),
                value: '${result.heartRate.round()}',
                unit: 'bpm',
                label: '心率',
              ),
              if (result.spo2 != null)
                _ResultItem(
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF0A84FF),
                  value: result.spo2!.toStringAsFixed(1),
                  unit: '%',
                  label: '血氧',
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Confidence bar
          Row(
            children: [
              Text('信心度：', style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    backgroundColor: Colors.white12,
                    color: result.confidence > 0.7
                        ? const Color(0xFF30D158)
                        : result.confidence > 0.4
                            ? const Color(0xFFFF9F0A)
                            : const Color(0xFFFF453A),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(result.confidence * 100).toInt()}%',
                style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.status,
            style: GoogleFonts.notoSansTc(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(CameraHealthService svc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (_lastResult != null && !_saved) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startMeasurement,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('重測', style: GoogleFonts.notoSansTc()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).disabledColor,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saveResult,
                icon: const Icon(Icons.save_rounded),
                label: Text('儲存到資料庫', style: GoogleFonts.notoSansTc(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else if (svc.isRunning) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopMeasurement,
                icon: const Icon(Icons.stop_rounded),
                label: Text('停止測量', style: GoogleFonts.notoSansTc()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF453A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cameras.isEmpty ? null : _startMeasurement,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('開始測量', style: GoogleFonts.notoSansTc(fontWeight: FontWeight.w600, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  final String label;

  const _ResultItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.notoSansTc(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.notoSansTc(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ],
          ),
        ),
        Text(label, style: GoogleFonts.notoSansTc(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
