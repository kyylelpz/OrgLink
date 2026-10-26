import '../../../../core/utils/display_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../../data/models/event.dart';

String schedule(DateTime? value) => value == null
    ? 'Not recorded'
    : '${displayDate(value)} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.organizationName,
    this.registrationStatus,
  });
  final OrgEvent event;
  final String organizationName;
  final String? registrationStatus;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: OrganizationLogo(event.posterURL),
      title: Text(event.title),
      subtitle: Text(
        '$organizationName\n${schedule(event.startAt)} | ${event.venue}\n${displayIdentifier(event.eventStatus)} / ${displayIdentifier(event.approvalStatus)} | ${event.availableSlots} slots | ${event.registrationOpen(DateTime.now()) ? 'Registration open' : 'Registration closed'}${registrationStatus == null ? '' : '\nRegistration: ${displayIdentifier(registrationStatus!)}'}',
      ),
      onTap: () => context.go(AppRoutes.event(event.organizationId, event.id)),
    ),
  );
}

Future<bool> confirmEventAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class EventNavigation extends StatelessWidget {
  const EventNavigation(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: (value) =>
        context.go(value == 0 ? AppRoutes.events : AppRoutes.myEvents),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.event), label: 'Discover Events'),
      NavigationDestination(
        icon: Icon(Icons.event_available),
        label: 'My Events',
      ),
    ],
  );
}
