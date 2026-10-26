import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/live_query.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';

class MyAttendanceViewModel extends ChangeNotifier {
  MyAttendanceViewModel(this.repository, this.events) {
    events.addListener(_sync);
    _sync();
  }
  final AttendanceRepository repository;
  final EventHubViewModel events;
  final Map<String, LiveQuery<AttendanceRecord?>> records = {};
  bool _disposed = false, busy = false;
  AppFailure? failure;
  QRCheckInCredential? credential;
  String? selected;
  Timer? _timer;
  Stopwatch? _elapsed;
  int _generation = 0;
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
                  DateTime.now(),
                )))) {
      credential = null;
      _timer?.cancel();
      _generation++;
      busy = false;
    }
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
    final key = selected!, parts = key.split('/'), generation = ++_generation;
    final reg = (events.mine.value ?? []).where(
      (r) =>
          r.organizationId == parts[0] &&
          r.eventId == parts[1] &&
          r.status == 'registered',
    );
    final event = events.registeredEvents[key]?.value;
    if (reg.isEmpty ||
        event == null ||
        !attendanceWindow(event, DateTime.now()) ||
        records[key]?.value != null ||
        records[key]?.loading != false ||
        records[key]?.failure != null) {
      failure = const AppFailure(
        'An active registration, open attendance window and unverified attendance are required.',
      );
      notifyListeners();
      return;
    }
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
    events.removeListener(_sync);
    for (final q in records.values) {
      q.dispose();
    }
    super.dispose();
  }
}
