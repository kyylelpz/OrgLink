import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/presentation/screens/auth_screens.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
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
    final firstName = auth.profile!.details.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return Scaffold(
      appBar: AppBar(title: const Text('Home Dashboard')),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeading(
              title: 'Welcome, $firstName!',
              description: 'Explore events and your organizations.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSearchField(
              controller: _search,
              onChanged: model.searchFor,
              label: 'Search Events or Organizations',
              hintText: 'Search events or organizations',
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Shortcut(
                  label: 'My Events',
                  icon: Icons.event_note,
                  route: AppRoutes.myEvents,
                ),
                _Shortcut(
                  label: 'My Orgs',
                  icon: Icons.groups_outlined,
                  route: AppRoutes.myOrganizations,
                ),
                _Shortcut(
                  label: 'Notifications',
                  icon: Icons.notifications_outlined,
                  route: AppRoutes.notifications,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (model.failure != null)
              AppErrorView(
                message: model.failure!.message,
                onRetry: model.retry,
              )
            else if (model.loading)
              const AppLoadingView(
                message: 'Loading events and organizations...',
              )
            else if (model.search.trim().isNotEmpty) ...[
              const AppSectionHeading(title: 'Search Results'),
              if (model.matchingEvents.isEmpty &&
                  model.matchingOrganizations.isEmpty)
                const AppEmptyView(
                  title: 'No Matches',
                  message: 'Try another event or organization name.',
                ),
              for (final event in model.matchingEvents)
                EventCard(
                  event: event,
                  organizationName:
                      model
                          .hub
                          .availableOrganizations[event.organizationId]
                          ?.name ??
                      'Organization',
                ),
              for (final org in model.matchingOrganizations)
                OrganizationCard(organization: org),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming Events',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.events),
                    child: const Text('See All'),
                  ),
                ],
              ),
              if (model.upcoming.isEmpty)
                const AppEmptyView(
                  title: 'No Upcoming Events',
                  message: 'Published upcoming events will appear here.',
                ),
              for (final event in model.upcoming)
                EventCard(
                  event: event,
                  organizationName:
                      model
                          .hub
                          .availableOrganizations[event.organizationId]
                          ?.name ??
                      'Organization',
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const AppSectionHeading(
              title: 'Your Activity',
              description:
                  'Explore, manage your participation, or update your account.',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => context.push(AppRoutes.organizations),
                  child: const Text('Discover Organizations'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.myOrganizations),
                  child: const Text('My Organizations'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.membershipRequests),
                  child: const Text('Membership Requests'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.events),
                  child: const Text('Discover Events'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.myAttendance),
                  child: const Text('My Attendance'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.attendanceHub),
                  child: const Text('Attendance Management'),
                ),
                TextButton(
                  onPressed: auth.isBusy
                      ? null
                      : () => context.push(AppRoutes.completeProfile),
                  child: const Text('Edit Student Profile'),
                ),
                const SignOutButton(),
              ],
            ),
            if (auth.failure != null) Text(auth.failure!.message),
          ],
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
  });
  final String label, route;
  final IconData icon;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => context.push(route),
    icon: Icon(icon),
    label: Text(label),
  );
}
