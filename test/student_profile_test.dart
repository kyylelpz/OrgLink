import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'support/test_auth_repository.dart';

void main() {
  test('student fields validate required and invalid input', () {
    expect(validDetails.isValid, isTrue);
    for (final value in ['', ' ', 'ab!', '12']) {
      expect(StudentDetails.validateStudentNumber(value), isNotNull);
    }
    expect(StudentDetails.validateName(' '), isNotNull);
    expect(StudentDetails.validateSection('#'), isNotNull);
    expect(StudentDetails.validateSection('CPE 3-A'), isNull);
    expect(
      StudentDetails(
        fullName: 'Student Name',
        studentNumber: '123',
        yearLevel: 7,
        section: 'A',
      ).isValid,
      isFalse,
    );
  });
  test('unknown and suspended statuses never grant eligibility', () {
    for (final status in ['pending', 'suspended', 'disabled', '', 'unknown']) {
      expect(profile(status: status).isEligible, isFalse);
    }
    expect(profile().isEligible, isTrue);
  });
}
