import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../organizations/data/repositories/organization_repository.dart';
import '../../data/models/membership.dart';

class MemberListViewModel extends ChangeNotifier {
  MemberListViewModel(
    this.repository,
    this.organizationId,
    this.uid, {
    required this.pending,
  }) {
    records = LiveQuery(
      () => repository.members(organizationId, pending ? 'pending' : 'active'),
    );
    records.addListener(notifyListeners);
  }
  final OrganizationRepository repository;
  final String organizationId, uid;
  final bool pending;
  late final LiveQuery<List<Membership>> records;
  final Set<String> processing = {};
  AppFailure? failure;
  bool _disposed = false;
  Future<bool> review(Membership member, {required bool approve}) async {
    if (!pending ||
        member.uid == uid ||
        member.status != 'pending' ||
        processing.contains(member.uid)) {
      return false;
    }
    processing.add(member.uid);
    failure = null;
    notifyListeners();
    try {
      await repository.reviewMembership(
        organizationId,
        member.uid,
        uid,
        approve: approve,
      );
      return true;
    } catch (error) {
      if (!_disposed) failure = AppFailure.from(error);
      return false;
    } finally {
      if (!_disposed) {
        processing.remove(member.uid);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    records.dispose();
    super.dispose();
  }
}
