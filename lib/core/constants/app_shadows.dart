import 'package:flutter/material.dart';

class AppShadows {
  // Shadow Values
  static const Shadow small = Shadow(
    color: Color.fromRGBO(0, 0, 0, 0.12),
    offset: Offset(0, 1),
    blurRadius: 3,
  );

  static const Shadow medium = Shadow(
    color: Color.fromRGBO(0, 0, 0, 0.16),
    offset: Offset(0, 4),
    blurRadius: 6,
  );

  static const Shadow large = Shadow(
    color: Color.fromRGBO(0, 0, 0, 0.20),
    offset: Offset(0, 10),
    blurRadius: 15,
  );

  // Glow Effects
  static const Shadow primaryGlow = Shadow(
    color: Color.fromRGBO(99, 102, 241, 0.3),
    offset: Offset(0, 0),
    blurRadius: 20,
  );

  static const Shadow accentGlow = Shadow(
    color: Color.fromRGBO(6, 182, 212, 0.3),
    offset: Offset(0, 0),
    blurRadius: 20,
  );

  // Box Shadow for Containers
  static List<BoxShadow> get boxShadowSmall => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  static List<BoxShadow> get boxShadowMedium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      offset: const Offset(0, 4),
      blurRadius: 6,
    ),
  ];

  static List<BoxShadow> get boxShadowLarge => [
    BoxShadow(
      color: Colors.black.withOpacity(0.20),
      offset: const Offset(0, 10),
      blurRadius: 15,
    ),
  ];

  static List<BoxShadow> get boxShadowPrimaryGlow => [
    BoxShadow(
      color: const Color(0xFF6366F1).withOpacity(0.3),
      offset: const Offset(0, 0),
      blurRadius: 20,
    ),
  ];

  static List<BoxShadow> get boxShadowAccentGlow => [
    BoxShadow(
      color: const Color(0xFF06B6D4).withOpacity(0.3),
      offset: const Offset(0, 0),
      blurRadius: 20,
    ),
  ];

  // Custom Box Shadow
  static List<BoxShadow> custom({
    Color color = Colors.black,
    double opacity = 0.16,
    Offset offset = const Offset(0, 4),
    double blurRadius = 6,
  }) => [
    BoxShadow(
      color: color.withOpacity(opacity),
      offset: offset,
      blurRadius: blurRadius,
    ),
  ];
}
