import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/community_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_asset_icon.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../../events/presentation/widgets/event_sort.dart';
import '../../../events/presentation/widgets/event_widgets.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../viewmodels/home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthViewModel>().profile?.isEligible != true) {
      return const Scaffold(
        body: AppEmptyView(
          title: 'Account Unavailable',
          message: 'An active account and completed profile are required.',
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(context.read<EventHubViewModel>()),
      child: const _Dashboard(),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>(),
        model = context.watch<HomeViewModel>();
    final fullName = auth.profile?.details.fullName.trim() ?? '';
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final firstName = parts.firstOrNull ?? 'Student';
    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final upcoming = model.upcoming;
    final ongoing = sortByChronology(model.ongoing);
    final organizations = model.suggestedOrganizations.take(2);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: const ValueKey('home-dashboard'),
        body: Semantics(
          label: 'Home Dashboard',
          namesRoute: true,
          child: RefreshIndicator(
            onRefresh: model.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CommunityDashboardHeader(
                    greeting: '$salutation,\n$firstName!',
                    name: firstName,
                    imageUrl: auth.profile?.photoURL,
                    onNotifications: () => context.push(AppRoutes.notifications),
                    onProfile: () => context.push(AppRoutes.completeProfile),
                    search: AppSearchField(
                      controller: _search,
                      onChanged: model.searchFor,
                      compact: true,
                      label: 'Search Events or Organizations',
                      hintText: 'Search events or organizations',
                      leading: const Padding(
                        padding: EdgeInsets.all(14),
                        child: AppAssetIcon(
                          'search',
                          size: 19,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
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
                            AppSpacing.xl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (model.search.trim().isEmpty) ...[
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableWidth = constraints.maxWidth;
                                  final textScale = MediaQuery.textScalerOf(context).scale(11);

                                  final columns = textScale > 16.5 || availableWidth < 320
                                      ? 2
                                      : availableWidth < 600
                                          ? 4
                                          : 4;

                                  final width =
                                      (availableWidth - 6 * (columns - 1)) / columns;
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: AppSpacing.md,
                                    children: [
                                      for (final action in const [
                                        _Shortcut(
                                          label: 'My Events',
                                          icon: Icons.event_note,
                                          asset: 'my_events',
                                          route: AppRoutes.myEvents,
                                        ),
                                        _Shortcut(
                                          label: 'My Organizations',
                                          icon: Icons.groups_outlined,
                                          asset: 'organizations',
                                          route: AppRoutes.myOrganizations,
                                        ),
                                        _Shortcut(
                                          label: 'Notifications',
                                          icon: Icons.notifications_outlined,
                                          asset: 'bell',
                                          route: AppRoutes.notifications,
                                        ),
                                        _Shortcut(
                                          label: 'My Attendance',
                                          icon: Icons.fact_check_outlined,
                                          asset: 'attendance',
                                          route: AppRoutes.myAttendance,
                                        ),
                                      ])
                                        SizedBox(width: width, child: action),
                                    ],
                                  );
                                },
                              ),
                              ],
                              
                              const SizedBox(height: AppSpacing.sm),

                              if (auth.failure != null)
                                AppErrorView(
                                  message: auth.failure!.message,
                                  onRetry: () => context.read<AuthViewModel>().retry(),
                                )
                              else if (model.failure != null)
                                AppErrorView(
                                  message: model.failure!.message,
                                  onRetry: model.retry,
                                )
                              else if (model.loading)
                                const AppLoadingView(
                                  message: 'Loading events and organizations...',
                                )
                              else if (model.search.trim().isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        'Search Results',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: AppColors.brandMidnight,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      '(${model.matchingEvents.length + model.matchingOrganizations.length})',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (model.matchingEvents.isEmpty &&
                                    model.matchingOrganizations.isEmpty)
                                  const AppEmptyView(
                                    title: 'No Matches',
                                    message:
                                        'Try another event or organization name.',
                                  ),
                                if (model.matchingEvents.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.sm,
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        'Events',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandMidnight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final event in model.matchingEvents)
                                    EventCard(
                                      event: event,
                                      organizationName:
                                          model
                                              .hub
                                              .availableOrganizations[event
                                                  .organizationId]
                                              ?.name ??
                                          'Organization',
                                      style: EventCardStyle.compact,
                                    ),
                                ],
                                if (model.matchingOrganizations.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.sm,
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        'Organizations',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandMidnight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final org in model.matchingOrganizations)
                                    OrganizationCard(
                                      organization: org,
                                      preview: true,
                                    ),
                                ],
                              ] else ...[
                                // 1. HAPPENING NOW (ONGOING EVENTS)
                                if (ongoing.isNotEmpty) ...[
                                  CommunitySectionHeading(
                                    title: 'Happening Now',
                                    actionLabel: 'View All',
                                    onAction: () =>
                                        context.push(AppRoutes.events),
                                  ),
                                  for (final event in ongoing)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm,
                                      ),
                                      child: LiveEventCard(
                                        event: event,
                                        organizationName:
                                            model
                                                .hub
                                                .availableOrganizations[event
                                                    .organizationId]
                                                ?.name ??
                                            'Organization',
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.md),
                                ],

                                // 2. FEATURED EVENT (Only show if there is an upcoming event)
                                if (upcoming.isNotEmpty) ...[
                                  CommunitySectionHeading(
                                    title: 'Featured Event',
                                    actionLabel: 'Explore',
                                    onAction: () =>
                                        context.push(AppRoutes.events),
                                  ),
                                  EventCard(
                                    event: upcoming.first,
                                    organizationName:
                                        model
                                            .hub
                                            .availableOrganizations[upcoming
                                                .first
                                                .organizationId]
                                            ?.name ??
                                        'Organization',
                                    style: EventCardStyle.featured,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],

                                // 3. EMPTY STATE (Only show if BOTH are empty)
                                if (upcoming.isEmpty &&
                                    model.ongoing.isEmpty) ...[
                                  CommunitySectionHeading(
                                    title: 'Featured Event',
                                    actionLabel: 'Explore Orgs',
                                    onAction: () =>
                                        context.push(AppRoutes.organizations),
                                  ),
                                  const AppEmptyView(
                                    title: 'No Events Right Now',
                                    message:
                                        'Check back later or explore organizations to get involved.',
                                  ),
                                ],

                                // 4. MORE EVENTS (Only show if there are 2 or more upcoming events)
                                if (upcoming.length > 1) ...[
                                  const SizedBox(height: AppSpacing.xl),
                                  CommunitySectionHeading(
                                    title: 'More Events',
                                  ),
                                  for (final event in upcoming.skip(1).take(3))
                                    EventCard(
                                      event: event,
                                      organizationName:
                                          model
                                              .hub
                                              .availableOrganizations[event
                                                  .organizationId]
                                              ?.name ??
                                          'Organization',
                                      style: EventCardStyle.compact,
                                    ),
                                ],

                                const SizedBox(height: AppSpacing.xl),

                                CommunitySectionHeading(
                                  title: 'Suggested Organizations',
                                  actionLabel: 'Browse All',
                                  onAction: () => context.push(AppRoutes.organizations),
                                ),
                                if (organizations.isEmpty)
                                  const AppEmptyView(
                                    title: 'No Suggested Organizations',
                                    message: 'You’ve joined every available organization — check back soon.',
                                  ),
                                for (final org in organizations)
                                  OrganizationCard(
                                    organization: org,
                                    preview: true,
                                  ),
                              ],

                              const SizedBox(height: AppSpacing.xl),
                              
                              // IMPROVED ORGANIZATION MANAGEMENT
                              if (model.search.trim().isEmpty &&
                              model
                                  .hub
                                  .managementOrganizations
                                  .isNotEmpty) ...[
                                const Divider(
                                  height: AppSpacing.md,   // whitespace above + below the line
                                  thickness: 1,            // line thickness (hairline)
                                  color: AppColors.border, // or AppColors.muted
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const AppSectionHeading(
                                  title: 'Organization Management',
                                  description: 'Tools for your organizations',
                                  prominent: true,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                for (final org
                                    in model.hub.managementOrganizations)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: AppSurfaceCard(
                                      onTap: () => context.push(
                                        AppRoutes.organization(org.id),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppColors.brandMidnight
                                                  .withValues(alpha: 0.05),
                                              borderRadius: AppShape.button,
                                            ),
                                            child: const Icon(
                                              Icons.admin_panel_settings_outlined,
                                              color: AppColors.brandMidnight,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  org.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .brandMidnight,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Manage',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.brandBlue,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                const SizedBox(height: AppSpacing.xs),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.label,
    required this.icon,
    required this.route,
    required this.asset,
  });
  final String label, route, asset;
  final IconData icon;
  @override
  Widget build(BuildContext context) => CommunityQuickAction(
    onPressed: () => context.push(route),
    icon: icon,
    asset: asset,
    label: label,
  );
}