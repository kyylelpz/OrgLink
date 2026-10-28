import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brandMidnight = Color(0xFF000246);
  static const brandNavy = Color(0xFF1E2A78);
  static const brandBlue = Color(0xFF152D97);
  static const brandPurple = Color(0xFF8E75F7);
  static const brandMist = Color(0xFFF0F2FA);
  static const ink = Color(0xFF0A0A0A);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  // Semantic colors supplement the brand palette; labels/icons also convey status.
  static const success = Color(0xFF16704A);
  static const successSurface = Color(0xFFE4F4EB);
  static const warning = Color(0xFF825900);
  static const warningSurface = Color(0xFFFFF3D6);
  static const error = Color(0xFFB42335);
  static const errorSurface = Color(0xFFFDECEF);
  static const muted = Color(0xFF60677C);
  static const outline = muted;
  static const border = Color(0xFFDDE2F0);
  static const tonal = Color(0xFFE8EDFF);
  static const purpleSurface = Color(0xFFF0EBFF);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const buttonHorizontal = 20.0;
  static const chipHorizontal = 10.0;
  static const chipVertical = 6.0;
}

abstract final class AppShape {
  static const featureRadius = 24.0;
  static const actionRadius = 20.0;
  static const feature = BorderRadius.all(Radius.circular(featureRadius));
  static const action = BorderRadius.all(Radius.circular(actionRadius));
  static const fieldRadius = 12.0;
  static const cardRadius = 16.0;
  static const field = BorderRadius.all(Radius.circular(fieldRadius));
  static const card = BorderRadius.all(Radius.circular(cardRadius));
  static const buttonRadius = 14.0;
  static const button = BorderRadius.all(Radius.circular(buttonRadius));
  static const pill = BorderRadius.all(Radius.circular(100));
}

/// Figma's flat surfaces; elevation is reserved for overlays.
abstract final class AppElevation {
  static const surface = 0.0;
  static const overlay = 4.0;
}

abstract final class AppIconSize {
  static const small = 20.0;
  static const standard = 24.0;
  static const feedback = 32.0;
}

/// Semantic roles mapped to the inspected Inter text styles in Figma.
abstract final class AppTypography {
  static const fontFamily = 'Inter';
  static const hero = TextStyle(
    letterSpacing: 0,
    fontSize: 34,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  static const title = TextStyle(
    letterSpacing: 0,
    fontSize: 28,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  static const section = TextStyle(
    letterSpacing: 0,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(letterSpacing: 0, fontSize: 15, height: 1.4);
  static const supporting = TextStyle(
    letterSpacing: 0,
    fontSize: 13,
    height: 1.4,
  );
  static const label = TextStyle(
    letterSpacing: 0,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const button = TextStyle(
    letterSpacing: 0,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
}

abstract final class AppLayout {
  static const compactBreakpoint = 600.0;
  static const contentWidth = 960.0;
  static const formWidth = 560.0;
  static const minTouchTarget = 48.0;
}
