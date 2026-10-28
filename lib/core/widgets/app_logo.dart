import 'package:flutter/material.dart';

enum AppLogoVariant { symbol, onMidnight, onLight }

/// Original official artwork, including its safe space and embedded backgrounds.
/// The symbol has transparency; the two wordmarks have opaque square canvases.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.symbol,
    this.size = 80,
  });

  final AppLogoVariant variant;
  final double size;

  static String assetFor(AppLogoVariant variant) => switch (variant) {
    AppLogoVariant.symbol => 'assets/icons/3.png',
    AppLogoVariant.onMidnight => 'assets/icons/1.png',
    AppLogoVariant.onLight => 'assets/icons/2.png',
  };

  @override
  Widget build(BuildContext context) => Image.asset(
    assetFor(variant),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'OrgLink',
  );
}
