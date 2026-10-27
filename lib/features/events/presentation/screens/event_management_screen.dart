import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../attendance/data/models/attendance.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/live_query.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../../data/models/event.dart';
import '../viewmodels/participants_view_model.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../viewmodels/event_context_view_model.dart';
import '../widgets/event_access_view.dart';
import '../widgets/event_widgets.dart';

class EventManagementScreen extends StatelessWidget {
  const EventManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Event Management'),
        leading: IconButton(
          onPressed: () =>
              context.go(AppRoutes.organization(model.organizationId)),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      floatingActionButton: model.canCreate
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.go(AppRoutes.createEvent(model.organizationId)),
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            )
          : null,
      body: EventAccessView(
        builder: (context) {
          if (!model.canCreate) {
            return const Center(
              child: Text('You do not have permission to manage events.'),
            );
          }
          return ChangeNotifierProvider(
            key: ValueKey('${model.organizationId}/${model.isManager}'),
            create: (_) => LiveQuery(
              () => model.repository.organizationEvents(
                model.organizationId,
                management: true,
                includePrivate: true,
                createdBy: model.isManager ? null : model.uid,
              ),
            ),
            child: const _ManagementList(),
          );
        },
      ),
    );
  }
}

class _ManagementList extends StatefulWidget {
  const _ManagementList();
  @override
  State<_ManagementList> createState() => _ManagementListState();
}

class _ManagementListState extends State<_ManagementList> {
  String filter = 'All', search = '';
  @override
  Widget build(BuildContext context) {
    final query = context.watch<LiveQuery<List<OrgEvent>>>(),
        model = context.watch<EventContextViewModel>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                  labelText: 'Search Organization Events',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: filter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final status in [
                    'All',
                    'draft',
                    'published',
                    'cancelled',
                    'completed',
                    'Archived',
                  ])
                    DropdownMenuItem(
                      value: status,
                      child: Text(displayIdentifier(status)),
                    ),
                ],
                onChanged: (value) => setState(() => filter = value!),
              ),
            ],
          ),
        ),
        Expanded(
          child: QueryContent(
            query: query,
            builder: (values) {
              final events = (values ?? [])
                  .where(
                    (event) =>
                        event.title.toLowerCase().contains(
                          search.toLowerCase(),
                        ) &&
                        (filter == 'Archived'
                            ? event.archivedAt != null
                            : event.archivedAt == null &&
                                  (filter == 'All' ||
                                      event.eventStatus == filter)),
                  )
                  .toList();
              if (events.isEmpty) {
                return const Center(child: Text('No events match this view.'));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  for (final event in events)
                    EventCard(
                      event: event,
                      organizationName: model.organization.value!.name,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Participants'),
        actions: [
          if (model.organization.failure == null &&
              model.membership.failure == null &&
              canManageAttendance(
                model.organization.value,
                model.membership.value,
                model.uid,
              ))
            IconButton(
              tooltip: 'Attendance Verification',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => context.go(
                AppRoutes.attendance(model.organizationId, model.eventId!),
              ),
            ),
        ],
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go(AppRoutes.event(model.organizationId, model.eventId!)),
        ),
      ),
      body: EventAccessView(
        requireEvent: true,
        builder: (context) {
          if (!model.canViewParticipants) {
            return const Center(
              child: Text('You do not have permission to view participants.'),
            );
          }
          return ChangeNotifierProvider(
            create: (_) => ParticipantsViewModel(
              model.repository,
              model.organizationId,
              model.eventId!,
            ),
            child: const _ParticipantList(),
          );
        },
      ),
    );
  }
}

class _ParticipantList extends StatelessWidget {
  const _ParticipantList();
  String _timestamp(BuildContext context, DateTime? value) {
    if (value == null) return 'Not recorded';
    final local = value.toLocal(), format = MaterialLocalizations.of(context);
    return '${format.formatFullDate(local)}, ${format.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
  }

  @override
  Widget build(BuildContext context) {
    final participants = context.watch<ParticipantsViewModel>(),
        model = context.watch<EventContextViewModel>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${model.event!.value!.title} | Reserved: ${model.event!.value!.registrationCount}/${model.event!.value!.capacity}',
          ),
        ),
        Expanded(
          child: QueryContent(
            query: participants.registrations,
            builder: (records) {
              if ((records ?? []).isEmpty) {
                return const Center(child: Text('No registrations yet.'));
              }
              if (participants.identities.loading) {
                return const AppLoadingView(
                  message: 'Loading participant names...',
                );
              }
              return QueryContent(
                query: participants.identities,
                builder: (_) => ListView(
                  children: [
                    for (final record in records!)
                      ListTile(
                        title: Text(participants.nameFor(record.uid)),
                        subtitle: Text(
                          '${displayIdentifier(record.status)} \u00b7 ${_timestamp(context, record.registeredAt)}\nUpdated: ${_timestamp(context, record.updatedAt)}',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
