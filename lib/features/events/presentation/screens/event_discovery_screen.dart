import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/event_hub_view_model.dart';
import '../widgets/event_widgets.dart';

class EventDiscoveryScreen extends StatelessWidget {
  const EventDiscoveryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventHubViewModel>();
    final organizations = model.availableOrganizations;
    final loading =
        model.organizations.discovery.loading ||
        model.organizations.mine.loading ||
        model.organizations.managed.loading ||
        model.catalog.values.any((query) => query.loading);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
          title: const Text('Event Discovery'),
          leading: const AppBackButton(),
          actions: [
            if (model.managementOrganizations.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final id = await showModalBottomSheet<String>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          const ListTile(
                            title: Text('Manage Organization Events'),
                          ),
                          for (final org in model.managementOrganizations)
                            ListTile(
                              title: Text(org.name),
                              onTap: () => Navigator.pop(context, org.id),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (id != null && context.mounted) {
                    context.go(AppRoutes.manageEvents(id));
                  }
                },
                child: const Text('Manage', style: TextStyle(color: AppColors.white)),
              ),
          ],
        ),
        // Navigation Pill at Bottom
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandMidnight.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppFilterChip(
                      label: 'Discover Events',
                      selected: true,
                      onSelected: (_) {},
                    ),
                  ),
                  Expanded(
                    child: AppFilterChip(
                      label: 'My Events',
                      selected: false,
                      onSelected: (_) => context.go(AppRoutes.myEvents),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: AppPageBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const AppSectionHeading(
                  title: 'Find Your Next Moment',
                  description: 'Events across campus',
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  onChanged: (value) => model.filter(text: value),
                  decoration: InputDecoration(
                    labelText: 'Search Events by Title',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: AppShape.action,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: model.period,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'When',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: AppShape.action,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    for (final value in ['Upcoming', 'Ongoing', 'Past', 'All'])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => model.filter(time: value),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: ValueKey(organizations.keys.join('/')),
                  initialValue: model.organizationFilter ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Organization',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: AppShape.action,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    for (final org in organizations.values)
                      DropdownMenuItem(
                        value: org.id,
                        child: Text(org.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => model.filter(
                    organization: value,
                    resetOrganization: value == '',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (loading) const LinearProgressIndicator(),
                if (model.organizations.discovery.failure != null)
                  TextButton(
                    onPressed: model.organizations.discovery.retry,
                    child: const Text('Retry Organizations'),
                  ),
                if (model.organizations.mine.failure != null)
                  TextButton(
                    onPressed: model.organizations.mine.retry,
                    child: const Text('Retry Memberships'),
                  ),
                if (model.organizations.managed.failure != null)
                  TextButton(
                    onPressed: model.organizations.managed.retry,
                    child: const Text('Retry Managed Organizations'),
                  ),
                for (final query in model.catalog.values)
                  if (query.failure != null)
                    AppErrorView(
                      message: query.failure!.message,
                      onRetry: query.retry,
                    ),
                if (model.results.isEmpty)
                  loading
                      ? const AppLoadingView(message: 'Loading events...')
                      : const AppEmptyView(
                          title: 'No Events Found',
                          message: 'No accessible events match these filters.',
                        )
                else
                  for (final event in model.results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: EventCard(
                        event: event,
                        organizationName:
                            organizations[event.organizationId]?.name ??
                            'Organization',
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}