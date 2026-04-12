// lib/services/camera_health_service.dart
//
// rPPG (remote Photoplethysmography) 演算法
// ─────────────────────────────────────────
// 原理：手指按住鏡頭 + 閃光燈，透過分析連續幀的平均
//       紅色通道強度變化（對應血液流動時吸光度的週期性改變）
//       來估算心率 (HR) 及血氧飽和度 (SpO2)。
//
// SpO2 估算使用 Beer-Lambert 比率：R = (AC_red/DC_red) / (AC_ir/DC_ir)
//   對於手機相機，以 red channel 近似 660nm，green channel 近似 IR。
//
// 注意：此為估算方法，非醫療級裝置，僅供參考。

import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

// ─── Result ──────────────────────────────────────────────────────────────────

class CameraHealthResult {
  final double heartRate;
  final double? spo2;
  final double confidence;   // 0.0 ~ 1.0
  final String status;

  const CameraHealthResult({
    required this.heartRate,
    this.spo2,
    required this.confidence,
    required this.status,
  });
}

enum CameraSessionState {
  idle,
  calibrating,   // 等待手指放好（前2秒）
  measuring,     // 測量中
  processing,    // 計算結果
  done,
  error,
}

// ─── Signal Buffer ────────────────────────────────────────────────────────────

class _FrameSample {
  final double red;
  final double green;
  final double blue;
  final int timestamp; // milliseconds

