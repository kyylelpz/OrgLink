import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/live_query.dart';
import '../../../events/data/models/event_registration.dart';
import '../../../events/data/models/participant_identity.dart';
import '../../../events/presentation/viewmodels/event_context_view_model.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';

class AttendanceViewModel extends ChangeNotifier {
  AttendanceViewModel(this.repository, this.context, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    context.addListener(_sync);
    _sync();
  }
  final AttendanceRepository repository;
  final EventContextViewModel context;
  final DateTime Function() _now;
  Timer? _windowTimer;
  LiveQuery<List<AttendanceRecord>>? records;
  LiveQuery<List<EventRegistration>>? registrations;
  LiveQuery<List<ParticipantIdentity>>? identities;
  bool _disposed = false, busy = false;
  AppFailure? failure;
  AttendanceResult? result;
  String? correctionMessage;
  String search = '', filter = 'All';
  bool get authorized =>
      canManageAttendance(
        context.organization.value,
        context.membership.value,
        context.uid,
      ) &&
      context.organization.failure == null &&
      context.membership.failure == null;
  bool get loading =>
      context.organization.loading ||
      context.membership.loading ||
      context.event?.loading == true ||
      records?.loading == true ||
      registrations?.loading == true ||
      identities?.loading == true;
  AppFailure? get loadFailure =>
      context.organization.failure ??
      context.membership.failure ??
      context.event?.failure ??
      records?.failure ??
      registrations?.failure ??
      identities?.failure;
  AttendanceSummary get summary =>
      AttendanceSummary(registrations?.value ?? [], records?.value ?? []);
  String? get manualUnavailableReason {
    final event = context.event?.value;
    return event == null
        ? 'Event no longer available.'
        : attendanceUnavailableReason(event, _now());
  }

  bool canMark(EventRegistration registration) =>
      authorized &&
      !loading &&
      loadFailure == null &&
      registration.status == 'registered' &&
      registration.uid != context.uid &&
      registration.organizationId == context.organizationId &&
      registration.eventId == context.eventId &&
      recordFor(registration.uid) == null &&
      manualUnavailableReason == null;
  bool canCorrect(EventRegistration registration) {
    final event = context.event?.value;
    return authorized &&
        context.organization.value?.managerUid == context.uid &&
        !loading &&
        loadFailure == null &&
        registration.uid != context.uid &&
        registration.organizationId == context.organizationId &&
        registration.eventId == context.eventId &&
        ['registered', 'cancelled'].contains(registration.status) &&
        recordFor(registration.uid) != null &&
        event != null &&
        ['published', 'completed'].contains(event.eventStatus) &&
        event.approvalStatus == 'approved' &&
        event.publishedAt != null &&
        event.archivedAt == null &&
        event.startAt != null &&
        !_now().isBefore(event.startAt!);
  }

