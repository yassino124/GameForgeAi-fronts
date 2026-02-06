import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Enhanced
  static const Color primary = Color(0xFF6366F1);      // Modern Indigo
  static const Color primaryLight = Color(0xFF818CF8);  // Lighter Indigo
  static const Color primaryDark = Color(0xFF4F46E5);   // Darker Indigo
  
  // Secondary Colors - Enhanced
  static const Color secondary = Color(0xFF10B981);     // Modern Emerald
  static const Color secondaryLight = Color(0xFF34D399); // Lighter Emerald
  static const Color secondaryDark = Color(0xFF059669);  // Darker Emerald

  // Surface Colors - Enhanced
  static const Color surface = Color(0xFF1F2937);       // Dark Gray Surface
  static const Color surfaceLight = Color(0xFF374151);  // Lighter Surface
  static const Color surfaceDark = Color(0xFF111827);    // Darker Surface
  
  // Background Colors - Enhanced
  static const Color background = Color(0xFF0F172A);     // Rich Dark Background
  static const Color backgroundLight = Color(0xFF1E293B); // Lighter Background

  // Text Colors - Enhanced
  static const Color textPrimary = Color(0xFFF9FAFB);    // Near White
  static const Color textSecondary = Color(0xFF9CA3AF);  // Medium Gray
  static const Color textTertiary = Color(0xFF6B7280);   // Darker Gray
  static const Color textDisabled = Color(0xFF4B5563);  // Disabled Text

  // Accent Colors - Enhanced
  static const Color accent = Color(0xFFA78BFA);          // Purple Accent
  static const Color accentLight = Color(0xFFC4B5FD);     // Light Accent
  static const Color accentDark = Color(0xFF7C3AED);      // Dark Accent
  
  // Surface Variants
  static const Color surfaceVariant = Color(0xFF2D3748);  // Surface Variant
  static const Color textOnSurface = Color(0xFFE2E8F0);   // Text on Surface

  // Status Colors - Enhanced
  static const Color success = Color(0xFF10B981);         // Success Green
  static const Color successLight = Color(0xFF34D399);    // Light Success
  static const Color warning = Color(0xFFF59E0B);         // Warning Amber
  static const Color warningLight = Color(0xFFFCD34D);    // Light Warning
  static const Color error = Color(0xFFEF4444);           // Error Red
  static const Color errorLight = Color(0xFFF87171);      // Light Error
  static const Color info = Color(0xFF3B82F6);            // Info Blue
  static const Color infoLight = Color(0xFF60A5FA);       // Light Info

  // Border & Divider Colors - Enhanced
  static const Color border = Color(0xFF374151);          // Subtle Border
  static const Color borderLight = Color(0xFF4B5563);     // Lighter Border
  static const Color divider = Color(0xFF1F2937);         // Divider Color
  static const Color outline = Color(0xFF6B7280);         // Outline Color

  // Gradient Colors - Enhanced
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Opacity Variants
  static Color primaryWithOpacity(double opacity) => primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) => secondary.withOpacity(opacity);
  static Color accentWithOpacity(double opacity) => accent.withOpacity(opacity);
  static Color successWithOpacity(double opacity) => success.withOpacity(opacity);
  static Color errorWithOpacity(double opacity) => error.withOpacity(opacity);
}
