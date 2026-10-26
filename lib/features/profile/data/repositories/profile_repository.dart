import '../../../auth/data/models/auth_user.dart';
import '../models/student_profile.dart';

abstract interface class ProfileRepository {
  Stream<StudentProfile?> watch(String uid);
  Future<void> save(AuthUser user, StudentDetails details);
}