  Future<T?> _correction<T>(
    EventRegistration registration,
    Future<T> Function() action,
  ) async {
    if (_disposed || busy) return null;
    if (!canCorrect(registration)) {
      failure = const AppFailure(
        'Attendance or permissions changed. Close this dialog and refresh the roster before correcting.',
      );
      notifyListeners();
      return null;
    }
    busy = true;
    failure = null;
    result = null;
    correctionMessage = null;
    notifyListeners();
    try {
      final value = await action();
      if (_disposed ||
          !authorized ||
          context.organization.value?.managerUid != context.uid) {
        return null;
      }
      return value;
    } catch (error) {
      if (!_disposed && authorized) failure = AppFailure.from(error);
      return null;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<AttendanceCorrectionPreview?> previewCorrection(
    EventRegistration registration,
  ) => _correction(
    registration,
    () => repository.previewCorrection(
      context.organizationId,
      context.eventId!,
      registration.uid,
    ),
  );

  Future<bool> correct(
    EventRegistration registration,
    AttendanceCorrectionPreview preview,
    AttendanceCorrectionStatus status,
    String reason,
  ) async {
    if (reason.trim().isEmpty || reason.trim().length > 1000) return false;
    final success = await _correction(registration, () async {
      await repository.correct(
        context.organizationId,
        context.eventId!,
        registration.uid,
        preview,
        status,
        reason.trim(),
      );
      return true;
    });
    if (success != true) return false;
    correctionMessage = status == AttendanceCorrectionStatus.pending
        ? 'Attendance reset to Pending (Not Marked). Correction history was retained.'
        : 'Attendance corrected. Correction history was retained.';
    records?.retry();
    notifyListeners();
    return true;
  }

  String nameFor(String uid) {
    for (final identity in identities?.value ?? <ParticipantIdentity>[]) {
      if (identity.uid == uid && identity.fullName.trim().isNotEmpty) {
        return identity.fullName;
      }
    }
    return 'Unknown Participant';
  }

  AttendanceRecord? recordFor(String uid) {
    for (final record in records?.value ?? <AttendanceRecord>[]) {
      if (record.uid == uid) return record;
    }
    return null;
  }

  List<EventRegistration> get participants =>
      (registrations?.value ?? <EventRegistration>[])
          .where(
            (r) =>
                nameFor(
                  r.uid,
                ).toLowerCase().contains(search.toLowerCase().trim()) &&
                (filter == 'All' ||
                    (recordFor(r.uid)?.status.name ?? 'notMarked') == filter),
          )
          .toList();
  void setFilter({String? text, String? status}) {
    search = text ?? search;
    filter = status ?? filter;
    notifyListeners();
  }

  void _refreshWindowTimer() {
    _windowTimer?.cancel();
    final event = context.event?.value;
    if (!authorized || event == null) return;
    final now = _now();
    var delay = const Duration(seconds: 30);
    for (final boundary in [event.startAt, event.endAt]) {
      if (boundary != null && boundary.isAfter(now)) {
        final remaining = boundary.difference(now);
        if (remaining < delay) delay = remaining;
      }
    }
    _windowTimer = Timer(delay, _sync);
  }

  void _sync() {
    if (_disposed) return;
    if (authorized && records == null && context.eventId != null) {
      records = LiveQuery(
        () => repository.records(context.organizationId, context.eventId!),
      );
      registrations = LiveQuery(
        () => context.repository.participants(
          context.organizationId,
          context.eventId!,
        ),
      );
      identities = LiveQuery(
        () => context.repository.participantIdentities(
          context.organizationId,
          context.eventId!,
        ),
      );
      records!.addListener(notifyListeners);
      registrations!.addListener(notifyListeners);
      identities!.addListener(notifyListeners);
    } else if (!authorized) {
      _clear();
      result = null;
      failure = null;
      correctionMessage = null;
    }
    _refreshWindowTimer();
    notifyListeners();
  }

  void _clear() {
    records?.dispose();
    registrations?.dispose();
    identities?.dispose();
    records = null;
    registrations = null;
    identities = null;
  }

  void retry() {
    context.organization.retry();
    context.membership.retry();
    context.event?.retry();
    records?.retry();
    registrations?.retry();
    identities?.retry();
  }

  Future<AttendanceResult?> mark(
    EventRegistration registration,
    AttendanceStatus status,
  ) async {
    if (_disposed || busy || !authorized || loading || loadFailure != null) {
      return null;
    }
    if (registration.uid == context.uid ||
        registration.status != 'registered' ||
        registration.organizationId != context.organizationId ||
        registration.eventId != context.eventId) {
      failure = const AppFailure(
        'Select another student with an active registration.',
      );
      notifyListeners();
      return null;
    }
    final old = recordFor(registration.uid);
    if (old != null) {
      result = AttendanceResult(old, duplicate: true);
      notifyListeners();
      return result;
    }
    final event = context.event?.value;
    if (event == null || !attendanceWindow(event, _now())) {
      failure = const AppFailure(
        'Attendance is available only during the published event. Server time determines final eligibility.',
      );
      notifyListeners();
      return null;
    }
    busy = true;
    failure = null;
    result = null;
    notifyListeners();
    try {
      final value = await repository.mark(
        context.organizationId,
        context.eventId!,
        registration.uid,
        context.uid,
        status,
      );
      if (_disposed || !authorized) return null;
      result = value;
      return value;
    } catch (e) {
      if (!_disposed && authorized) failure = AppFailure.from(e);
      return null;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _windowTimer?.cancel();
    context.removeListener(_sync);
    _clear();
    super.dispose();
  }
}
