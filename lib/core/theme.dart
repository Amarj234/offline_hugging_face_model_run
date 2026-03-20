import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF0A0B1E);
  static const Color surface = Color(0xFF1D1F3E);
  static const Color accentPrimary = Color(0xFF00D2FF);
  static const Color accentSecondary = Color(0xFF9D50BB);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color.fromARGB(255, 131, 136, 224)
        : Colors.white;
    final surfaceColor = isDark
        ? const Color.fromARGB(255, 143, 149, 231)
        : Colors.grey[100]!;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: baseColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentPrimary,
        brightness: brightness,
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: surfaceColor,
        background: baseColor,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: isDark ? textPrimary : Colors.black87,
        displayColor: isDark ? textPrimary : Colors.black87,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? textPrimary : Colors.black87,
        ),
        iconTheme: IconThemeData(color: isDark ? textPrimary : Colors.black87),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: isDark ? textSecondary : Colors.black45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}
