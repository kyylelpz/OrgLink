import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../data/models/organization.dart';
import '../../data/repositories/organization_repository.dart';
import '../../../memberships/data/models/membership.dart';

enum OrganizationBrowseFilter { all, joined, discover }

class OrganizationHubViewModel extends ChangeNotifier {
  OrganizationHubViewModel(this.repository, this.uid) {
    discovery = LiveQuery(repository.discover);
    mine = LiveQuery(() => repository.myMemberships(uid));
    managed = LiveQuery(() => repository.managed(uid));
    discovery.addListener(notifyListeners);
    managed.addListener(notifyListeners);
    mine.addListener(_membershipsChanged);
  }
  final OrganizationRepository repository;
  final String uid;
  late final LiveQuery<List<Organization>> discovery, managed;
  late final LiveQuery<List<Membership>> mine;
  final Map<String, LiveQuery<Organization?>> associated = {};
  String search = '';
  OrganizationBrowseFilter browseFilter = OrganizationBrowseFilter.all;
  List<Organization> get browseResults {
    final orgs = {
      for (final org in discovery.value ?? <Organization>[]) org.id: org,
      for (final query in associated.values)
        if (query.value != null) query.value!.id: query.value!,
      for (final org in managed.value ?? <Organization>[]) org.id: org,
    };
    return orgs.values.where((org) {
      final joined =
          membership(org.id)?.status == 'active' || org.managerUid == uid;
      return org.name.toLowerCase().contains(search.toLowerCase().trim()) &&
          switch (browseFilter) {
            OrganizationBrowseFilter.all => true,
            OrganizationBrowseFilter.joined => joined,
            OrganizationBrowseFilter.discover =>
              !joined && org.visibility == 'public' && org.status == 'active',
          };
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  void browse(OrganizationBrowseFilter value) {
    browseFilter = value;
    notifyListeners();
  }

  List<Organization> get results =>
      (discovery.value ?? [])
          .where(
            (org) =>
                org.name.toLowerCase().contains(search.toLowerCase().trim()),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  Membership? membership(String id) {
    for (final entry in mine.value ?? <Membership>[]) {
      if (entry.organizationId == id) return entry;
    }
    return null;
  }

  void searchFor(String value) {
    search = value;
    notifyListeners();
  }

  void _membershipsChanged() {
    final ids = (mine.value ?? <Membership>[])
        .map((entry) => entry.organizationId)
        .toSet();
    for (final id in associated.keys.toList()) {
      if (!ids.contains(id)) {
        associated.remove(id)!.dispose();
      }
    }
    for (final id in ids) {
      associated.putIfAbsent(id, () {
        final query = LiveQuery(() => repository.watchOrganization(id));
        query.addListener(notifyListeners);
        return query;
      });
    }
    notifyListeners();
  }

  void retry() {
    discovery.retry();
    mine.retry();
    managed.retry();
    for (final query in associated.values) {
      query.retry();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    discovery.dispose();
    mine.dispose();
    managed.dispose();
    for (final value in associated.values) {
      value.dispose();
    }
    super.dispose();
  }
}
