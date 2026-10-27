import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
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
              child: const Text('Manage'),
            ),
        ],
      ),
      bottomNavigationBar: const EventNavigation(0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => model.filter(text: value),
                  decoration: const InputDecoration(
                    labelText: 'Search Events by Title',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: model.period,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'When'),
                        items: [
                          for (final value in [
                            'Upcoming',
                            'Ongoing',
                            'Past',
                            'All',
                          ])
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) => model.filter(time: value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(organizations.keys.join('/')),
                        initialValue: model.organizationFilter ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Organization',
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          for (final org in organizations.values)
                            DropdownMenuItem(
                              value: org.id,
                              child: Text(
                                org.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => model.filter(
                          organization: value,
                          resetOrganization: value == '',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
              Column(
                children: [
                  Text(query.failure!.message),
                  TextButton(
                    onPressed: query.retry,
                    child: const Text('Retry Events'),
                  ),
                ],
              ),
          Expanded(
            child: model.results.isEmpty
                ? Center(
                    child: Text(
                      loading
                          ? 'Loading events...'
                          : 'No accessible events match these filters.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final event in model.results)
                        EventCard(
                          event: event,
                          organizationName:
                              organizations[event.organizationId]?.name ??
                              'Organization',
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
