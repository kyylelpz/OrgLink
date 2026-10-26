import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/organization_hub_view_model.dart';
import '../widgets/organization_widgets.dart';

class OrganizationDiscoveryScreen extends StatelessWidget {
  const OrganizationDiscoveryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationHubViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Discovery'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      bottomNavigationBar: const OrganizationNavigation(0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: model.searchFor,
              decoration: const InputDecoration(
                labelText: 'Search organizations by name',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: QueryContent(
              query: model.discovery,
              builder: (_) {
                if (model.results.isEmpty) {
                  return Center(
                    child: Text(
                      model.search.trim().isEmpty
                          ? 'No public organizations are available yet.'
                          : 'No organizations match your search.',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: model.results.length,
                  itemBuilder: (context, index) {
                    final org = model.results[index];
                    final membership = model.membership(org.id);
                    return OrganizationCard(
                      organization: org,
                      subtitle: membership == null
                          ? null
                          : 'Membership: ${membership.statusLabel}',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
