import '../../../../core/widgets/image_editor.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/organization_details_view_model.dart';
import '../widgets/organization_widgets.dart';

class OrganizationDetailsScreen extends StatelessWidget {
  const OrganizationDetailsScreen({super.key});

  Widget _section(String title, String text, {bool card = true}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.brandMidnight,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          text.isEmpty ? 'Not published yet.' : text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
    return card ? AppSurfaceCard(child: content) : content;
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationDetailsViewModel>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          backgroundColor: AppColors.brandMidnight,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppShape.featureRadius),
            ),
          ),
          title: const Text('Organization Details'),
          leading: const AppBackButton(),
        ),
        body: QueryContent(
          query: model.organization,
          builder: (org) {
            if (org == null) {
              return const AppEmptyView(
                title: 'Organization Unavailable',
                message: 'Organization not found.',
              );
            }
            return AppPageBody(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                          child: Container(
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AppColors.brandMidnight,
                              borderRadius: AppShape.feature,
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: 8,
                                  top: 10,
                                  child: Image.asset(
                                    'assets/illustrations/organization_orbit.png',
                                    width: 128,
                                    height: 128,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    40,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 230,
                                    ),
                                    child: Text(
                                      'Ideas become\nimpact. Together.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontSize: 30,
                                            height: 1.05,
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: AppShape.action,
                            ),
                            child: OrganizationLogo(org.logoURL, size: 56),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (model.isManager && org.status == 'active')
                      ImageEditor(
                        key: ValueKey('logo/${org.id}'),
                        resource: ImageResource(
                          'organization',
                          organizationId: org.id,
                        ),
                        label: 'Logo',
                        currentURL: org.logoURL,
                      ),
                    Text(
                      org.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.brandMidnight,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        AppStatusChip(
                          label: displayIdentifier(org.visibility),
                          tone: AppStatusTone.info,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppStatusChip(
                          label: displayIdentifier(org.status),
                          tone: org.status == 'active'
                              ? AppStatusTone.success
                              : AppStatusTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // MEMBERSHIP STATUS
                    if (model.membership.loading)
                      const LinearProgressIndicator()
                    else if (model.membership.failure != null)
                      TextButton(
                        onPressed: model.membership.retry,
                        child: const Text('Retry Membership Status'),
                      )
                    else ...[
                      AppSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.isManager
                                  ? 'You manage this organization.'
                                  : 'Membership: ${model.membership.value == null ? (model.submitted ? 'Pending' : 'Not a Member') : displayMembershipStatus(model.membership.value!.status)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandMidnight,
                              ),
                            ),
                            if ([
                              'rejected',
                              'removed',
                            ].contains(model.membership.value?.status))
                              const Padding(
                                padding: EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  'Reapplication is not currently available.',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            if (model.membership.value == null &&
                                !model.isManager) ...[
                              const SizedBox(height: AppSpacing.md),
                              FilledButton(
                                onPressed: model.canRequest
                                    ? () async {
                                        final success = await model.request();
                                        if (context.mounted && success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Membership request submitted.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                child: Text(
                                  model.busy
                                      ? 'Submitting...'
                                      : model.submitted
                                      ? 'Request Pending'
                                      : 'Request to Join',
                                ),
                              ),
                            ],
                            if (!model.isManager &&
                                (model.membership.value?.status == 'pending' ||
                                    (model.submitted &&
                                        model.membership.value == null))) ...[
                              const SizedBox(height: AppSpacing.sm),
                              TextButton(
                                onPressed: model.canCancelRequest
                                    ? () async {
                                        final success = await model
                                            .cancelRequest();
                                        if (context.mounted && success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Membership request cancelled.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                child: Text(
                                  model.busy
                                      ? 'Cancelling...'
                                      : 'Cancel Request',
                                ),
                              ),
                            ],
                            if (!org.acceptsRequests)
                              const Padding(
                                padding: EdgeInsets.only(top: AppSpacing.sm),
                                child: Text(
                                  'This organization is not accepting new requests.',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    if (model.actionFailure != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          model.actionFailure!.message,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),

                    // MANAGER ACTIONS
                    if (model.isManager)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              context.go(AppRoutes.manageMembers(org.id)),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('Manage Membership Requests'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                    if (model.canViewRoster)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go(AppRoutes.memberRoster(org.id)),
                          icon: const Icon(Icons.people_outline),
                          label: const Text('View Member Roster'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.md),

                    // INFO SECTIONS
                    _section('Description', org.description),
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section('Our Mission', org.mission, card: false),
                          const Divider(height: AppSpacing.xl),
                          _section('Our Vision', org.vision, card: false),
                          const Divider(height: AppSpacing.xl),
                          _section(
                            'Our Goals',
                            org.goals.join('\n'),
                            card: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _section(
                      'Membership Structure',
                      org.positions.isEmpty
                          ? 'Manager, officers and general members. Position titles have not been published.'
                          : org.positions.join('\n'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _section(
                      'Membership Requirements',
                      org.membershipRequirements.join('\n'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _section(
                      'Public Officers',
                      org.publicOfficers.isEmpty
                          ? 'No public officer information.'
                          : org.publicOfficers
                                .map(
                                  (officer) =>
                                      '${officer.name} - ${officer.positionTitle}',
                                )
                                .join('\n'),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const AppSectionHeading(title: 'Upcoming Published Events'),
                    const SizedBox(height: AppSpacing.md),

                    if (model.events.loading)
                      const LinearProgressIndicator()
                    else if (model.events.failure != null)
                      TextButton(
                        onPressed: model.events.retry,
                        child: const Text('Retry Events'),
                      )
                    else if ((model.events.value ?? []).isEmpty)
                      const AppEmptyView(
                        title: 'No Events',
                        message: 'No upcoming published events.',
                      )
                    else
                      for (final event
                          in (List.of(model.events.value!)..sort((a, b) {
                            final dateA = a.startAt;
                            final dateB = b.startAt;
                            if (dateA == null && dateB == null) return 0;
                            if (dateA == null) return 1;
                            if (dateB == null) return -1;
                            return dateA.compareTo(dateB);
                          })))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppSurfaceCard(
                            onTap: () =>
                                context.go(AppRoutes.event(org.id, event.id)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandMidnight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        displayDate(event.startAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),

                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.events),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Browse All Events'),
                    ),

                    if (model.isManager ||
                        (model.membership.value?.role == 'officer' &&
                            model.membership.value?.status == 'active' &&
                            model
                                    .membership
                                    .value
                                    ?.permissions['manageEvents'] ==
                                true))
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              context.go(AppRoutes.manageEvents(org.id)),
                          icon: const Icon(Icons.edit_calendar),
                          label: const Text('Manage Organization Events'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
