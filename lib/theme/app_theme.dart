import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static bool _isLight = PlatformDispatcher.instance.platformBrightness == Brightness.light;
  static void update(bool isLight) => _isLight = isLight;

  static Color get bg => _isLight ? const Color(0xFFF2F2F7) : const Color(0xFF0A0A12);
  static Color get s1 => _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF12121E);
  static Color get s2 => _isLight ? const Color(0xFFF8F8FC) : const Color(0xFF1A1A2E);
  static Color get s3 => _isLight ? const Color(0xFFE4E4ED) : const Color(0xFF252540);
  static Color get s4 => _isLight ? const Color(0xFFD0D0DF) : const Color(0xFF32325A);
  
  static Color get txt => _isLight ? const Color(0xFF0F0F1C) : const Color(0xFFF0F0FF);
  static Color get txt2 => _isLight ? const Color(0xFF3A3A52) : const Color(0xFFC8C8E8);
  static Color get txt3 => _isLight ? const Color(0xFF7A7A96) : const Color(0xFF8888AA);
  static Color get txt4 => _isLight ? const Color(0xFFA0A0B8) : const Color(0xFF555577);

  static Color get white10 => _isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.1);
  static Color get white08 => _isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.08);
  static Color get white70 => _isLight ? Colors.black87 : Colors.white70;
  static Color get white54 => _isLight ? Colors.black54 : Colors.white54;
  static Color get white38 => _isLight ? Colors.black38 : Colors.white.withValues(alpha: 0.38);
  
  static Color get neon => _isLight ? const Color(0xFF7C3AED) : const Color(0xFFA855F7);
  static Color get neon2 => _isLight ? const Color(0xFF0284C7) : const Color(0xFF06B6D4);
  static Color get neon3 => _isLight ? const Color(0xFF059669) : const Color(0xFF10B981);
  static Color get hot => _isLight ? const Color(0xFFE11D48) : const Color(0xFFFF3B6B);
  static Color get gold => _isLight ? const Color(0xFFD97706) : const Color(0xFFF59E0B);

  static LinearGradient get grad1 => LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [neon, neon2],
  );
  static LinearGradient get grad2 => LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [hot, gold],
  );
  static LinearGradient get grad3 => LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [neon3, neon2],
  );
  static LinearGradient get grad4 => LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [hot, neon],
  );

  static Color scoreColor(int s) => s >= 70 ? neon : s >= 40 ? gold : hot;
  static Color scoreColor2(int s) => s >= 70 ? neon2 : s >= 40 ? gold : (_isLight ? const Color(0xFFF43F5E) : const Color(0xFFFF6B8A));
  static LinearGradient scoreGrad(int s) => LinearGradient(colors: [scoreColor(s), scoreColor2(s)]);

  static bool get isLightMode => _isLight;
}

class AppText {
  static TextStyle grotesk({double sz = 14, FontWeight w = FontWeight.w600, Color? c, double? ls}) =>
      GoogleFonts.spaceGrotesk(fontSize: sz, fontWeight: w, color: c ?? AppColors.txt, letterSpacing: ls);
  static TextStyle jakarta({double sz = 14, FontWeight w = FontWeight.w500, Color? c, double? ls, double? h}) =>
      GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c ?? AppColors.txt, letterSpacing: ls, height: h);
}

class AppTheme {
  static ThemeData buildTheme({required bool isLight}) {
    AppColors.update(isLight);
    return ThemeData(
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme(
        brightness: isLight ? Brightness.light : Brightness.dark,
        primary: AppColors.neon, onPrimary: Colors.white,
        secondary: AppColors.neon2, onSecondary: Colors.white,
        error: AppColors.hot, onError: Colors.white,
        surface: AppColors.bg, onSurface: AppColors.txt,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme
      ).apply(
        bodyColor: AppColors.txt, displayColor: AppColors.txt,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg.withValues(alpha: 0.9), elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.txt, letterSpacing: -0.3),
        iconTheme: IconThemeData(color: AppColors.txt3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.s2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.s3)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.s3)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.neon, width: 1.5)),
        hintStyle: TextStyle(color: AppColors.txt3, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerColor: AppColors.s3, cardColor: AppColors.s1,
    );
  }
}
