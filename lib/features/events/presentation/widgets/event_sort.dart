import '../../data/models/event.dart';

/// Canonical chronological order used across the app:
///   0. ongoing         (started, not yet ended) — most urgent
///   1. nearest future  (startAt ascending)
///   2. later future    (same rank, falls out of ascending)
///   3. recent past     (startAt descending)
///   4. old past        (same rank, falls out of descending)
/// Undated events go last.
List<OrgEvent> sortByChronology(
  Iterable<OrgEvent> events, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();

  int rank(OrgEvent? e) {
    final start = e?.startAt;
    final end = e?.endAt;
    if (start == null) return 4;
    final isOngoing = !start.isAfter(n) && (end?.isAfter(n) ?? false);
    if (isOngoing) return 0;
    if (start.isAfter(n)) return 1;
    return 2;
  }

  return [...events]..sort((a, b) {
    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);

    final sa = a.startAt;
    final sb = b.startAt;
    if (sa == null && sb == null) return 0;
    if (sa == null) return 1;
    if (sb == null) return -1;

    return ra == 2 ? sb.compareTo(sa) : sa.compareTo(sb);
  });
}