import 'package:flutter/material.dart';

class AppBorderRadius {
  // Border Radius Values
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double xlarge = 24;
  static const double full = 50; // For circles

  // Border Radius Helpers
  static const BorderRadius allSmall = BorderRadius.all(Radius.circular(small));
  static const BorderRadius allMedium = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius allLarge = BorderRadius.all(Radius.circular(large));
  static const BorderRadius allXLarge = BorderRadius.all(Radius.circular(xlarge));
  static const BorderRadius circular = BorderRadius.all(Radius.circular(full));

  // Custom Border Radius
  static BorderRadius only({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
  }) => BorderRadius.only(
    topLeft: Radius.circular(topLeft),
    topRight: Radius.circular(topRight),
    bottomLeft: Radius.circular(bottomLeft),
    bottomRight: Radius.circular(bottomRight),
  );

  static BorderRadius circularCustom(double radius) => BorderRadius.all(Radius.circular(radius));

  // Directional Border Radius
  static const BorderRadius top = BorderRadius.vertical(
    top: Radius.circular(large),
  );

  static const BorderRadius bottom = BorderRadius.vertical(
    bottom: Radius.circular(large),
  );

  static const BorderRadius left = BorderRadius.horizontal(
    left: Radius.circular(large),
  );

  static const BorderRadius right = BorderRadius.horizontal(
    right: Radius.circular(large),
  );
}
