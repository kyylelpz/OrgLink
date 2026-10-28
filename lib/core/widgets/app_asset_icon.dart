import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Locally exported Figma icon artwork. Interactive parents provide semantics.
class AppAssetIcon extends StatelessWidget {
  const AppAssetIcon(
    this.name, {
    super.key,
    this.size = AppIconSize.standard,
    this.color = AppColors.brandBlue,
  });
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/figma_$name.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    color: color,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );
}
