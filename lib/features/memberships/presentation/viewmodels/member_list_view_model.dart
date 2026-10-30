import 'package:flutter/foundation.dart';
import 'dart:math';
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
    this.manager = false,
  }) {
    records = LiveQuery(
      () => repository.members(organizationId, pending ? 'pending' : 'active'),
    );
    records.addListener(notifyListeners);
    if (manager && !pending) {
      former = LiveQuery(() => repository.members(organizationId, 'removed'));
      former!.addListener(notifyListeners);
    }
  }
  final OrganizationRepository repository;
  final String organizationId, uid;
  final bool pending;
  final bool manager;
  LiveQuery<List<Membership>>? former;
  String view = 'Active', search = '';
  List<Membership> get visibleMembers {
    final source = view == 'Former Members' ? former?.value : records.value;
    final query = search.trim().toLowerCase();
    return (source ?? <Membership>[])
        .where(
          (m) =>
              (view != 'Officers' || m.role == 'officer') &&
              '${m.applicantName} ${m.uid} ${m.positionTitle ?? ''} ${m.role} ${m.status}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
  }

  void filter({String? view, String? text}) {
    if (view != null &&
        ['Active', 'Officers', if (manager) 'Former Members'].contains(view)) {
      this.view = view;
    }
    if (text != null) search = text;
    notifyListeners();
  }

  bool canManage(Membership m) =>
      manager &&
      !pending &&
      m.status == 'active' &&
      m.role != 'manager' &&
      m.uid != uid;
  Future<Map<String, dynamic>?> preview(Membership m) async {
    if (!manager || processing.contains(m.uid)) return null;
    processing.add(m.uid);
    failure = null;
    notifyListeners();
    try {
      return await repository.membershipCommand('preview', {
        'organizationId': organizationId,
        'participantUid': m.uid,
      });
    } catch (error) {
      if (!_disposed) failure = AppFailure.from(error);
      return null;
    } finally {
      if (!_disposed) {
        processing.remove(m.uid);
        notifyListeners();
      }
    }
  }

  Future<bool> manage(Membership m, Map<String, dynamic> command) async {
    if (!canManage(m) || processing.contains(m.uid)) return false;
    processing.add(m.uid);
    failure = null;
    notifyListeners();
    try {
      await repository.membershipCommand('mutate', {
        ...command,
        'organizationId': organizationId,
        'participantUid': m.uid,
      });
      return true;
    } catch (error) {
      if (!_disposed) failure = AppFailure.from(error);
      return false;
    } finally {
      if (!_disposed) {
        processing.remove(m.uid);
        notifyListeners();
      }
    }
  }

  static String requestId() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
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
    former?.dispose();
    super.dispose();
  }
}
