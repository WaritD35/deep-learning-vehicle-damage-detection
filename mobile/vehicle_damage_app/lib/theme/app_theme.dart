/// App theme configuration

import 'package:flutter/material.dart';

class AppTheme {
  // Bright brand colors
  static const Color primaryColor = Color(0xFF5061C8);
  static const Color secondaryColor = Color(0xFF6D7BE0);
  static const Color successColor = Color(0xFF22C55E);  // Bright green
  static const Color warningColor = Color(0xFFFBBF24);  // Bright yellow
  static const Color errorColor = Color(0xFFF87171);  // Bright red
  static const Color backgroundColor = Color(0xFFEAF3FA);
  static const Color surfaceColor = Colors.white;
  
  // Damage type colors - brighter
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
  
  // Severity colors - brighter
  static const Map<String, Color> severityColors = {
    'severe': Color(0xFFF87171),
    'moderate': Color(0xFFFBBF24),
    'minor': Color(0xFFFDE047),
    'none': Color(0xFF4ADE80),
  };

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      useMaterial3: true,
      fontFamily: 'Poppins',
      
      // App bar theme - bright
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
      
      // Card theme - bright white with soft shadow
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      
      // Button themes - vibrant
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input decoration theme - clean and bright
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
      ),
      
      // Chip theme - bright
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade100,
        thickness: 1,
        space: 1,
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      
      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: Color(0xFF64748B),
      ),
      
      // Text theme - darker text for better contrast on bright bg
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        bodyLarge: TextStyle(
          color: Color(0xFF334155),
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF475569),
        ),
        bodySmall: TextStyle(
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: 'Poppins',
      
      // App bar theme
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
      
      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// Get color for damage type
  static Color getDamageColor(String damageType) {
    return damageColors[damageType.toLowerCase()] ?? Colors.grey;
  }
  
  /// Get color for severity level
  static Color getSeverityColor(String severity) {
    return severityColors[severity.toLowerCase()] ?? Colors.grey;
  }
  
  /// Get icon for damage type
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
