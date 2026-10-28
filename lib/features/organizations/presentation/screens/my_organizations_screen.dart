import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/organization_hub_view_model.dart';
import '../widgets/organization_widgets.dart';

class MyOrganizationsScreen extends StatelessWidget {
  const MyOrganizationsScreen({super.key, this.requestsOnly = false});
  final bool requestsOnly;
  
  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationHubViewModel>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        // We move the nav bar down here
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrganizationNavigation(requestsOnly ? 2 : 1),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // DARK HEADER
            Container(
              decoration: const BoxDecoration(
                color: AppColors.brandMidnight,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppShape.featureRadius),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.contentWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back, color: AppColors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            requestsOnly ? 'Membership Requests' : 'My Organizations',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // MAIN CONTENT
            Expanded(
              child: QueryContent(
                query: model.mine,
                builder: (records) {
                  final memberships =
                      (records ?? [])
                          .where((member) => !requestsOnly || member.role != 'manager')
                          .toList()
                        ..sort((a, b) => a.organizationId.compareTo(b.organizationId));
                  final membershipIds = memberships
                      .map((member) => member.organizationId)
                      .toSet();
                  final assignedOnly = (model.managed.value ?? [])
                      .where((org) => !membershipIds.contains(org.id))
                      .toList();
                      
                  return AppPageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        OrganizationPageHeading(
                          title: requestsOnly
                              ? 'Membership Requests'
                              : 'Your Communities',
                          description: requestsOnly
                              ? 'Track your existing membership requests.'
                              : 'Your memberships and organizations you manage.',
                        ),
                        if (!requestsOnly) ...[
                          if (model.managed.failure != null)
                            TextButton(
                              onPressed: model.managed.retry,
                              child: const Text('Retry Managed Organizations'),
                            ),
                          if (assignedOnly.isNotEmpty)
                            const AppSectionHeading(title: 'Organizations You Manage'),
                          for (final org in assignedOnly)
                            OrganizationCard(
                              organization: org,
                              subtitle: 'Assigned Organization Manager',
                              status: const AppStatusChip(
                                label: 'Manager',
                                tone: AppStatusTone.info,
                              ),
                            ),
                        ],
                        if (memberships.isEmpty &&
                            (requestsOnly || assignedOnly.isEmpty))
                          AppEmptyView(
                            title: requestsOnly
                                ? 'No Membership Requests'
                                : 'No Memberships Yet',
                            message: requestsOnly
                                ? 'No membership requests yet.'
                                : 'You have no organization memberships yet.',
                          ),
                        for (final member in memberships)
                          Builder(
                            builder: (context) {
                              final query = model.associated[member.organizationId];
                              final org = query?.value;
                              final summary =
                                  'Role: ${displayIdentifier(member.role)} | Status: ${displayMembershipStatus(member.status)}\nPosition: ${member.positionTitle ?? 'Not Assigned'}\nRequested: ${displayDate(member.requestedAt)}';
                              if (org != null) {
                                return OrganizationCard(
                                  organization: org,
                                  subtitle: summary,
                                  status: AppStatusChip(
                                    label: displayMembershipStatus(member.status),
                                    tone: membershipStatusTone(member.status),
                                  ),
                                );
                              }
                              return AppSurfaceCard(
                                onTap: () => context.go(
                                  AppRoutes.organization(member.organizationId),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      query?.loading == true
                                          ? 'Loading organization...'
                                          : 'Organization Unavailable',
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      '$summary\n${query?.failure?.message ?? 'Details may no longer be available to your account.'}',
                                    ),
                                    if (query?.failure != null)
                                      AppActionButton(
                                        label: 'Retry Organization',
                                        icon: Icons.refresh,
                                        style: AppActionStyle.outlined,
                                        onPressed: query!.retry,
                                      ),
                                    AppActionButton(
                                      label: 'View Organization',
                                      style: AppActionStyle.text,
                                      onPressed: () => context.go(
                                        AppRoutes.organization(member.organizationId),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}