import 'package:flutter/foundation.dart';
import '../../../../core/utils/live_query.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../organizations/data/models/organization.dart';
import '../../../organizations/data/repositories/organization_repository.dart';
import '../../../memberships/data/models/membership.dart';
import '../../data/models/event.dart';
import '../../data/models/event_registration.dart';
import '../../data/repositories/event_repository.dart';

class EventContextViewModel extends ChangeNotifier {
  EventContextViewModel(
    this.repository,
    OrganizationRepository organizations,
    this.organizationId,
    this.uid, {
    this.eventId,
  }) {
    organization = LiveQuery(
      () => organizations.watchOrganization(organizationId),
    );
    membership = LiveQuery(
      () => organizations.watchMembership(organizationId, uid),
    );
    organization.addListener(notifyListeners);
    membership.addListener(notifyListeners);
    if (eventId != null) {
      event = LiveQuery(() => repository.watchEvent(organizationId, eventId!));
      registration = LiveQuery(
        () => repository.watchRegistration(organizationId, eventId!, uid),
      );
      event!.addListener(notifyListeners);
      registration!.addListener(notifyListeners);
    }
  }
  final EventRepository repository;
  final String organizationId, uid;
  final String? eventId;
  late final LiveQuery<Organization?> organization;
  late final LiveQuery<Membership?> membership;
  LiveQuery<OrgEvent?>? event;
  LiveQuery<EventRegistration?>? registration;
  bool busy = false, _disposed = false;
  AppFailure? failure;
  bool get isManager => organization.value?.managerUid == uid;
  bool get isOfficer =>
      membership.value?.role == 'officer' &&
      membership.value?.status == 'active' &&
      membership.value?.permissions['manageEvents'] == true;
  bool get canCreate =>
      organization.value?.status == 'active' && (isManager || isOfficer);
  bool get canManageEvent =>
      canCreate && (isManager || event?.value?.createdBy == uid);
  bool get canEdit =>
      canManageEvent &&
      event?.value?.eventStatus == 'draft' &&
      event?.value?.archivedAt == null &&
      !(event?.value?.approvalStatus == 'pending' &&
          event?.value?.submittedAt != null);
  bool get canReview =>
      isManager &&
      organization.value?.status == 'active' &&
      event?.value?.eventStatus == 'draft' &&
      event?.value?.approvalStatus == 'pending' &&
      event?.value?.submittedAt != null;
  bool get canPublish =>
      isManager &&
      organization.value?.status == 'active' &&
      event?.value?.eventStatus == 'draft' &&
      event?.value?.approvalStatus == 'approved';
  bool get canViewParticipants => canManageEvent;
  bool get privateEligible => membership.value?.status == 'active';
  bool get canRegister =>
      !busy &&
      registration != null &&
      !registration!.loading &&
      registration!.failure == null &&
      registration!.value?.status != 'registered' &&
      event?.value?.registrationOpen(DateTime.now()) == true &&
      (event!.value!.visibility == 'public' || privateEligible);
  bool get canWithdraw {
    final value = event?.value, now = DateTime.now();
    return !busy &&
        registration?.value?.status == 'registered' &&
        ['published', 'cancelled'].contains(value?.eventStatus) &&
        value?.approvalStatus == 'approved' &&
        value?.registrationDeadline != null &&
        now.isBefore(value!.registrationDeadline!) &&
        value.startAt != null &&
        now.isBefore(value.startAt!);
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    if (busy || _disposed) return null;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      if (!_disposed) failure = AppFailure.from(error);
      return null;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<String?> save(EventDraft draft) => _run(() async {
    final error = draft.validate(DateTime.now());
    if (error != null) throw AppFailure(error);
    if (eventId == null) {
      if (!canCreate) {
        throw const AppFailure(
          'You cannot create events for this organization.',
        );
      }
      return repository.create(organizationId, uid, draft);
    }
    if (!canEdit) {
      throw const AppFailure(
        'This event cannot be edited in its current state.',
      );
    }
    await repository.edit(organizationId, eventId!, draft);
    return eventId!;
  });
  Future<bool> act(String action) async =>
      await _run(() async {
        await repository.transition(organizationId, eventId!, uid, action);
        return true;
      }) ??
      false;
  Future<bool> register({required bool withdraw}) async {
    if (!(withdraw ? canWithdraw : canRegister)) return false;
    return await _run(() async {
          await repository.register(
            organizationId,
            eventId!,
            uid,
            withdraw: withdraw,
          );
          return true;
        }) ??
        false;
  }

  @override
  void dispose() {
    _disposed = true;
    organization.dispose();
    membership.dispose();
    event?.dispose();
    registration?.dispose();
    super.dispose();
  }
}
