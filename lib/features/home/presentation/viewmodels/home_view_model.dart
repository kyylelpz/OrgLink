import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../events/data/models/event.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../../organizations/data/models/organization.dart';

/// Presentation-only selection over the existing authorized event/organization streams.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this.hub, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    hub.addListener(notifyListeners);
  }
  final EventHubViewModel hub;
  final DateTime Function() _now;
  String search = '';
  bool get loading =>
      hub.organizations.discovery.loading ||
      hub.organizations.mine.loading ||
      hub.organizations.managed.loading ||
      hub.organizations.associated.values.any((q) => q.loading) ||
      hub.catalog.values.any((q) => q.loading);
  AppFailure? get failure {
    final orgs = hub.organizations;
    for (final error in [
      orgs.discovery.failure,
      orgs.mine.failure,
      orgs.managed.failure,
      ...orgs.associated.values.map((q) => q.failure),
      ...hub.catalog.values.map((q) => q.failure),
    ]) {
      if (error != null) return error;
    }
    return null;
  }

  List<OrgEvent> get _events {
    final events = <String, OrgEvent>{};
    for (final query in hub.catalog.values) {
      for (final event in query.value ?? <OrgEvent>[]) {
        if (event.eventStatus == 'published' &&
            event.approvalStatus == 'approved' &&
            event.publishedAt != null &&
            event.archivedAt == null) {
          events['${event.organizationId}/${event.id}'] = event;
        }
      }
    }
    return events.values.toList()..sort((a, b) {
      final time = (a.startAt ?? DateTime(9999)).compareTo(
        b.startAt ?? DateTime(9999),
      );
      return time != 0
          ? time
          : '${a.organizationId}/${a.id}'.compareTo(
              '${b.organizationId}/${b.id}',
            );
    });
  }

  List<OrgEvent> get upcoming =>
      _events.where((e) => e.startAt?.isAfter(_now()) == true).take(2).toList();
  List<OrgEvent> get ongoing => _events.where((e) {
    final start = e.startAt;
    final end = e.endAt;
    if (start == null || end == null) return false;
    final now = _now();
    return !start.isAfter(now) && end.isAfter(now);
  }).toList();
  List<OrgEvent> get matchingEvents => _events
      .where((e) => e.title.toLowerCase().contains(search.trim().toLowerCase()))
      .toList();
  List<Organization> get matchingOrganizations =>
      hub.availableOrganizations.values
          .where(
            (o) => o.name.toLowerCase().contains(search.trim().toLowerCase()),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  void searchFor(String value) {
    search = value;
    notifyListeners();
  }

  void retry() {
    hub.organizations.retry();
    for (final query in hub.catalog.values) {
      query.retry();
    }
  }

  @override
  void dispose() {
    hub.removeListener(notifyListeners);
    super.dispose();
  }
}
