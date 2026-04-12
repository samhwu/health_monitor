// lib/services/pedometer_service.dart

import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.sensors.request();
      return status.isGranted;
    }
    return false;
  }

  Stream<StepCount> get stepCountStream {
    _stepCountStream ??= Pedometer.stepCountStream;
    return _stepCountStream!;
  }

  Stream<PedestrianStatus> get pedestrianStatusStream {
    _pedestrianStatusStream ??= Pedometer.pedestrianStatusStream;
    return _pedestrianStatusStream!;
  }
}