  const _FrameSample({
    required this.red,
    required this.green,
    required this.blue,
    required this.timestamp,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class CameraHealthService extends ChangeNotifier {
  CameraController? _cameraController;
  CameraSessionState _sessionState = CameraSessionState.idle;
  double _progress = 0.0;           // 0.0 ~ 1.0
  double? _realtimeHR;
  String _statusMessage = '';
  String? _errorMessage;

  static const int _measurementSeconds = 30;
  static const int _calibrationSeconds = 3;
  static const int _sampleRateHz = 30;

  final List<_FrameSample> _samples = [];
  Timer? _progressTimer;
  Timer? _processingTimer;
  int _frameCount = 0;
  int _sessionStartMs = 0;

  final _resultController = StreamController<CameraHealthResult>.broadcast();
  final _hrRealtimeController = StreamController<double>.broadcast();

  CameraSessionState get sessionState => _sessionState;
  double get progress => _progress;
  double? get realtimeHR => _realtimeHR;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  Stream<CameraHealthResult> get resultStream => _resultController.stream;
  Stream<double> get hrRealtimeStream => _hrRealtimeController.stream;

  bool get isRunning =>
      _sessionState == CameraSessionState.calibrating ||
      _sessionState == CameraSessionState.measuring;

  // ─── Start/Stop ──────────────────────────────────────────────────────────

  Future<void> startMeasurement(List<CameraDescription> cameras) async {
    if (isRunning) return;
    _samples.clear();
    _frameCount = 0;
    _errorMessage = null;

    try {
      // 優先使用後置相機
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.low,     // 低解析度省電省運算
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // 開啟閃光燈（模擬 IR 光源）
      try {
        await _cameraController!.setFlashMode(FlashMode.torch);
      } catch (_) {
        // 部分裝置不支援 torch
      }

      _setState(CameraSessionState.calibrating);
      _statusMessage = '請將手指輕輕覆蓋鏡頭...';
      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;

      // 開始串流影像幀
      await _cameraController!.startImageStream(_processFrame);

      // 進度計時器
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        final elapsed = (DateTime.now().millisecondsSinceEpoch - _sessionStartMs) / 1000.0;
        final total = (_calibrationSeconds + _measurementSeconds).toDouble();

        _progress = (elapsed / total).clamp(0.0, 1.0);

        if (elapsed < _calibrationSeconds) {
          _statusMessage = '準備中... ${(_calibrationSeconds - elapsed).ceil()} 秒';
          _setState(CameraSessionState.calibrating);
        } else if (elapsed < total) {
          final remaining = (total - elapsed).ceil();
          _statusMessage = '測量中，請保持靜止... $remaining 秒';
          _setState(CameraSessionState.measuring);

          // 每 5 秒更新一次即時心率
          if (_samples.length >= 150) {
            _updateRealtimeHR();
          }
        } else {
          t.cancel();
          _finalizeMeasurement();
        }
      });
    } catch (e) {
      _setError('相機啟動失敗: $e');
    }
  }

  Future<void> stopMeasurement() async {
    _progressTimer?.cancel();
    _processingTimer?.cancel();
    try {
      await _cameraController?.setFlashMode(FlashMode.off);
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;
    _setState(CameraSessionState.idle);
    _statusMessage = '';
    _progress = 0;
  }

  // ─── Frame Processing ─────────────────────────────────────────────────────

  void _processFrame(CameraImage image) {
    _frameCount++;
    // 只取每隔 1 幀（降採樣到約 15fps 即可）
    if (_frameCount % 2 != 0) return;

    final elapsed = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
    if (elapsed < _calibrationSeconds * 1000) return; // 校準期間跳過

    try {
      final rgb = _extractRGBFromYUV(image);
      _samples.add(_FrameSample(
        red: rgb[0],
        green: rgb[1],
        blue: rgb[2],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (_) {}
  }

  /// 從 YUV420 影像中央 ROI 提取平均 RGB 值
  List<double> _extractRGBFromYUV(CameraImage image) {
    final width = image.width;
    final height = image.height;

    // 取中央 1/4 區域（手指覆蓋區）
    final roiX = width ~/ 4;
    final roiY = height ~/ 4;
    final roiW = width ~/ 2;
    final roiH = height ~/ 2;

    // YUV420 Plane 0 = Y, Plane 1 = U (Cb), Plane 2 = V (Cr)
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    double sumR = 0, sumG = 0, sumB = 0;
    int count = 0;

    for (int y = roiY; y < roiY + roiH; y += 4) {
      for (int x = roiX; x < roiX + roiW; x += 4) {
        final yIdx = y * yPlane.bytesPerRow + x;
        final uvIdx = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        if (yIdx >= yPlane.bytes.length || uvIdx >= uPlane.bytes.length) continue;

        final Y = yPlane.bytes[yIdx].toDouble();
        final U = uPlane.bytes[uvIdx].toDouble() - 128;
        final V = vPlane.bytes[uvIdx].toDouble() - 128;

        // YUV → RGB
        final r = (Y + 1.402 * V).clamp(0.0, 255.0);
        final g = (Y - 0.344 * U - 0.714 * V).clamp(0.0, 255.0);
        final b = (Y + 1.772 * U).clamp(0.0, 255.0);

        sumR += r; sumG += g; sumB += b;
        count++;
      }
    }

    if (count == 0) return [0, 0, 0];
    return [sumR / count, sumG / count, sumB / count];
  }

  // ─── Real-time HR Preview ─────────────────────────────────────────────────

  void _updateRealtimeHR() {
    final recent = _samples.length > 300 ? _samples.sublist(_samples.length - 300) : _samples;
    final hr = _computeHeartRate(recent);
    if (hr != null) {
      _realtimeHR = hr;
      _hrRealtimeController.add(hr);
      notifyListeners();
    }
  }

  // ─── Final Computation ────────────────────────────────────────────────────

  void _finalizeMeasurement() async {
    _progressTimer?.cancel();
    _setState(CameraSessionState.processing);
    _statusMessage = '計算結果中...';

    try {
      await _cameraController?.setFlashMode(FlashMode.off);
      await _cameraController?.stopImageStream();
    } catch (_) {}

    // 在背景執行計算（防止 UI 卡頓）
    _processingTimer = Timer(const Duration(milliseconds: 100), () async {
      final result = await compute(_computeHealthMetrics, _samples);

      if (result != null) {
        _resultController.add(result);
        _setState(CameraSessionState.done);
        _statusMessage = '測量完成！';
      } else {
        _setError('訊號品質不足，請重新測量');
      }

      try {
        await _cameraController?.dispose();
      } catch (_) {}
      _cameraController = null;
    });
  }

  // ─── DSP Algorithms (run in isolate) ─────────────────────────────────────

  static CameraHealthResult? _computeHealthMetrics(List<_FrameSample> samples) {
    if (samples.length < 50) return null;

    // Heart Rate via FFT on red channel
    final hr = _computeHeartRate(samples);
    if (hr == null) return null;

    // SpO2 via Ratio of Ratios
    final spo2 = _computeSpO2(samples);

    // Confidence based on signal quality
    final snr = _computeSNR(samples.map((s) => s.red).toList());
    final confidence = (snr / 20.0).clamp(0.0, 1.0);

    String status;
    if (confidence < 0.4) {
      status = '訊號品質低，請確保手指完整覆蓋鏡頭';
    } else if (confidence < 0.7) {
      status = '訊號品質中等';
    } else {
      status = '訊號品質良好';
    }

    return CameraHealthResult(
      heartRate: hr,
      spo2: spo2,
      confidence: confidence,
      status: status,
    );
  }

  static double? _computeHeartRate(List<_FrameSample> samples) {
    if (samples.length < 30) return null;

    // 1. 提取紅色通道信號並去除趨勢
    final signal = samples.map((s) => s.red).toList();
    final detrended = _detrend(signal);

    // 2. 計算採樣率（實際 FPS）
    final durationMs = samples.last.timestamp - samples.first.timestamp;
    final fps = samples.length / (durationMs / 1000.0);

    // 3. 帶通濾波 (0.7~3.5 Hz = 42~210 bpm)
    final filtered = _bandpassFilter(detrended, fps, 0.7, 3.5);

    // 4. FFT 找主頻率
    final dominantFreq = _findDominantFrequency(filtered, fps, 0.7, 3.5);
    if (dominantFreq == null) return null;

    return dominantFreq * 60.0; // Hz → bpm
  }

  /// SpO2 ≈ 110 - 25 × R   (empirical calibration formula)
  /// R = (AC_red/DC_red) / (AC_green/DC_green)
  static double? _computeSpO2(List<_FrameSample> samples) {
    if (samples.length < 50) return null;

    final redSignal = samples.map((s) => s.red).toList();
    final greenSignal = samples.map((s) => s.green).toList();

    final dcRed = redSignal.reduce((a, b) => a + b) / redSignal.length;
    final dcGreen = greenSignal.reduce((a, b) => a + b) / greenSignal.length;

    if (dcRed <= 0 || dcGreen <= 0) return null;

    final acRed = _computeRMS(_detrend(redSignal));
    final acGreen = _computeRMS(_detrend(greenSignal));

    if (acGreen <= 0 || dcGreen <= 0) return null;

    final R = (acRed / dcRed) / (acGreen / dcGreen);
    final spo2 = (110.0 - 25.0 * R).clamp(90.0, 100.0);

    return spo2;
  }

  // ─── Signal Processing Utilities ─────────────────────────────────────────

  static List<double> _detrend(List<double> signal) {
    final n = signal.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i; sumY += signal[i];
      sumXY += i * signal[i]; sumX2 += i * i.toDouble();
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    return List.generate(n, (i) => signal[i] - (slope * i + intercept));
  }

  static List<double> _bandpassFilter(
    List<double> signal,
    double fps,
    double lowFreq,
    double highFreq,
  ) {
    // 簡單移動平均帶通濾波
    final lowWindow = (fps / (2 * lowFreq)).round().clamp(1, signal.length ~/ 4);
    final highWindow = (fps / (2 * highFreq)).round().clamp(1, signal.length ~/ 8);

    List<double> lowpass(List<double> s, int w) {
      return List.generate(s.length, (i) {
        final start = math.max(0, i - w);
        final end = math.min(s.length, i + w + 1);
        final window = s.sublist(start, end);
        return window.reduce((a, b) => a + b) / window.length;
      });
    }

    final low = lowpass(signal, lowWindow);
    final high = lowpass(signal, highWindow);
    return List.generate(signal.length, (i) => low[i] - high[i]);
  }

  static double? _findDominantFrequency(
    List<double> signal,
    double fps,
    double minFreq,
    double maxFreq,
  ) {
    final n = signal.length;
    if (n < 4) return null;

    // DFT (Goertzel-like for relevant frequencies only)
    double maxMag = 0;
    double dominantFreq = 0;

    final minK = (minFreq * n / fps).ceil();
    final maxK = (maxFreq * n / fps).floor();

    for (int k = minK; k <= maxK; k++) {
      double real = 0, imag = 0;
      for (int t = 0; t < n; t++) {
        final angle = 2 * math.pi * k * t / n;
        real += signal[t] * math.cos(angle);
        imag -= signal[t] * math.sin(angle);
      }
      final mag = real * real + imag * imag;
      if (mag > maxMag) {
        maxMag = mag;
        dominantFreq = k * fps / n;
      }
    }

    return dominantFreq > 0 ? dominantFreq : null;
  }

  static double _computeRMS(List<double> signal) {
    if (signal.isEmpty) return 0;
    final sum = signal.fold(0.0, (acc, v) => acc + v * v);
    return math.sqrt(sum / signal.length);
  }

  static double _computeSNR(List<double> signal) {
    if (signal.length < 10) return 0;
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final variance = signal.fold(0.0, (acc, v) => acc + (v - mean) * (v - mean)) / signal.length;
    if (variance == 0) return 0;
    return 10 * math.log(mean * mean / variance) / math.ln10;
  }

  // ─── State Management ─────────────────────────────────────────────────────

  void _setState(CameraSessionState state) {
    _sessionState = state;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _sessionState = CameraSessionState.error;
    _statusMessage = message;
    notifyListeners();
  }

  CameraController? get cameraController => _cameraController;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _processingTimer?.cancel();
    _cameraController?.dispose();
    _resultController.close();
    _hrRealtimeController.close();
    super.dispose();
  }
}
