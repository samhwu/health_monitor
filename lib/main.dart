// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/db_config.dart';

import 'services/bluetooth_service.dart';
import 'services/camera_health_service.dart';
import 'database/health_database.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'providers/health_provider.dart';
import 'providers/step_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 視窗全螢幕顯示 (僅限桌面平台)
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        fullScreen: true,
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
    
    // 初始化資料庫 (原生平台的 FFI)
    setupDatabase();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider(create: (_) => HealthDatabase()),
          ChangeNotifierProxyProvider<HealthDatabase, HealthProvider>(
            create: (ctx) => HealthProvider(ctx.read<HealthDatabase>()),
            update: (_, db, prev) => prev ?? HealthProvider(db),
          ),
          ChangeNotifierProvider(create: (_) => HealthBluetoothService()),
          ChangeNotifierProvider(create: (_) => CameraHealthService()),
          ChangeNotifierProxyProvider<HealthDatabase, StepProvider>(
            create: (ctx) => StepProvider(ctx.read<HealthDatabase>()),
            update: (_, db, prev) => prev ?? StepProvider(db),
          ),
        ],
        child: const HealthMonitorApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Fatal error: $error\n$stack');
  });
}

class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '健康監測',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: const LoginScreen(),
    );
  }
}
