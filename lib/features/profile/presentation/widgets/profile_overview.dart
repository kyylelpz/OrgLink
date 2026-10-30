import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../auth/presentation/screens/auth_screens.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.name,
    this.photo,
    this.size = 72,
  });
  final String name;
  final String? photo;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first)
        .join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.tonal,
        borderRadius: AppShape.feature,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppColors.brandBlue),
      ),
    );
    return ExcludeSemantics(
      child: photo?.isNotEmpty == true
          ? ClipRRect(
              borderRadius: AppShape.feature,
              child: Image.network(
                photo!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => fallback,
              ),
            )
          : fallback,
    );
  }
}

class ProfileOverview extends StatelessWidget {
  const ProfileOverview({super.key, required this.auth, required this.onEdit});
  final AuthViewModel auth;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final details = auth.profile!.details;
    final academic = [
      if (details.college?.isNotEmpty == true) details.college!,
      if (details.program?.isNotEmpty == true) details.program!,
      'Year ${details.yearLevel}',
      'Section ${details.section}',
    ];
    return AppPageBody(
      maxWidth: AppLayout.formWidth,
      child: SingleChildScrollView(
        // <-- ADDED
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.fullName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: AppColors.brandMidnight),
                    ),
                    Text(
                      details.studentNumber,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                );
                final avatar = ProfileIdentity(
                  name: details.fullName,
                  photo: auth.profile?.photoURL,
                );
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(height: AppSpacing.md),
                      identity,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: identity),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeading(title: 'Academic Information'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(academic.join(' · ')),
                  if (details.college?.isNotEmpty != true ||
                      details.program?.isNotEmpty != true) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'College and Program are optional. Add them when you edit your profile.',
                    ),
                  ],
                ],
              ),
            ),

            AppActionButton(
              label: 'Edit Student Profile',
              onPressed: auth.isBusy ? null : onEdit,
              style: AppActionStyle.outlined,
            ),

            if (auth.profile?.isPlatformAdmin == true) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.admin),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                label: const Text('Platform Administration'),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // NEW CARD STYLE LINKS
            const AppSectionHeading(title: 'Your Communities'),
            AppSurfaceCard(
              onTap: () => context.push(AppRoutes.myOrganizations),
              child: Row(
                children: [
                  const Icon(Icons.groups_outlined, color: AppColors.brandBlue),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'My Organizations',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeading(title: 'Participation History'),
            AppSurfaceCard(
              onTap: () => context.push(AppRoutes.myAttendance),
              child: Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'My Attendance',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
            AppSurfaceCard(
              onTap: () => context.push(AppRoutes.myEvents),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'My Events',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            if (auth.user?.providers.contains('google.com') == true &&
                auth.user?.providers.contains('password') != true) ...[
              const SizedBox(height: AppSpacing.xs),
              AppActionButton(
                label: 'Link Password',
                style: AppActionStyle.outlined,
                onPressed: () => context.push(AppRoutes.linkPassword),
              ),
            ],

            if (auth.failure != null)
              Text(
                auth.failure!.message,
                style: const TextStyle(color: AppColors.error),
              ),
            
            const SizedBox(height: AppSpacing.md),
            const SignOutButton(),
            const SizedBox(height: AppSpacing.xl), // Bottom padding
          ],
        ),
      ),
    );
  }
}
