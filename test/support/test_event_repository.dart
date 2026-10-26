import 'package:orglink/features/events/data/models/participant_identity.dart';
import 'dart:async';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/events/data/models/event.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'test_organization_repository.dart';

OrgEvent sampleEvent({
  String status = 'published',
  String approval = 'approved',
  String visibility = 'public',
  String creator = 'manager',
}) => OrgEvent(
  id: 'demo',
  organizationId: 'robotics',
  title: 'Demo Event',
  description: 'Synthetic event',
  venue: 'Demo Hall',
  capacity: 2,
  registrationCount: 0,
  eventStatus: status,
  approvalStatus: approval,
  createdBy: creator,
  visibility: visibility,
  startAt: DateTime.now().add(const Duration(days: 2)),
  endAt: DateTime.now().add(const Duration(days: 2, hours: 2)),
  registrationDeadline: DateTime.now().add(const Duration(days: 1)),
);
EventDraft sampleDraft() => sampleEvent().draft!;

class TestEventRepository implements EventRepository {
  final event = TestFeed<OrgEvent?>(sampleEvent());
  final registrations = TestFeed<List<EventRegistration>>([]);
  final identities = TestFeed<List<ParticipantIdentity>>([]);
  String profileName = 'Student Name';
  int identityWatches = 0, identityRefreshes = 0;
  int creates = 0, edits = 0, registrationsMade = 0;
  final actions = <String>[];
  Object? failure;
  Completer<void>? operationGate;
  void change(Map<String, dynamic> changes) => event.emit(
    OrgEvent.fromMap('demo', 'robotics', {...event.value!.toMap(), ...changes}),
  );
  @override
  Stream<List<OrgEvent>> organizationEvents(
    String org, {
    required bool management,
    required bool includePrivate,
    String? createdBy,
  }) => event.watch().map(
    (value) =>
        value == null ||
            org != 'robotics' ||
            (createdBy != null && createdBy != value.createdBy) ||
            (!management &&
                (!['published', 'completed'].contains(value.eventStatus) ||
                    value.approvalStatus != 'approved' ||
                    (!includePrivate && value.visibility != 'public')))
        ? []
        : [value],
  );
  @override
  Stream<OrgEvent?> watchEvent(String org, String id) => event.watch();
  @override
  Stream<EventRegistration?> watchRegistration(
    String org,
    String id,
    String uid,
  ) => registrations.watch().map((values) {
    for (final record in values) {
      if (record.uid == uid) return record;
    }
    return null;
  });
  @override
  Stream<List<EventRegistration>> myRegistrations(String uid) => registrations
      .watch()
      .map((values) => values.where((record) => record.uid == uid).toList());
  @override
  Stream<List<EventRegistration>> participants(String org, String id) =>
      registrations.watch();
  @override
  Stream<List<ParticipantIdentity>> participantIdentities(
    String org,
    String id,
  ) {
    identityWatches++;
    return identities.watch();
  }

  void _captureName(String uid) {
    identities.emit([
      for (final identity in identities.value)
        if (identity.uid != uid) identity,
      ParticipantIdentity(
        uid: uid,
        fullName: profileName,
        updatedAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<void> refreshParticipantIdentity(
    String org,
    String id,
    String uid,
  ) async {
    identityRefreshes++;
    await operation();
    if (!registrations.value.any((record) => record.uid == uid)) {
      throw const AppFailure('No registration');
    }
    _captureName(uid);
  }

  Future<void> operation() async {
    await operationGate?.future;
    if (failure case final error?) throw error;
  }

  @override
  Future<String> create(String org, String uid, EventDraft draft) async {
    creates++;
    await operation();
    event.emit(
      OrgEvent.fromMap('demo', org, {
        ...draft.toMap(),
        'eventStatus': 'draft',
        'approvalStatus': 'pending',
        'registrationCount': 0,
        'createdBy': uid,
        'eventId': 'demo',
        'organizationId': org,
      }),
    );
    return 'demo';
  }

  @override
  Future<void> edit(String org, String id, EventDraft draft) async {
    edits++;
    await operation();
    change({
      ...draft.toMap(),
      'approvalStatus': 'pending',
      'submittedAt': null,
    });
  }

  @override
  Future<void> transition(
    String org,
    String id,
    String uid,
    String action,
  ) async {
    await operation();
    actions.add(action);
    switch (action) {
      case 'submit':
        change({'approvalStatus': 'pending', 'submittedAt': DateTime.now()});
      case 'approve':
        change({
          'approvalStatus': 'approved',
          'reviewedBy': uid,
          'reviewedAt': DateTime.now(),
        });
      case 'reject':
        change({
          'approvalStatus': 'rejected',
          'reviewedBy': uid,
          'reviewedAt': DateTime.now(),
        });
      case 'publish':
        change({'eventStatus': 'published', 'publishedAt': DateTime.now()});
      case 'cancel':
        change({'eventStatus': 'cancelled', 'cancelledAt': DateTime.now()});
    }
  }

  @override
  Future<void> register(
    String org,
    String id,
    String uid, {
    required bool withdraw,
  }) async {
    registrationsMade++;
    await operation();
    EventRegistration? previous;
    for (final record in registrations.value) {
      if (record.uid == uid) previous = record;
    }
    if (!withdraw &&
        (previous?.status == 'registered' ||
            event.value!.availableSlots == 0)) {
      throw const AppFailure('Duplicate or full');
    }
    final updated = EventRegistration(
      uid: uid,
      eventId: id,
      organizationId: org,
      status: withdraw ? 'cancelled' : 'registered',
      registeredAt: previous?.registeredAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (!withdraw) _captureName(uid);
    registrations.emit([
      for (final record in registrations.value)
        if (record.uid != uid) record,
      updated,
    ]);
    change({
      'registrationCount': event.value!.registrationCount + (withdraw ? -1 : 1),
    });
  }

  Future<void> close() async {
    await event.close();
    await registrations.close();
    await identities.close();
  }
}
