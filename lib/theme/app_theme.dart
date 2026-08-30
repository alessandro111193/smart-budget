import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF16B98C); // verde smeraldo
  static const Color secondary = Color(0xFF2563EB); // blu
  static const Color accent = Color(0xFF8B5CF6); // viola
  static const Color warning = Color(0xFFF59E0B); // arancio
  static const Color danger = Color(0xFFEF4444); // rosso
  static const Color neutral = Color(0xFF64748B); // grigio
  static const Color ink = Color(0xFF0F172A);
  static const List<Color> envelopeColors = [
    Color(0xFF16B98C), // verde
    Color(0xFF2563EB), // blu
    Color(0xFFF59E0B), // arancio
    Color(0xFF8B5CF6), // viola
    Color(0xFFEF4444), // rosso
  ];
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme(),
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );
  }
}
