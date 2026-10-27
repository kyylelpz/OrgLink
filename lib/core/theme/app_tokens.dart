import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brandMidnight = Color(0xFF000246);
  static const brandNavy = Color(0xFF1E2A78);
  static const brandBlue = Color(0xFF002BED);
  static const brandPurple = Color(0xFF8E75F7);
  static const brandMist = Color(0xFFF0F2FA);
  static const ink = Color(0xFF0A0A0A);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  // Semantic colors supplement the brand palette; labels/icons also convey status.
  static const success = Color(0xFF166534);
  static const successSurface = Color(0xFFEAF7EE);
  static const warning = Color(0xFF805500);
  static const warningSurface = Color(0xFFFFF3D6);
  static const error = Color(0xFFA61B29);
  static const errorSurface = Color(0xFFFDEDEF);
  static const outline = Color(0xFF747A91);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppShape {
  static const fieldRadius = 12.0;
  static const cardRadius = 16.0;
  static const field = BorderRadius.all(Radius.circular(fieldRadius));
  static const card = BorderRadius.all(Radius.circular(cardRadius));
}

abstract final class AppLayout {
  static const compactBreakpoint = 600.0;
  static const contentWidth = 960.0;
  static const formWidth = 560.0;
  static const minTouchTarget = 48.0;
}
