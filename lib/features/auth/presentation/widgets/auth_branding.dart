import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_asset_icon.dart';

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppLogo(size: size),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          'OrgLink',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.brandMidnight,
            fontSize: 22,
            letterSpacing: -0.7,
          ),
        ),
      ),
    ],
  );
}

/// Marketing illustration, not an organization/event record or app statistics.
class CampusIllustration extends StatelessWidget {
  const CampusIllustration({super.key});
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return ClipRRect(
      borderRadius: AppShape.feature,
      child: Container(
        constraints: BoxConstraints(minHeight: 264 * scale),
        color: AppColors.brandMidnight,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: 40,
              child: Image.asset(
                'assets/illustrations/auth_orbit.png',
                width: 210,
                height: 210,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              right: 28,
              top: 12,
              child: Transform.rotate(
                angle: -0.488692,
                child: Container(
                  width: 220,
                  height: 28,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: scale > 1.3 ? null : 140,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: AppShape.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppLogo(size: 32),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Your people.\nYour possibilities.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: scale > 1.3 ? null : 248,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: const BoxDecoration(
                        color: AppColors.tonal,
                        borderRadius: AppShape.card,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppAssetIcon('my_events'),
                          const SizedBox(width: AppSpacing.md),
                          Flexible(
                            child: Text(
                              'One campus. More connections.',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
