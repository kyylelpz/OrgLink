import 'package:cloud_firestore/cloud_firestore.dart';

/// Supplies typed references without imposing a collection or document schema.
class FirestoreService {
  FirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<T> runTransaction<T>(TransactionHandler<T> handler) =>
      _firestore.runTransaction(handler);

  CollectionReference<T> collection<T extends Object>(
    String path, {
    required FromFirestore<T> fromFirestore,
    required ToFirestore<T> toFirestore,
  }) => _firestore
      .collection(path)
      .withConverter<T>(fromFirestore: fromFirestore, toFirestore: toFirestore);
  Query<T> collectionGroup<T extends Object>(
    String name, {
    required FromFirestore<T> fromFirestore,
    required ToFirestore<T> toFirestore,
  }) => _firestore
      .collectionGroup(name)
      .withConverter<T>(fromFirestore: fromFirestore, toFirestore: toFirestore);
}
