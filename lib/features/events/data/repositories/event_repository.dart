import '../models/participant_identity.dart';
import '../models/event.dart';
import '../models/event_registration.dart';

abstract interface class EventRepository {
  Stream<List<OrgEvent>> organizationEvents(
    String organizationId, {
    required bool management,
    required bool includePrivate,
    String? createdBy,
  });
  Stream<OrgEvent?> watchEvent(String organizationId, String eventId);
  Stream<EventRegistration?> watchRegistration(
    String organizationId,
    String eventId,
    String uid,
  );
  Stream<List<EventRegistration>> myRegistrations(String uid);
  Stream<List<EventRegistration>> participants(
    String organizationId,
    String eventId,
  );
  Stream<List<ParticipantIdentity>> participantIdentities(
    String organizationId,
    String eventId,
  );
  Future<void> refreshParticipantIdentity(
    String organizationId,
    String eventId,
    String uid,
  );
  Future<String> create(String organizationId, String uid, EventDraft draft);
  Future<void> edit(String organizationId, String eventId, EventDraft draft);
  Future<void> transition(
    String organizationId,
    String eventId,
    String uid,
    String action,
  );
  Future<void> register(
    String organizationId,
    String eventId,
    String uid, {
    required bool withdraw,
  });
}
