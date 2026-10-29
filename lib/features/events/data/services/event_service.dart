import '../models/participant_identity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/event.dart';
import '../models/event_registration.dart';

class EventService {
  EventService(this._store);
  final FirestoreService _store;
  CollectionReference<Map<String, dynamic>> _collection(String path) =>
      _store.collection<Map<String, dynamic>>(
        path,
        fromFirestore: (doc, _) => doc.data()!,
        toFirestore: (data, _) => data,
      );
  CollectionReference<Map<String, dynamic>> _events(String org) =>
      _collection('organizations/$org/events');
  DocumentReference<Map<String, dynamic>> _event(String org, String id) =>
      _events(org).doc(id);
  DocumentReference<Map<String, dynamic>> _registration(
    String org,
    String id,
    String uid,
  ) => _collection('organizations/$org/events/$id/registrations').doc(uid);
  Stream<List<OrgEvent>> organizationEvents(
    String org, {
    required bool management,
    required bool includePrivate,
    String? createdBy,
  }) {
    Query<Map<String, dynamic>> query = _events(org);
    if (management) {
      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }
    } else {
      query = query
          .where('eventStatus', whereIn: ['published', 'completed'])
          .where('approvalStatus', isEqualTo: 'approved');
      if (!includePrivate) {
        query = query.where('visibility', isEqualTo: 'public');
      }
    }
    return query
        .orderBy('startAt')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.isFromCache)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrgEvent.fromMap(doc.id, org, doc.data()))
              .toList(),
        );
  }

  Stream<OrgEvent?> watchEvent(String org, String id) => _event(org, id)
      .snapshots(includeMetadataChanges: true)
      .where(
        (doc) => !doc.metadata.isFromCache && !doc.metadata.hasPendingWrites,
      )
      .map(
        (doc) => doc.data() == null
            ? null
            : OrgEvent.fromMap(doc.id, org, doc.data()!),
      );
  Stream<EventRegistration?> watchRegistration(
    String org,
    String id,
    String uid,
  ) => _registration(org, id, uid)
      .snapshots(includeMetadataChanges: true)
      .where(
        (doc) => !doc.metadata.isFromCache && !doc.metadata.hasPendingWrites,
      )
      .map(
        (doc) =>
            doc.data() == null ? null : EventRegistration.fromMap(doc.data()!),
      );
  Stream<List<EventRegistration>> _registrations(
    Query<Map<String, dynamic>> query,
  ) => query
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => EventRegistration.fromMap(doc.data()))
            .toList(),
      );
  Stream<List<EventRegistration>> myRegistrations(String uid) => _registrations(
    _store
        .collectionGroup<Map<String, dynamic>>(
          'registrations',
          fromFirestore: (doc, _) => doc.data()!,
          toFirestore: (data, _) => data,
        )
        .where('uid', isEqualTo: uid),
  );
  Stream<List<EventRegistration>> participants(String org, String id) =>
      _registrations(
        _collection('organizations/$org/events/$id/registrations'),
      );
  DocumentReference<Map<String, dynamic>> _identity(
    String org,
    String id,
    String uid,
  ) => _collection(
    'organizations/$org/events/$id/participantIdentities',
  ).doc(uid);
  Stream<List<ParticipantIdentity>> participantIdentities(
    String org,
    String id,
  ) => _collection('organizations/$org/events/$id/participantIdentities')
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ParticipantIdentity.fromMap(doc.id, doc.data()))
            .toList(),
      );
  Map<String, dynamic> _identityData(
    String uid,
    Map<String, dynamic>? profile,
  ) {
    final fullName = profile?['fullName'];
    if (fullName is! String || fullName.trim().isEmpty) {
      throw const AppFailure(
        'Complete your profile full name before sharing it with event organizers.',
      );
    }
    return {
      'uid': uid,
      'fullName': fullName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> refreshParticipantIdentity(String org, String id, String uid) =>
      _store.runTransaction((transaction) async {
        final profile = await transaction.get(_collection('users').doc(uid));
        final registration = await transaction.get(_registration(org, id, uid));
        if (!registration.exists) {
          throw const AppFailure('An existing event registration is required.');
        }
        transaction.set(
          _identity(org, id, uid),
          _identityData(uid, profile.data()),
        );
      });
  Future<String> create(String org, String uid, EventDraft draft) async {
    final reference = _events(org).doc();
    await reference.set({
      ...draft.toMap(),
      'posterURL': null,
      'eventId': reference.id,
      'organizationId': org,
      'createdBy': uid,
      'eventStatus': 'draft',
      'approvalStatus': 'pending',
      'registrationCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'submittedAt': null,
      'reviewedAt': null,
      'reviewedBy': null,
      'publishedAt': null,
      'cancelledAt': null,
      'completedAt': null,
      'archivedAt': null,
    });
    return reference.id;
  }

  Future<void> edit(String org, String id, EventDraft draft) =>
      _event(org, id).update({
        ...(draft.toMap()..remove('posterURL')),
        'approvalStatus': 'pending',
        'submittedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  Future<void> transition(String org, String id, String uid, String action) =>
      _store.runTransaction((transaction) async {
        final reference = _event(org, id);
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) throw const AppFailure('Event no longer exists.');
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        switch (action) {
          case 'submit':
            updates.addAll({
              'approvalStatus': 'pending',
              'submittedAt': FieldValue.serverTimestamp(),
            });
          case 'approve':
          case 'reject':
            updates.addAll({
              'approvalStatus': action == 'approve' ? 'approved' : 'rejected',
              'reviewedAt': FieldValue.serverTimestamp(),
              'reviewedBy': uid,
            });
          case 'publish':
            updates.addAll({
              'eventStatus': 'published',
              'publishedAt': FieldValue.serverTimestamp(),
            });
          case 'cancel':
            updates.addAll({
              'eventStatus': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });
          case 'complete':
            updates.addAll({
              'eventStatus': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
            });
          case 'archive':
            updates['archivedAt'] = FieldValue.serverTimestamp();
          default:
            throw const AppFailure('Unsupported event action.');
        }
        transaction.update(reference, updates);
      });
  Future<void> register(
    String org,
    String id,
    String uid, {
    required bool withdraw,
  }) {
    if (withdraw) {
      // No private event read is needed to release an owned reservation. Rules
      // enforce the cutoff and pair this decrement with the status transition.
      return _store
          .commitBatch((batch) {
            batch.update(_registration(org, id, uid), {
              'registrationStatus': 'cancelled',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            batch.update(_event(org, id), {
              'registrationCount': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const AppFailure(
              'Withdrawal could not be confirmed. Reconnect to check its final status.',
            ),
          );
    }
    return _store.runTransaction((transaction) async {
      final eventRef = _event(org, id);
      final registrationRef = _registration(org, id, uid);
      final eventDoc = await transaction.get(eventRef);
      final record = await transaction.get(registrationRef);
      final profile = await transaction.get(_collection('users').doc(uid));
      if (!eventDoc.exists) throw const AppFailure('Event no longer exists.');
      final event = OrgEvent.fromMap(id, org, eventDoc.data()!);
      if (!event.registrationOpen(DateTime.now())) {
        throw const AppFailure('Registration is closed or the event is full.');
      }
      final old = record.data();
      if (old?['registrationStatus'] == 'registered') {
        throw const AppFailure('You are already registered.');
      }
      if (old == null) {
        transaction.set(registrationRef, {
          'uid': uid,
          'eventId': id,
          'organizationId': org,
          'registrationStatus': 'registered',
          'registeredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(registrationRef, {
          'registrationStatus': 'registered',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(
        _identity(org, id, uid),
        _identityData(uid, profile.data()),
      );
      transaction.update(eventRef, {
        'registrationCount': event.registrationCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
