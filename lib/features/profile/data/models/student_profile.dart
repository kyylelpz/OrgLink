class StudentDetails {
  const StudentDetails({
    required this.fullName,
    required this.studentNumber,
    required this.yearLevel,
    required this.section,
  });
  final String fullName;
  final String studentNumber;
  final int yearLevel;
  final String section;

  static String? validateName(String? value) =>
      value == null || value.trim().length < 2 || value.trim().length > 100
      ? 'Enter a full name (2?100 characters).'
      : null;
  static String? validateStudentNumber(String? value) =>
      value == null ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{2,29}$').hasMatch(value.trim())
      ? 'Use 3?30 letters, digits or hyphens.'
      : null;
  static String? validateSection(String? value) =>
      value == null ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]{0,29}$').hasMatch(value.trim())
      ? 'Use 1?30 letters, digits, spaces or hyphens.'
      : null;
  bool get isValid =>
      validateName(fullName) == null &&
      validateStudentNumber(studentNumber) == null &&
      yearLevel >= 1 &&
      yearLevel <= 6 &&
      validateSection(section) == null;
  Map<String, dynamic> toMap() => {
    'fullName': fullName.trim(),
    'studentNumber': studentNumber.trim(),
    'yearLevel': yearLevel,
    'section': section.trim(),
  };
}

class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.email,
    required this.details,
    required this.platformRole,
    required this.accountStatus,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
  });
  final String uid;
  final String email;
  final StudentDetails details;
  final String? photoURL;
  final String platformRole;
  final String accountStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  bool get isComplete => email.isNotEmpty && details.isValid;
  // Role data never grants administrative access in this module.
  bool get isEligible => isComplete && accountStatus == 'active';
}
