import 'package:flutter/material.dart';

class AppSpacing {
  // Base Unit: 4px
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  
  static const double large = 24;

  // Larger Spacing - More impressive
  static const double huge = 40;
  static const double massive = 48;
  static const double gigantic = 64;
  static const double enormous = 80;
  static const double colossal = 96;
  static const double titanic = 128;

  // Micro Spacing - More precise
  static const double micro = 2;
  static const double tiny = 1;

  // Padding Helpers - Enhanced
  static const EdgeInsets paddingAll = EdgeInsets.all(lg);
  static const EdgeInsets paddingSmall = EdgeInsets.all(sm);
  static const EdgeInsets paddingLarge = EdgeInsets.all(xxl);
  static const EdgeInsets paddingHuge = EdgeInsets.all(huge);
  static const EdgeInsets paddingMassive = EdgeInsets.all(massive);

  static const EdgeInsets paddingHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingVertical = EdgeInsets.symmetric(vertical: lg);
  
  static const EdgeInsets paddingHorizontalSmall = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingVerticalSmall = EdgeInsets.symmetric(vertical: sm);
  
  static const EdgeInsets paddingHorizontalLarge = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets paddingVerticalLarge = EdgeInsets.symmetric(vertical: xxl);

  static const EdgeInsets paddingHorizontalHuge = EdgeInsets.symmetric(horizontal: huge);
  static const EdgeInsets paddingVerticalHuge = EdgeInsets.symmetric(vertical: huge);

  // Margin Helpers - Enhanced
  static const EdgeInsets marginAll = EdgeInsets.all(lg);
  static const EdgeInsets marginSmall = EdgeInsets.all(sm);
  static const EdgeInsets marginLarge = EdgeInsets.all(xxl);
  static const EdgeInsets marginHuge = EdgeInsets.all(huge);

  static const EdgeInsets marginHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets marginVertical = EdgeInsets.symmetric(vertical: lg);
  
  static const EdgeInsets marginHorizontalSmall = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets marginVerticalSmall = EdgeInsets.symmetric(vertical: sm);
  
  static const EdgeInsets marginHorizontalLarge = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets marginVerticalLarge = EdgeInsets.symmetric(vertical: xxl);

  // Custom Spacing - More options
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => EdgeInsets.only(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );

  static EdgeInsets symmetric({
    double horizontal = 0,
    double vertical = 0,
  }) => EdgeInsets.symmetric(
    horizontal: horizontal,
    vertical: vertical,
  );

  // Responsive Spacing - For better layouts
  static double responsive(BuildContext context, double mobile, double tablet, double desktop) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768) return mobile;
    if (width < 1024) return tablet;
    return desktop;
  }

  // Section Spacing - For better content organization
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(horizontal: huge, vertical: massive);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: lg, vertical: xl);
}
