import '../../../../core/services/worker_api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../auth/data/models/auth_user.dart';
import '../models/student_profile.dart';

class UserProfileService {
  UserProfileService(this._service, {required this.api});
  final WorkerApiService api;
  final FirestoreService _service;
  DocumentReference<Map<String, dynamic>> _document(String uid) => _service
      .collection<Map<String, dynamic>>(
        'users',
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (data, _) => data,
      )
      .doc(uid);

  Stream<StudentProfile?> watch(String uid) => _document(uid)
      .snapshots(includeMetadataChanges: true)
      // Cached/optimistic status must not grant eligibility.
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        if (data['uid'] != uid) {
          throw const FormatException('Profile identity mismatch');
        }
        return StudentProfile(
          uid: uid,
          email: data['email'] as String? ?? '',
          details: StudentDetails.fromMap(data),
          photoURL: data['photoURL'] as String?,
          platformRole: data['platformRole'] as String? ?? '',
          accountStatus: data['accountStatus'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      });

  Future<void> save(AuthUser user, StudentDetails details) async {
    if (api.auth.currentUser?.uid != user.id) {
      throw const WorkerFailure(
        'Your session changed. Reopen your profile.',
        'unauthenticated',
      );
    }
    await api.call('/profile/save', {'details': details.toMap()});
  }
}
