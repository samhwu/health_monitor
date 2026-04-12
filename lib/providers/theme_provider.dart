import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { modernTech, warmService, calmMedical }

class ThemeProvider with ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.modernTech;

  AppThemeType get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme_index') ?? 0;
    _currentTheme = AppThemeType.values[themeIndex];
    notifyListeners();
  }

  Future<void> setTheme(AppThemeType type) async {
    _currentTheme = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_index', type.index);
    notifyListeners();
  }

  String get themeName {
    switch (_currentTheme) {
      case AppThemeType.modernTech: return '現代科技';
      case AppThemeType.warmService: return '溫馨服務';
      case AppThemeType.calmMedical: return '平靜醫療';
    }
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppThemeType.modernTech:
        return _buildModernTech();
      case AppThemeType.warmService:
        return _buildWarmService();
      case AppThemeType.calmMedical:
        return _buildCalmMedical();
    }
  }

  ThemeData _buildModernTech() {
    return _baseTheme(
      brightness: Brightness.dark,
      seedColor: const Color(0xFF0A84FF),
      scaffoldBg: const Color(0xFF0C0C0E),
      cardBg: const Color(0xFF1C1C1E),
      accentColor: const Color(0xFF0A84FF),
    );
  }

  ThemeData _buildWarmService() {
    return _baseTheme(
      brightness: Brightness.light,
      seedColor: const Color(0xFFFF9500),
      scaffoldBg: const Color(0xFFFFF9F2),
      cardBg: Colors.white,
      accentColor: const Color(0xFFFF9500),
      textColor: const Color(0xFF4A4A4A),
    );
  }

  ThemeData _buildCalmMedical() {
    return _baseTheme(
      brightness: Brightness.light,
      seedColor: const Color(0xFF32ADE6),
      scaffoldBg: const Color(0xFFF2F7F9),
      cardBg: Colors.white,
      accentColor: const Color(0xFF007AFF),
      textColor: const Color(0xFF2C3E50),
    );
  }

  ThemeData _baseTheme({
    required Brightness brightness,
    required Color seedColor,
    required Color scaffoldBg,
    required Color cardBg,
    required Color accentColor,
    Color? textColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : (textColor ?? Colors.black87);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        surface: cardBg,
        onSurface: defaultTextColor,
        primary: accentColor,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: GoogleFonts.notoSansTcTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: defaultTextColor, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: defaultTextColor, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: defaultTextColor.withValues(alpha: 0.8)),
          bodyMedium: TextStyle(color: defaultTextColor.withValues(alpha: 0.6)),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black12,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansTc(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: defaultTextColor,
        ),
        iconTheme: IconThemeData(color: defaultTextColor),
      ),
    );
  }
}
