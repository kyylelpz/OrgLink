import 'package:flutter/material.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), leading: const AppBackButton()),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formWidth),
          child: AppSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: const BoxDecoration(
                    color: AppColors.brandMist,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: AppColors.brandBlue),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    'Coming Soon',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                AppActionButton(
                  label: 'Discover Events',
                  icon: Icons.arrow_forward,
                  onPressed: () => context.push(AppRoutes.events),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
