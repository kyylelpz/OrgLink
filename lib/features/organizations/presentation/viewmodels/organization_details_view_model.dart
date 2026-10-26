import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../../../core/errors/app_failure.dart';
import '../../data/models/organization.dart';
import '../../data/repositories/organization_repository.dart';
import '../../../memberships/data/models/membership.dart';

class OrganizationDetailsViewModel extends ChangeNotifier {
  OrganizationDetailsViewModel(this.repository, this.id, this.uid) {
    organization = LiveQuery(() => repository.watchOrganization(id));
    membership = LiveQuery(() => repository.watchMembership(id, uid));
    events = LiveQuery(() => repository.upcomingEvents(id));
    organization.addListener(notifyListeners);
    membership.addListener(notifyListeners);
    events.addListener(notifyListeners);
  }
  final OrganizationRepository repository;
  final String id, uid;
  late final LiveQuery<Organization?> organization;
  late final LiveQuery<Membership?> membership;
  late final LiveQuery<List<PublishedEvent>> events;
  bool busy = false;
  bool submitted = false;
  bool _disposed = false;
  AppFailure? actionFailure;
  bool get isManager =>
      organization.failure == null && organization.value?.managerUid == uid;
  bool get canViewRoster =>
      isManager ||
      (membership.failure == null && membership.value?.canViewRoster == true);
  bool get canRequest =>
      !busy &&
      !submitted &&
      !isManager &&
      !membership.loading &&
      membership.failure == null &&
      membership.value == null &&
      organization.value?.acceptsRequests == true;
  Future<bool> request() async {
    if (!canRequest) return false;
    busy = true;
    actionFailure = null;
    notifyListeners();
    try {
      await repository.requestMembership(id, uid);
      if (!_disposed) submitted = true;
      return true;
    } catch (error) {
      if (!_disposed) actionFailure = AppFailure.from(error);
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void retry() {
    organization.retry();
    membership.retry();
    events.retry();
    actionFailure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    organization.dispose();
    membership.dispose();
    events.dispose();
    super.dispose();
  }
}
