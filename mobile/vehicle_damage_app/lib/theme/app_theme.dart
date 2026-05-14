// App theme configuration

import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primaryColor = Color(0xFF5061C8);
  static const Color secondaryColor = Color(0xFF6D7BE0);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color errorColor = Color(0xFFF87171);
  static const Color backgroundColor = Color(0xFFEAF3FA);
  static const Color surfaceColor = Colors.white;

  // Dark mode palette
  static const Color _darkBg = Color(0xFF0B1220);
  static const Color _darkSurface = Color(0xFF131D33);
  static const Color _darkCard = Color(0xFF1E2A3D);

  // Damage type colors
  static const Map<String, Color> damageColors = {
    'dent': Color(0xFFFF6B6B),
    'scratch': Color(0xFF51CF66),
    'crack': Color(0xFF339AF0),
    'glass shatter': Color(0xFFFFE066),
    'glass_shatter': Color(0xFFFFE066),
    'lamp broken': Color(0xFFCC5DE8),
    'lamp_broken': Color(0xFFCC5DE8),
    'tire flat': Color(0xFF22D3EE),
    'tire_flat': Color(0xFF22D3EE),
  };

  // Severity colors
  static const Map<String, Color> severityColors = {
    'severe': Color(0xFFF87171),
    'moderate': Color(0xFFFBBF24),
    'minor': Color(0xFFFDE047),
    'none': Color(0xFF4ADE80),
  };

  /// Returns the standard inner-card / soft-block background colour for the
  /// current brightness: light lavender in light mode, dark navy in dark mode.
  static Color cardSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkCard
        : const Color(0xFFF4F3FB);
  }

  /// Returns a readable secondary text colour for the current brightness.
  static Color subtitleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
  }

  /// Returns a modal / dialog surface colour for the current brightness.
  static Color modalSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkSurface
        : Colors.white;
  }

  // ─── Light theme ────────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      useMaterial3: true,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade100,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryColor),
      iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        titleSmall: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        bodyLarge: TextStyle(color: Color(0xFF334155)),
        bodyMedium: TextStyle(color: Color(0xFF475569)),
        bodySmall: TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }

  // ─── Dark theme ─────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: _darkSurface,
        onSurface: const Color(0xFFE2E8F0),
      ),
      scaffoldBackgroundColor: _darkBg,
      useMaterial3: true,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: secondaryColor,
          side: const BorderSide(color: secondaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          foregroundColor: secondaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        filled: true,
        fillColor: _darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkCard,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFFCBD5E1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.10),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryColor),
      iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF1F5F9)),
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF1F5F9)),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
        titleSmall: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
        bodyLarge: TextStyle(color: Color(0xFFCBD5E1)),
        bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
        bodySmall: TextStyle(color: Color(0xFF94A3B8)),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static Color getDamageColor(String damageType) =>
      damageColors[damageType.toLowerCase()] ?? Colors.grey;

  static Color getSeverityColor(String severity) =>
      severityColors[severity.toLowerCase()] ?? Colors.grey;

  /// Readable foreground for severity chips (label + icon).
  static Color severityChipForeground(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return const Color(0xFFB91C1C);
      case 'moderate':
        return const Color(0xFFB45309);
      case 'minor':
        return const Color(0xFF854D0E);
      case 'none':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF475569);
    }
  }

  static IconData getDamageIcon(String damageType) {
    switch (damageType.toLowerCase()) {
      case 'dent':
        return Icons.car_crash;
      case 'scratch':
        return Icons.format_paint;
      case 'crack':
        return Icons.broken_image;
      case 'glass shatter':
      case 'glass_shatter':
        return Icons.window;
      case 'lamp broken':
      case 'lamp_broken':
        return Icons.lightbulb_outline;
      case 'tire flat':
      case 'tire_flat':
        return Icons.tire_repair;
      default:
        return Icons.warning;
    }
  }
}
