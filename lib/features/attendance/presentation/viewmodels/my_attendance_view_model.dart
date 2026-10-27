import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/live_query.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';

class MyAttendanceViewModel extends ChangeNotifier {
  MyAttendanceViewModel(
    this.repository,
    this.events, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    events.addListener(_sync);
    _sync();
  }
  final AttendanceRepository repository;
  final EventHubViewModel events;
  final DateTime Function() _now;
  final Map<String, LiveQuery<AttendanceRecord?>> records = {};
  bool _disposed = false, busy = false;
  AppFailure? failure;
  QRCheckInCredential? credential;
  String? selected;
  Timer? _timer;
  Timer? _windowTimer;
  Stopwatch? _elapsed;
  int _generation = 0;
  String? _lastWindowDiagnostic;
  String? get windowMessage {
    final event = events.registeredEvents[selected]?.value;
    return event == null ? null : attendanceUnavailableReason(event, _now());
  }

  bool get canGenerate {
    final event = events.registeredEvents[selected], record = records[selected];
    return !busy &&
        !events.mine.loading &&
        events.mine.failure == null &&
        (events.mine.value ?? []).any(
          (r) =>
              '${r.organizationId}/${r.eventId}' == selected &&
              r.status == 'registered',
        ) &&
        event?.loading == false &&
        event?.failure == null &&
        event?.value != null &&
        windowMessage == null &&
        record?.loading == false &&
        record?.failure == null &&
        record?.value == null;
  }

  void _scheduleWindowRefresh() {
    _windowTimer?.cancel();
    final event = events.registeredEvents[selected]?.value;
    if (_disposed || event == null) return;
    final now = _now();
    // No Firestore refetch: wake at start/end, and periodically check clock changes.
    var delay = const Duration(seconds: 30);
    for (final boundary in [event.startAt, event.endAt]) {
      if (boundary != null && boundary.isAfter(now)) {
        final remaining = boundary.difference(now);
        if (remaining < delay) delay = remaining;
      }
    }
    _windowTimer = Timer(delay, _sync);
    if (kDebugMode) {
      final diagnostic =
          'QR window $selected: startAt=${event.startAt?.toUtc().toIso8601String()}, '
          'endAt=${event.endAt?.toUtc().toIso8601String()}, eventStatus=${event.eventStatus}, '
          'approvalStatus=${event.approvalStatus}, publishedAt=${event.publishedAt?.toUtc().toIso8601String()}, '
          'archivedAt=${event.archivedAt?.toUtc().toIso8601String()}, '
          'localStart=${event.startAt?.toLocal().toIso8601String()}, localEnd=${event.endAt?.toLocal().toIso8601String()}, '
          'offset=${now.timeZoneOffset}, reason=${windowMessage ?? 'open'}';
      if (diagnostic != _lastWindowDiagnostic) {
        _lastWindowDiagnostic = diagnostic;
        debugPrint(
          '$diagnostic; deviceNow=${now.toUtc().toIso8601String()}, localNow=${now.toLocal().toIso8601String()}',
        );
      }
    }
  }

  int get secondsRemaining => credential == null
      ? 0
      : ((credential!.expiresAt
                        .difference(credential!.serverTime)
                        .inMilliseconds -
                    (_elapsed?.elapsedMilliseconds ?? 0)) /
                1000)
            .ceil()
            .clamp(0, 60);
  void _sync() {
    if (_disposed) return;
    final desired = {
      for (final r in events.mine.value ?? [])
        '${r.organizationId}/${r.eventId}': r,
    };
    for (final key in records.keys.toList()) {
      if (!desired.containsKey(key)) records.remove(key)!.dispose();
    }
    for (final entry in desired.entries) {
      records.putIfAbsent(entry.key, () {
        final r = entry.value;
        final query = LiveQuery(
          () => repository.watchOwn(
            r.organizationId,
            r.eventId,
            events.organizations.uid,
          ),
        );
        query.addListener(_attendanceChanged);
        return query;
      });
    }
    if (selected != null &&
        (desired[selected]?.status != 'registered' ||
            records[selected]?.value != null ||
            events.registeredEvents[selected]?.failure != null ||
            (events.registeredEvents[selected]?.value != null &&
                !attendanceWindow(
                  events.registeredEvents[selected]!.value!,
                  _now(),
                )))) {
      credential = null;
      _timer?.cancel();
      _generation++;
      busy = false;
    }
    _scheduleWindowRefresh();
    notifyListeners();
  }

  void _attendanceChanged() {
    final query = records[selected];
    if (query?.value != null || query?.failure != null) {
      credential = null;
      _timer?.cancel();
      _generation++;
      busy = false;
    }
    notifyListeners();
  }

  void select(String? key) {
    selected = key;
    credential = null;
    failure = null;
    _generation++;
    busy = false;
    _timer?.cancel();
    _scheduleWindowRefresh();
    notifyListeners();
  }

  void refresh() {
    select(selected);
    events.mine.retry();
    events.registeredEvents[selected]?.retry();
    records[selected]?.retry();
  }

  Future<void> generate() async {
    if (_disposed || busy || selected == null) return;
    if (!canGenerate) {
      failure = AppFailure(
        windowMessage ??
            'An active registration, open attendance window and unverified attendance are required.',
      );
      notifyListeners();
      return;
    }
    final parts = selected!.split('/'), generation = ++_generation;
    busy = true;
    failure = null;
    credential = null;
    _timer?.cancel();
    final elapsed = Stopwatch()..start();
    notifyListeners();
    try {
      final value = await repository.issue(parts[0], parts[1]);
      if (_disposed || generation != _generation) return;
      credential = value;
      _elapsed = elapsed;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_disposed) {
          notifyListeners();
          if (secondsRemaining == 0) _timer?.cancel();
        }
      });
    } catch (e) {
      if (!_disposed && generation == _generation) failure = AppFailure.from(e);
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _windowTimer?.cancel();
    events.removeListener(_sync);
    for (final q in records.values) {
      q.dispose();
    }
    super.dispose();
  }
}
