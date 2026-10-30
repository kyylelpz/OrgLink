import '../../../../core/widgets/app_back_button.dart';
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

class MyOrganizationsScreen extends StatefulWidget {
  const MyOrganizationsScreen({super.key});

  @override
  State<MyOrganizationsScreen> createState() => _MyOrganizationsScreenState();
}

class _MyOrganizationsScreenState extends State<MyOrganizationsScreen> {
  String _activeTab = 'All';

  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationHubViewModel>();
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        bottomNavigationBar: const OrganizationNavigation(1),
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
                          const IconTheme(
                            data: IconThemeData(color: AppColors.white),
                            child: AppBackButton(color: AppColors.white),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'My Organizations',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                  final memberships = (records ?? []).toList();
                  final membershipIds = memberships
                      .map((member) => member.organizationId)
                      .toSet();
                      
                  final assignedOnly = (model.managed.value ?? [])
                      .where((org) => !membershipIds.contains(org.id))
                      .toList();

                  final pendingMemberships = memberships
                      .where((m) => m.status == 'pending')
                      .toList();

                  final activeMemberships = memberships
                      .where((m) => m.status == 'active')
                      .toList();

                  final inactiveMemberships = memberships
                      .where((m) =>
                          m.status != 'pending' && m.status != 'active')
                      .toList();

                  return AppPageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        const OrganizationPageHeading(
                          title: 'Your Communities',
                          description: 'Your memberships and organizations you manage.',
                        ),

                        // ─── INTERNAL TABS ───
                        Row(
                          children: [
                            Expanded(
                              child: AppFilterChip(
                                expanded: true,
                                label: 'All',
                                selected: _activeTab == 'All',
                                onSelected: (_) => setState(() => _activeTab = 'All'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppFilterChip(
                                expanded: true,
                                label: 'Active',
                                selected: _activeTab == 'Active',
                                onSelected: (_) => setState(() => _activeTab = 'Active'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppFilterChip(
                                expanded: true,
                                label: 'Pending',
                                selected: _activeTab == 'Pending',
                                onSelected: (_) => setState(() => _activeTab = 'Pending'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ─── GLOBAL EMPTY STATE (Only on "All" tab) ───
                        if (_activeTab == 'All' &&
                            assignedOnly.isEmpty &&
                            pendingMemberships.isEmpty &&
                            activeMemberships.isEmpty &&
                            inactiveMemberships.isEmpty)
                          const AppEmptyView(
                            title: 'No Organizations Yet',
                            message: 'You have not joined or requested to join any organizations.',
                          ),

                        // ─── MANAGED ORGS (Visible on All or Active tabs if not empty) ───
                        if ((_activeTab == 'All' || _activeTab == 'Active') &&
                            assignedOnly.isNotEmpty) ...[
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
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ─── PENDING REQUESTS ───
                        if (_activeTab == 'Pending' || 
                           (_activeTab == 'All' && pendingMemberships.isNotEmpty)) ...[
                          const AppSectionHeading(title: 'Pending Requests'),
                          if (pendingMemberships.isEmpty)
                            const AppEmptyView(
                              title: 'No Pending Requests',
                              message: 'You have no membership requests awaiting approval.',
                            )
                          else
                            for (final member in pendingMemberships)
                              _buildMembershipCard(context, model, member),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ─── ACTIVE MEMBERSHIPS ───
                        if (_activeTab == 'Active' || 
                           (_activeTab == 'All' && activeMemberships.isNotEmpty)) ...[
                          const AppSectionHeading(title: 'Active Memberships'),
                          if (activeMemberships.isEmpty)
                            const AppEmptyView(
                              title: 'No Active Memberships',
                              message: 'You are not an active member of any organization.',
                            )
                          else
                            for (final member in activeMemberships)
                              _buildMembershipCard(context, model, member),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ─── PAST MEMBERSHIPS (Visible on All or Active tabs if not empty) ───
                        if ((_activeTab == 'All' || _activeTab == 'Active') &&
                            inactiveMemberships.isNotEmpty) ...[
                          const AppSectionHeading(title: 'Past Memberships'),
                          for (final member in inactiveMemberships)
                            _buildMembershipCard(context, model, member),
                        ],
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

  Widget _buildMembershipCard(
    BuildContext context,
    OrganizationHubViewModel model,
    dynamic member,
  ) {
    return Builder(
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
                  AppRoutes.organization(
                    member.organizationId,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}