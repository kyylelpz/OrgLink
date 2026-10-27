import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// A shared introduction for community and participation destinations.
class CommunityHeader extends StatelessWidget {
  const CommunityHeader({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome_outlined,
    this.emphasized = false,
  });
  final String title, description;
  final IconData icon;
  final bool emphasized;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = emphasized ? AppColors.white : AppColors.brandMidnight;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppShape.feature,
        color: emphasized ? null : AppColors.white,
        gradient: emphasized
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandMidnight, AppColors.brandNavy],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: emphasized ? AppColors.white : AppColors.brandBlue,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(color: foreground),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class CommunityQuickAction extends StatelessWidget {
  const CommunityQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    borderRadius: AppShape.action,
    child: InkWell(
      onTap: onPressed,
      borderRadius: AppShape.action,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.brandMist,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brandBlue),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    ),
  );
}
