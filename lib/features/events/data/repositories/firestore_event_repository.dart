import '../models/participant_identity.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../services/event_service.dart';
import 'event_repository.dart';

class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository(this._service);
  final EventService _service;
  Stream<T> _stream<T>(Stream<T> source) async* {
    try {
      yield* source;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<T> _operation<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  void _validate(EventDraft draft) {
    final error = draft.validate(DateTime.now());
    if (error != null) throw AppFailure(error);
  }

  @override
  Stream<List<OrgEvent>> organizationEvents(
    String org, {
    required bool management,
    required bool includePrivate,
    String? createdBy,
  }) => _stream(
    _service.organizationEvents(
      org,
      management: management,
      includePrivate: includePrivate,
      createdBy: createdBy,
    ),
  );
  @override
  Stream<OrgEvent?> watchEvent(String org, String id) =>
      _stream(_service.watchEvent(org, id));
  @override
  Stream<EventRegistration?> watchRegistration(
    String org,
    String id,
    String uid,
  ) => _stream(_service.watchRegistration(org, id, uid));
  @override
  Stream<List<EventRegistration>> myRegistrations(String uid) =>
      _stream(_service.myRegistrations(uid));
  @override
  Stream<List<EventRegistration>> participants(String org, String id) =>
      _stream(_service.participants(org, id));
  @override
  Stream<List<ParticipantIdentity>> participantIdentities(
    String org,
    String id,
  ) => _stream(_service.participantIdentities(org, id));
  @override
  Future<void> refreshParticipantIdentity(String org, String id, String uid) =>
      _operation(() => _service.refreshParticipantIdentity(org, id, uid));
  @override
  Future<String> create(String org, String uid, EventDraft draft) {
    _validate(draft);
    return _operation(() => _service.create(org, uid, draft));
  }

  @override
  Future<void> edit(String org, String id, EventDraft draft) {
    _validate(draft);
    return _operation(() => _service.edit(org, id, draft));
  }

  @override
  Future<void> transition(String org, String id, String uid, String action) =>
      _operation(() => _service.transition(org, id, uid, action));
  @override
  Future<void> register(
    String org,
    String id,
    String uid, {
    required bool withdraw,
  }) => _operation(() => _service.register(org, id, uid, withdraw: withdraw));
}
