import '../../../../core/errors/app_failure.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../../organizations/data/models/organization.dart';
import '../../../organizations/presentation/viewmodels/organization_hub_view_model.dart';
import '../../data/models/event.dart';
import '../../data/models/event_registration.dart';
import '../../data/repositories/event_repository.dart';

class EventHubViewModel extends ChangeNotifier {
  EventHubViewModel(this.repository, this.organizations) {
    mine = LiveQuery(() => repository.myRegistrations(organizations.uid));
    mine.addListener(_syncRegistrations);
    organizations.addListener(_syncCatalog);
    _syncCatalog();
  }
  final EventRepository repository;
  final OrganizationHubViewModel organizations;
  late final LiveQuery<List<EventRegistration>> mine;
  final Map<String, LiveQuery<List<OrgEvent>>> catalog = {};
  final Map<String, LiveQuery<OrgEvent?>> registeredEvents = {};
  final Set<String> withdrawing = {};
  final Set<String> refreshingNames = {};
  AppFailure? actionFailure;
  bool _disposed = false;
  String search = '', period = 'All';
  String? organizationFilter;
  Map<String, Organization> get availableOrganizations => {
    for (final org in organizations.discovery.value ?? <Organization>[])
      org.id: org,
    for (final query in organizations.associated.values)
      if (query.value != null) query.value!.id: query.value!,
    for (final org in organizations.managed.value ?? <Organization>[])
      org.id: org,
  };
  List<Organization> get managementOrganizations => availableOrganizations
      .values
      .where(
        (org) =>
            org.status == 'active' &&
            (org.managerUid == organizations.uid ||
                (organizations.membership(org.id)?.role == 'officer' &&
                    organizations.membership(org.id)?.status == 'active' &&
                    organizations
                            .membership(org.id)
                            ?.permissions['manageEvents'] ==
                        true)),
      )
      .toList();
  List<OrgEvent> get results {
    final now = DateTime.now();
    final unique = <String, OrgEvent>{};
    for (final query in catalog.values) {
      for (final event in query.value ?? <OrgEvent>[]) {
        unique['${event.organizationId}/${event.id}'] = event;
      }
    }
    return unique.values.where((event) {
      if (event.archivedAt != null ||
          !event.title.toLowerCase().contains(search.toLowerCase().trim()) ||
          (organizationFilter != null &&
              event.organizationId != organizationFilter)) {
        return false;
      }
      final start = event.startAt, end = event.endAt;
      if (start == null || end == null) return false;
      return switch (period) {
        'Upcoming' => start.isAfter(now),
        'Ongoing' => !start.isAfter(now) && end.isAfter(now),
        'Past' => !end.isAfter(now),
        _ => true,
      };
    }).toList()..sort((a, b) => a.startAt!.compareTo(b.startAt!));
  }

  void filter({
    String? text,
    String? time,
    String? organization,
    bool resetOrganization = false,
  }) {
    if (text != null) search = text;
    if (time != null) period = time;
    if (resetOrganization) {
      organizationFilter = null;
    } else if (organization != null) {
      organizationFilter = organization;
    }
    notifyListeners();
  }

  void _syncCatalog() {
    if (organizationFilter != null &&
        !availableOrganizations.containsKey(organizationFilter)) {
      organizationFilter = null;
    }
    final desired = <String, Organization>{};
    for (final org in availableOrganizations.values) {
      final member = organizations.membership(org.id);
      final manager = org.managerUid == organizations.uid;
      if (org.status != 'active' ||
          !(org.visibility == 'public' ||
              manager ||
              member?.status == 'active')) {
        continue;
      }
      final includePrivate = manager || member?.status == 'active';
      desired['${org.id}/$includePrivate'] = org;
    }
    for (final key in catalog.keys.toList()) {
      if (!desired.containsKey(key)) catalog.remove(key)!.dispose();
    }
    for (final entry in desired.entries) {
      catalog.putIfAbsent(entry.key, () {
        final query = LiveQuery(
          () => repository.organizationEvents(
            entry.value.id,
            management: false,
            includePrivate: entry.key.endsWith('/true'),
          ),
        );
        query.addListener(notifyListeners);
        return query;
      });
    }
    notifyListeners();
  }

  void _syncRegistrations() {
    final desired = {
      for (final registration in mine.value ?? <EventRegistration>[])
        '${registration.organizationId}/${registration.eventId}': registration,
    };
    for (final key in registeredEvents.keys.toList()) {
      if (!desired.containsKey(key)) registeredEvents.remove(key)!.dispose();
    }
    for (final entry in desired.entries) {
      registeredEvents.putIfAbsent(entry.key, () {
        final query = LiveQuery(
          () => repository.watchEvent(
            entry.value.organizationId,
            entry.value.eventId,
          ),
        );
        query.addListener(notifyListeners);
        return query;
      });
    }
    notifyListeners();
  }

  Future<bool> withdraw(EventRegistration registration) async {
    final key = '${registration.organizationId}/${registration.eventId}';
    if (_disposed || withdrawing.contains(key)) return false;
    withdrawing.add(key);
    actionFailure = null;
    notifyListeners();
    try {
      await repository.register(
        registration.organizationId,
        registration.eventId,
        organizations.uid,
        withdraw: true,
      );
      return true;
    } catch (error) {
      if (!_disposed) actionFailure = AppFailure.from(error);
      return false;
    } finally {
      if (!_disposed) {
        withdrawing.remove(key);
        notifyListeners();
      }
    }
  }

  Future<bool> refreshName(EventRegistration registration) async {
    final key = '${registration.organizationId}/${registration.eventId}';
    if (_disposed || refreshingNames.contains(key)) return false;
    refreshingNames.add(key);
    actionFailure = null;
    notifyListeners();
    try {
      await repository.refreshParticipantIdentity(
        registration.organizationId,
        registration.eventId,
        organizations.uid,
      );
      return true;
    } catch (error) {
      if (!_disposed) actionFailure = AppFailure.from(error);
      return false;
    } finally {
      if (!_disposed) {
        refreshingNames.remove(key);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    organizations.removeListener(_syncCatalog);
    mine.dispose();
    for (final query in catalog.values) {
      query.dispose();
    }
    for (final query in registeredEvents.values) {
      query.dispose();
    }
    super.dispose();
  }
}
