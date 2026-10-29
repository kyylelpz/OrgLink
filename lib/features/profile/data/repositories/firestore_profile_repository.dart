import '../../../../core/errors/app_failure.dart';
import '../../../auth/data/models/auth_user.dart';
import '../models/student_profile.dart';
import '../services/user_profile_service.dart';
import 'profile_repository.dart';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._service);
  final UserProfileService _service;
  @override
  Stream<StudentProfile?> watch(String uid) async* {
    try {
      yield* _service.watch(uid);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> save(AuthUser user, StudentDetails details) async {
    if (!details.isValid ||
        !details.hasValidAcademicSelection ||
        user.requiresEmailVerification ||
        user.email == null ||
        user.email!.isEmpty) {
      throw const AppFailure(
        'Complete all student details with valid information.',
      );
    }
    try {
      await _service.save(user, details);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}
