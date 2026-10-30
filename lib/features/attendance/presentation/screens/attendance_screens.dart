import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'attendance_correction_dialog.dart';
import '../../../events/presentation/widgets/event_sort.dart';

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
          leading: const AppBackButton(),
          title: const Text('Attendance Management'),
        ),
        body: AppPageBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const AppSectionHeading(
                  title: 'Your Event Attendance',
                  description: 'Select an organization to manage attendance.',
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.lg),

                if (authorized.isEmpty)
                  const AppEmptyView(
                    title: 'No Permissions',
                    message: 'You have no attendance management permissions.',
                  ),

                for (final org in authorized)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppSurfaceCard(
                      child: Theme(
                        // Remove the default ExpansionTile divider lines
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          key: ValueKey(org.id),
                          initiallyExpanded: org.id == initialOrganization,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                          ),
                          iconColor: AppColors.brandBlue,
                          collapsedIconColor: AppColors.muted,
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.brandBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: AppShape.button,
                                ),
                                child: const Icon(
                                  Icons.groups_outlined,
                                  color: AppColors.brandBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  org.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.brandMidnight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            _AttendanceEvents(
                              key: ValueKey('${org.id}/${orgs.uid}'),
                              org: org.id,
                            ),
                          ],
                        ),
                      ),
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
          for (final event in sortByChronology(query.value!))
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
      body = AppPageBody(
        child: SingleChildScrollView(
          // Added scroll for smaller screens
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              AppSectionHeading(
                title: report ? 'Attendance Overview' : 'Event Attendance',
                description: model.context.organization.value!.name,
                prominent: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSurfaceCard(child: EventSummary(event: event)),

              AppSurfaceCard(
                child: _MetricGroup(
                  children: [
                    _MetricTile(
                      label: 'Registered',
                      value: '${summary.registered}',
                      color: AppColors.brandBlue,
                    ),
                    _MetricTile(
                      label: 'Present',
                      value: '${summary.present}',
                      color: AppColors.success,
                    ),
                    _MetricTile(
                      label: 'Attendance',
                      value: summary.rate == null
                          ? '—'
                          : '${summary.rate!.toStringAsFixed(1)}%',
                      color: AppColors.brandMidnight,
                    ),
                  ],
                ),
              ),

              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppStatusChip(
                    label: '${summary.absent} Absent',
                    tone: AppStatusTone.error,
                  ),
                  AppStatusChip(
                    label: '${summary.notMarked} Not Marked',
                    tone: AppStatusTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Statistics use active registrations. Absent requires an explicit verification; missing records remain Not Marked.',
              ),
              if (!report)
                const Text(
                  'Normal verification cannot replace an existing result. Authorized organizers use Correct Attendance separately.',
                ),
              if (!report && model.manualUnavailableReason != null)
                Text(
                  model.manualUnavailableReason!,
                  style: const TextStyle(color: AppColors.error),
                ),

              const SizedBox(height: AppSpacing.lg),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!report)
                    FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.qrScan),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                    ),
                  if (report)
                    OutlinedButton(
                      onPressed: () => context.go(
                        AppRoutes.attendance(
                          model.context.organizationId,
                          event.id,
                        ),
                      ),
                      child: const Text('Verification Mode'),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Manual Lookup',
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search participants by name',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: AppShape.action,
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => model.setFilter(text: v),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: model.filter,
                decoration: InputDecoration(
                  labelText: 'Attendance Status',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: AppShape.action,
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  for (final entry in {
                    'All': 'All',
                    'present': 'Present',
                    'absent': 'Absent',
                    'notMarked': 'Not Marked',
                  }.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (v) => model.setFilter(status: v),
              ),

              if (model.busy)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: LinearProgressIndicator(),
                ),
              if (model.failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    model.failure!.message,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (model.correctionMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: AppStatusChip(
                    label: model.correctionMessage!,
                    tone: AppStatusTone.success,
                  ),
                ),
              if (model.result != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    model.result!.duplicate
                        ? 'Already Verified: ${attendanceLabel(model.result!.record)} | ${verificationLabel(model.result!.record)}'
                        : 'Attendance saved: ${attendanceLabel(model.result!.record)}.',
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              if (model.participants.isEmpty)
                const AppEmptyView(
                  title: 'No Participants Found',
                  message: 'No participants match this view.',
                ),

              for (final registration in model.participants)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                model.nameFor(registration.uid),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandMidnight,
                                    ),
                              ),
                            ),
                            Flexible(
                              child: AttendanceStatusBadge(
                                model.recordFor(registration.uid),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Registration: ${displayIdentifier(registration.status)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                        Text(
                          verificationLabel(model.recordFor(registration.uid)),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                        if (!report && model.canCorrect(registration)) ...[
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: model.busy
                                ? null
                                : () async {
                                    final preview = await model
                                        .previewCorrection(registration);
                                    if (!context.mounted ||
                                        preview == null ||
                                        !model.canCorrect(registration)) {
                                      return;
                                    }
                                    await showDialog<void>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) =>
                                          AttendanceCorrectionDialog(
                                            model: model,
                                            registration: registration,
                                            preview: preview,
                                          ),
                                    );
                                  },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Correct Attendance'),
                          ),
                        ],
                        if (!report && model.canMark(registration)) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                          await model.mark(
                                            registration,
                                            status,
                                          );
                                        },
                                  child: Text(
                                    'Mark ${displayIdentifier(status.name)}',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
          leading: const AppBackButton(),
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
      ),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
          leading: const AppBackButton(),
          title: const Text('My Attendance'),
        ),
        body: AppPageBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const AppSectionHeading(
                  title: 'Your Attendance',
                  description: 'Your event verification history',
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.lg),

                if (!pending)
                  AppSurfaceCard(
                    child: _MetricGroup(
                      children: [
                        _MetricTile(
                          label: 'Present',
                          value: '$present',
                          color: AppColors.success,
                        ),
                        _MetricTile(
                          label: 'Absent',
                          value: '$absent',
                          color: AppColors.error,
                        ),
                        _MetricTile(
                          label: 'Not Marked',
                          value: '${values.length - present - absent}',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),

                if (pending)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('Loading participation summary...'),
                  ),

                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Not Marked means Pending: no active attendance result. Organizer corrections update this view automatically.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.lg),

                if ((events.mine.value ?? []).isEmpty)
                  const AppEmptyView(
                    title: 'No Events',
                    message: 'You have no event registrations.',
                  ),

                for (final reg in events.mine.value ?? [])
                  Builder(
                    builder: (context) {
                      final key = '${reg.organizationId}/${reg.eventId}',
                          attendance = model.records[key],
                          query = events.registeredEvents[key],
                          event = query?.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppSurfaceCard(
                          child: LayoutBuilder(
                            builder: (context, constraints) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event?.title ?? 'Event Unavailable',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.brandMidnight,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            events
                                                    .availableOrganizations[reg
                                                        .organizationId]
                                                    ?.name ??
                                                'Organization Unavailable',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.brandBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (attendance?.loading == false &&
                                        attendance?.failure == null)
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth * 0.45,
                                        ),
                                        child: AttendanceStatusBadge(
                                          attendance?.value,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.md,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: AppColors.muted,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            schedule(event?.startAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.muted,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.confirmation_num_outlined,
                                          size: 14,
                                          color: AppColors.muted,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            displayIdentifier(reg.status),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.muted,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                if (query?.loading == true ||
                                    attendance?.loading == true)
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      top: AppSpacing.sm,
                                    ),
                                    child: LinearProgressIndicator(),
                                  ),
                                if (query?.failure != null)
                                  TextButton(
                                    onPressed: query!.retry,
                                    child: const Text('Retry Event Details'),
                                  ),
                                if (attendance?.failure != null)
                                  AppErrorView(
                                    message: attendance!.failure!.message,
                                    onRetry: attendance.retry,
                                  )
                                else if (attendance?.value != null) ...[
                                  const Divider(height: AppSpacing.xl),
                                  Text(
                                    verificationLabel(attendance?.value),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.brandMidnight,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preserve the approved three-column summary; stack only when enlarged text needs room.
class _MetricGroup extends StatelessWidget {
  const _MetricGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        children: [
          for (final entry in children.indexed) ...[
            if (entry.$1 > 0) const SizedBox(height: AppSpacing.lg),
            entry.$2,
          ],
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final entry in children.indexed) ...[
          if (entry.$1 > 0)
            Container(width: 1, height: 40, color: AppColors.border),
          Expanded(child: entry.$2),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge(this.record, {super.key});
  final AttendanceRecord? record;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: AppStatusChip(
      label: attendanceLabel(record),
      tone: record == null
          ? AppStatusTone.warning
          : record!.status == AttendanceStatus.present
          ? AppStatusTone.success
          : AppStatusTone.error,
    ),
  );
}
