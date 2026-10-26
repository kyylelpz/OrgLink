import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/utils/live_query.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../events/data/models/event.dart';
import '../../../events/data/repositories/event_repository.dart';
import '../../../events/presentation/widgets/event_widgets.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../data/models/attendance.dart';
import '../viewmodels/attendance_view_model.dart';
import '../viewmodels/my_attendance_view_model.dart';

String attendanceLabel(AttendanceRecord? record) =>
    record == null ? 'Not Marked' : displayIdentifier(record.status.name);
String verificationLabel(AttendanceRecord? record) => record == null
    ? 'No verification recorded.'
    : '${record.method == VerificationMethod.qr ? 'QR' : 'Manual'} | ${schedule(record.verifiedAt)}';

class AttendanceSelectionScreen extends StatelessWidget {
  const AttendanceSelectionScreen({super.key, this.initialOrganization});
  final String? initialOrganization;
  @override
  Widget build(BuildContext context) {
    final hub = context.watch<EventHubViewModel>(), orgs = hub.organizations;
    if (orgs.managed.loading || orgs.mine.loading) {
      return const Scaffold(body: AppLoadingView());
    }
    if (orgs.managed.failure != null || orgs.mine.failure != null) {
      return Scaffold(
        body: AppErrorView(
          message: 'Attendance permissions could not be loaded.',
          onRetry: orgs.retry,
        ),
      );
    }
    final authorized = hub.availableOrganizations.values
        .where(
          (org) => canManageAttendance(org, orgs.membership(org.id), orgs.uid),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Select an organization, then choose an event for verification or reporting.',
          ),
          if (authorized.isEmpty)
            const Text('You have no attendance management permissions.'),
          for (final org in authorized)
            ExpansionTile(
              key: ValueKey(org.id),
              initiallyExpanded: org.id == initialOrganization,
              title: Text(org.name),
              children: [
                _AttendanceEvents(
                  key: ValueKey('${org.id}/${orgs.uid}'),
                  org: org.id,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AttendanceEvents extends StatefulWidget {
  const _AttendanceEvents({super.key, required this.org});
  final String org;
  @override
  State<_AttendanceEvents> createState() => _AttendanceEventsState();
}

class _AttendanceEventsState extends State<_AttendanceEvents> {
  late final LiveQuery<List<OrgEvent>> query;
  @override
  void initState() {
    super.initState();
    query = LiveQuery(
      () => context.read<EventRepository>().organizationEvents(
        widget.org,
        management: true,
        includePrivate: true,
      ),
    );
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: query,
    builder: (context, _) {
      if (query.loading) return const LinearProgressIndicator();
      if (query.failure != null) {
        return AppErrorView(
          message: query.failure!.message,
          onRetry: query.retry,
        );
      }
      if (query.value!.isEmpty) return const Text('No events available.');
      return Column(
        children: [
          for (final event in query.value!)
            ListTile(
              title: Text(event.title),
              subtitle: Text(
                '${schedule(event.startAt)} | ${displayIdentifier(event.eventStatus)}',
              ),
              onTap: () =>
                  context.go(AppRoutes.attendance(widget.org, event.id)),
              trailing: IconButton(
                tooltip: 'Attendance Report',
                icon: const Icon(Icons.assessment),
                onPressed: () => context.go(
                  AppRoutes.attendanceReport(widget.org, event.id),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, this.report = false});
  final bool report;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AttendanceViewModel>();
    Widget body;
    if (model.loading) {
      body = const AppLoadingView();
    } else if (model.loadFailure != null) {
      body = AppErrorView(
        message: model.loadFailure!.message,
        onRetry: model.retry,
      );
    } else if (!model.authorized) {
      body = const Center(
        child: Text(
          'You do not have permission to manage attendance for this organization.',
        ),
      );
    } else if (model.context.event?.value == null) {
      body = const Center(child: Text('Event no longer available.'));
    } else {
      final event = model.context.event!.value!, summary = model.summary;
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(model.context.organization.value!.name),
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          Text('${schedule(event.startAt)} - ${schedule(event.endAt)}'),
          Text(
            'Registered: ${summary.registered} | Present: ${summary.present} | Absent: ${summary.absent} | Not Marked: ${summary.notMarked}',
          ),
          Text(
            summary.rate == null
                ? 'No eligible registered participants.'
                : 'Attendance Rate: ${summary.rate!.toStringAsFixed(1)}%',
          ),
          const Text(
            'Statistics use active registrations. Absent requires an explicit verification; missing records remain Not Marked.',
          ),
          if (!report)
            const Text(
              'The first verification is final. Server time and current permissions determine whether marking is allowed.',
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => context.go(
                  AppRoutes.attendanceManagement(model.context.organizationId),
                ),
                child: const Text('Select Event'),
              ),
              TextButton(
                onPressed: () => context.go(
                  report
                      ? AppRoutes.attendance(
                          model.context.organizationId,
                          event.id,
                        )
                      : AppRoutes.attendanceReport(
                          model.context.organizationId,
                          event.id,
                        ),
                ),
                child: Text(
                  report ? 'Attendance Verification' : 'Attendance Report',
                ),
              ),
              if (!report)
                TextButton(
                  onPressed: () => context.go(AppRoutes.qrScan),
                  child: const Text('Scan QR Code'),
                ),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Manual Lookup',
              hintText: 'Search participants by name',
            ),
            onChanged: (v) => model.setFilter(text: v),
          ),
          DropdownButtonFormField<String>(
            initialValue: model.filter,
            decoration: const InputDecoration(labelText: 'Attendance Status'),
            items: [
              for (final entry in {
                'All': 'All',
                'present': 'Present',
                'absent': 'Absent',
                'notMarked': 'Not Marked',
              }.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => model.setFilter(status: v),
          ),
          if (model.busy) const LinearProgressIndicator(),
          if (model.failure != null) Text(model.failure!.message),
          if (model.result != null)
            Text(
              model.result!.duplicate
                  ? 'Already Verified: ${attendanceLabel(model.result!.record)} | ${verificationLabel(model.result!.record)}'
                  : 'Attendance saved: ${attendanceLabel(model.result!.record)}.',
            ),
          if (model.participants.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No participants match this view.'),
            ),
          for (final registration in model.participants)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.nameFor(registration.uid),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Registration: ${displayIdentifier(registration.status)} | Attendance: ${attendanceLabel(model.recordFor(registration.uid))}',
                    ),
                    Text(verificationLabel(model.recordFor(registration.uid))),
                    if (!report &&
                        registration.status == 'registered' &&
                        registration.uid != model.context.uid &&
                        model.recordFor(registration.uid) == null &&
                        attendanceWindow(event, DateTime.now()))
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final status in AttendanceStatus.values)
                            OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () async {
                                      if (!await confirmEventAction(
                                            context,
                                            'Mark ${displayIdentifier(status.name)}?',
                                            'This attendance result is final. Confirm the participant and status before continuing.',
                                          ) ||
                                          !context.mounted) {
                                        return;
                                      }
                                      await model.mark(registration, status);
                                    },
                              child: Text(
                                'Mark ${displayIdentifier(status.name)}',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(report ? 'Attendance Report' : 'Attendance Verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: model.busy ? null : model.retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }
}

class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<MyAttendanceViewModel>(), events = model.events;
    if (events.mine.loading) return const Scaffold(body: AppLoadingView());
    if (events.mine.failure != null) {
      return Scaffold(
        body: AppErrorView(
          message: events.mine.failure!.message,
          onRetry: events.mine.retry,
        ),
      );
    }
    final values = model.records.values;
    final present = values
        .where((q) => q.value?.status == AttendanceStatus.present)
        .length;
    final absent = values
        .where((q) => q.value?.status == AttendanceStatus.absent)
        .length;
    final pending = values.any((q) => q.loading || q.failure != null);
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            pending
                ? 'Participation summary is unavailable until all attendance records load.'
                : 'Present: $present | Absent: $absent | Not Marked: ${values.length - present - absent}',
          ),
          if ((events.mine.value ?? []).isEmpty)
            const Text('You have no event registrations.'),
          for (final reg in events.mine.value ?? [])
            Builder(
              builder: (context) {
                final key = '${reg.organizationId}/${reg.eventId}',
                    attendance = model.records[key],
                    query = events.registeredEvents[key],
                    event = query?.value;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event?.title ?? 'Event Unavailable',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          events
                                  .availableOrganizations[reg.organizationId]
                                  ?.name ??
                              'Organization Unavailable',
                        ),
                        Text(
                          '${schedule(event?.startAt)} | Registration: ${displayIdentifier(reg.status)}',
                        ),
                        if (query?.loading == true)
                          const LinearProgressIndicator(),
                        if (query?.failure != null)
                          TextButton(
                            onPressed: query!.retry,
                            child: const Text('Retry Event Details'),
                          ),
                        if (attendance?.loading == true)
                          const LinearProgressIndicator()
                        else if (attendance?.failure != null)
                          AppErrorView(
                            message: attendance!.failure!.message,
                            onRetry: attendance.retry,
                          )
                        else ...[
                          Text(attendanceLabel(attendance?.value)),
                          Text(verificationLabel(attendance?.value)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
