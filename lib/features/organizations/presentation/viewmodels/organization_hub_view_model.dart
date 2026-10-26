import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../data/models/organization.dart';
import '../../data/repositories/organization_repository.dart';
import '../../../memberships/data/models/membership.dart';

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
