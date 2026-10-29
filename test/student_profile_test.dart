import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'support/test_auth_repository.dart';

void main() {
  test(
    'legacy documents remain complete and omitted academic fields preserve patches',
    () {
      final legacy = StudentDetails.fromMap(
        {...validDetails.toMap()}
          ..remove('college')
          ..remove('program'),
      );
      expect(legacy.college, isNull);
      expect(legacy.program, isNull);
      expect(profile(details: legacy).isEligible, isTrue);
      final stored = {
        ...legacy.toMap(),
        'college': 'College of Engineering',
        'program': 'iOS Research',
        'custom': 'keep',
      };
      final updated = {...stored, ...legacy.toMap()};
      expect(updated['college'], 'College of Engineering');
      expect(updated['program'], 'iOS Research');
      expect(updated['custom'], 'keep');
      final details = StudentDetails.fromMap(stored);
      expect(details.toMap()['program'], 'iOS Research');
      expect(details.isValid, isTrue);
      expect(StudentDetails.validateAcademic('x'), isNotNull);
      expect(StudentDetails.validateAcademic('a' * 161), isNotNull);
      expect(StudentDetails.validateAcademic('College\nName'), isNotNull);
      expect(StudentDetails.validateAcademic(''), isNull);
      expect(StudentDetails.validateAcademic(null), isNull);
    },
  );
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
