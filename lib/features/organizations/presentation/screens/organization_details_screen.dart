import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
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
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.brandMidnight,
          ),
        ),
        const SizedBox(height: 6),
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                Text(
                  org.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.brandMidnight,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${displayIdentifier(org.visibility)} | ${displayIdentifier(org.status)}',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (model.membership.loading)
                  const LinearProgressIndicator()
                else if (model.membership.failure != null)
                  TextButton(
                    onPressed: model.membership.retry,
                    child: const Text('Retry Membership Status'),
                  )
                else ...[
                  Text(
                    model.isManager
                        ? 'You manage this organization.'
                        : 'Membership: ${model.membership.value == null ? (model.submitted ? 'Pending' : 'Not a Member') : displayMembershipStatus(model.membership.value!.status)}',
                  ),
                  if ([
                    'rejected',
                    'removed',
                  ].contains(model.membership.value?.status))
                    const Text('Reapplication is not currently available.'),
                  if (model.membership.value == null && !model.isManager)
                    AppActionButton(
                      busy: model.busy,
                      busyLabel: 'Submitting membership request',
                      onPressed: model.canRequest
                          ? () async {
                              final success = await model.request();
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Membership request submitted.',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      label: model.busy
                          ? 'Submitting...'
                          : model.submitted
                          ? 'Request Pending'
                          : 'Request to Join',
                    ),
                  if (!org.acceptsRequests)
                    const Text(
                      'This organization is not accepting new requests.',
                    ),
                ],
                if (model.actionFailure != null)
                  Text(
                    model.actionFailure!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (model.isManager)
                  FilledButton.tonal(
                    onPressed: () =>
                        context.go(AppRoutes.manageMembers(org.id)),
                    child: const Text('Manage Membership Requests'),
                  ),
                if (model.canViewRoster)
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.memberRoster(org.id)),
                    child: const Text('View Member Roster'),
                  ),
                const SizedBox(height: AppSpacing.lg),
                _section('Description', org.description),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section('Our Mission', org.mission, card: false),
                      const SizedBox(height: AppSpacing.md),
                      _section('Our Vision', org.vision, card: false),
                      const SizedBox(height: AppSpacing.md),
                      _section('Our Goals', org.goals.join('\n'), card: false),
                    ],
                  ),
                ),
                _section(
                  'Membership Structure',
                  org.positions.isEmpty
                      ? 'Manager, officers and general members. Position titles have not been published.'
                      : org.positions.join('\n'),
                ),
                _section(
                  'Membership Requirements',
                  org.membershipRequirements.join('\n'),
                ),
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Upcoming Published Events',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                if (model.events.loading)
                  const LinearProgressIndicator()
                else if (model.events.failure != null)
                  TextButton(
                    onPressed: model.events.retry,
                    child: const Text('Retry Events'),
                  )
                else if ((model.events.value ?? []).isEmpty)
                  const Text('No upcoming published events.')
                else
                  for (final event in model.events.value!)
                    ListTile(
                      title: Text(event.title),
                      subtitle: Text(displayDate(event.startAt)),
                      onTap: () =>
                          context.go(AppRoutes.event(org.id, event.id)),
                    ),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.events),
                  child: const Text('Browse Events'),
                ),
                if (model.isManager ||
                    (model.membership.value?.role == 'officer' &&
                        model.membership.value?.status == 'active' &&
                        model.membership.value?.permissions['manageEvents'] ==
                            true))
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.manageEvents(org.id)),
                    child: const Text('Manage Organization Events'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
