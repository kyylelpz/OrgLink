import 'package:flutter/foundation.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/worker_api_service.dart';
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
  bool selectingPoster = false;
  AppFailure? failure;
  Uint8List? selectedPoster;
  String? createdDraftId, posterMessage, _pendingPosterUpload;
  double? posterProgress;
  ImageUploadService? _posterService;
  bool get creationSaved => eventId == null && createdDraftId != null;
  bool get formLocked => busy || creationSaved;

  Future<void> selectPoster(
    ImageUploadService service, {
    Future<Uint8List?> Function(Uint8List bytes)? prepare,
  }) async {
    if (eventId != null || busy || !canCreate) return;
    selectingPoster = true;
    try {
      await _run(() async {
        var bytes = await service.select();
        if (bytes == null || _disposed) return;
        ImageUploadService.validateBytes(bytes);
        if (prepare != null) bytes = await prepare(bytes);
        if (bytes == null || _disposed) return;
        ImageUploadService.validateBytes(bytes);
        selectedPoster = bytes;
        _posterService = service;
        _pendingPosterUpload = null;
        posterMessage = null;
        posterProgress = null;
      });
    } finally {
      selectingPoster = false;
      if (!_disposed) notifyListeners();
    }
  }

  void removeSelectedPoster() {
    if (busy) return;
    selectedPoster = null;
    _pendingPosterUpload = null;
    posterMessage = null;
    posterProgress = null;
    failure = null;
    notifyListeners();
  }

  Future<String> _finishCreation() async {
    final id = createdDraftId;
    if (id == null || id.isEmpty || id.contains('/')) {
      throw const AppFailure(
        'A saved draft is required before uploading a poster.',
      );
    }
    final bytes = selectedPoster;
    if (bytes != null) {
      if (!canCreate || _posterService == null) {
        throw const AppFailure('You cannot upload a poster for this draft.');
      }
      void progress(String message, double? value) {
        posterMessage = message;
        posterProgress = value;
        if (!_disposed) notifyListeners();
      }

      try {
        _pendingPosterUpload ??= await _posterService!.upload(
          ImageResource('event', organizationId: organizationId, eventId: id),
          bytes,
          onProgress: progress,
        );
        if (_disposed) return id;
        progress('Verifying poster', null);
        await _posterService!.finalize(_pendingPosterUpload!);
      } on WorkerFailure catch (error) {
        // Expired/stale tickets need a fresh upload; ambiguous verification can retry its ticket.
        if ([
          'failed-precondition',
          'conflict',
          'not-found',
        ].contains(error.code)) {
          _pendingPosterUpload = null;
        }
        rethrow;
      }
      selectedPoster = null;
      _pendingPosterUpload = null;
      posterMessage = null;
      posterProgress = null;
    }
    return id;
  }

  Future<String?> retryPoster() => _run(_finishCreation);
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
    if (creationSaved) return _finishCreation();
    final error = draft.validate(DateTime.now());
    if (error != null) throw AppFailure(error);
    if (eventId == null) {
      if (!canCreate) {
        throw const AppFailure(
          'You cannot create events for this organization.',
        );
      }
      createdDraftId = await repository.create(organizationId, uid, draft);
      if (_disposed) return createdDraftId!;
      return _finishCreation();
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
