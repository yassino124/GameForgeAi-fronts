import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Enhanced
  static const Color primary = Color(0xFF6366F1);      // Indigo
  static const Color primaryLight = Color(0xFF818CF8);  
  static const Color primaryDark = Color(0xFF4F46E5);   
  
  // Secondary Colors - Enhanced
  static const Color secondary = Color(0xFFEC4899);     // Fuchsia (Web Match)
  static const Color secondaryLight = Color(0xFFF472B6);
  static const Color secondaryDark = Color(0xFFDB2777);

  // Surface Colors - Enhanced
  static const Color surface = Color(0xFF0D0E14);       // Darker Surface
  static const Color surfaceLight = Color(0xFF161821);  // Lighter Surface
  static const Color surfaceDark = Color(0xFF05060A);    // Darkest Surface
  static const Color surfaceBorder = Color(0xFF1E293B);  // Web-like border color
  
  static const Color background = Color(0xFF05060A);     // Deeper Black Background (Web Match)
  static const Color backgroundLight = Color(0xFF0D0E14); // Very Dark Navy
  static const Color backgroundDark = Color(0xFF020204);  // Absolute Black

  // Legacy Compatibility
  static const Color backgroundGradientLight = Color(0xFF0D0E14);
  static const Color backgroundGradientDark = Color(0xFF05060A);

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

  static const Color border = Color(0xFF1E293B);          // Web-like border color
  static const Color borderLight = Color(0xFF334155);     
  static const Color divider = Color(0xFF0F172A);         
  static const Color outline = Color(0xFF475569);         

  static const LinearGradient PrimaryGradient = LinearGradient(
    colors: [primary, Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient SecondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ChromaticGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient BackgroundGradient = LinearGradient(
    colors: [background, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient SurfaceGradient = LinearGradient(
    colors: [surface, surfaceLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy Aliases
  static const LinearGradient primaryGradient = PrimaryGradient;
  static const LinearGradient secondaryGradient = SecondaryGradient;
  static const LinearGradient chromaticGradient = ChromaticGradient;
  static const LinearGradient backgroundGradient = BackgroundGradient;
  static const LinearGradient surfaceGradient = SurfaceGradient;

  // Opacity Variants
  static Color primaryWithOpacity(double opacity) => primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) => secondary.withOpacity(opacity);
  static Color accentWithOpacity(double opacity) => accent.withOpacity(opacity);
  static Color successWithOpacity(double opacity) => success.withOpacity(opacity);
  static Color errorWithOpacity(double opacity) => error.withOpacity(opacity);
}
