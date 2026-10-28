import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'package:orglink/features/profile/data/services/user_profile_service.dart';
import 'package:orglink/features/profile/data/repositories/firestore_profile_repository.dart';
import 'support/test_auth_repository.dart';

class RecordingProfileService extends Fake implements UserProfileService {
  StudentDetails? saved;
  @override
  Future<void> save(AuthUser user, StudentDetails details) async {
    saved = details;
  }
}

void main() {
  test(
    'repository forwards academic values without normalizing spelling',
    () async {
      final service = RecordingProfileService();
      final repo = FirestoreProfileRepository(service);
      final details = StudentDetails.fromMap({
        ...validDetails.toMap(),
        'college': 'College of Engineering',
        'program': 'IEEE / iOS Research',
      });
      await repo.save(student, details);
      expect(service.saved!.toMap()['program'], 'IEEE / iOS Research');
      await repo.save(student, validDetails);
      expect(service.saved!.toMap().containsKey('college'), isFalse);
      await expectLater(
        repo.save(
          student,
          StudentDetails.fromMap({...validDetails.toMap(), 'college': 'x'}),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
