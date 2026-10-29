/// Controlled persisted labels; extending options does not change field names.
abstract final class AcademicOptions {
  static const college = 'College of Engineering';
  static const colleges = [college];
  static const programs = [
    'Bachelor of Science in Civil Engineering',
    'Bachelor of Science in Computer Engineering',
    'Bachelor of Science in Electrical Engineering',
    'Bachelor of Science in Electronics Engineering',
    'Bachelor of Science in Industrial Engineering',
    'Bachelor of Science in Manufacturing Engineering',
    'Bachelor of Science in Mechanical Engineering',
    'Bachelor of Science in Mechatronics Engineering',
  ];
  static List<String> programsFor(String? value) =>
      value == college ? programs : const [];
  static String? validateCollege(String? value) =>
      colleges.contains(value) ? null : 'Select a college.';
  static String? validateProgram(String? collegeValue, String? value) =>
      programsFor(collegeValue).contains(value) ? null : 'Select a program.';
}

class StudentDetails {
  const StudentDetails({
    required this.fullName,
    required this.studentNumber,
    required this.yearLevel,
    required this.section,
    this.college,
    this.program,
  });
  final String fullName;
  final String studentNumber;
  final int yearLevel;
  final String section;
  // Null means not supplied by a caller; omit it from patches to retain data.
  final String? college, program;

  factory StudentDetails.fromMap(Map<String, dynamic> data) => StudentDetails(
    fullName: data['fullName'] as String? ?? '',
    studentNumber: data['studentNumber'] as String? ?? '',
    yearLevel: data['yearLevel'] as int? ?? 0,
    section: data['section'] as String? ?? '',
    college: data['college'] is String ? data['college'] as String : null,
    program: data['program'] is String ? data['program'] as String : null,
  );

  static String? validateAcademic(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim().length < 2 ||
            value.trim().length > 160 ||
            RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)
        ? 'Use 2–160 characters without control characters, or leave this blank.'
        : null;
  }

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
  bool get hasValidIdentity =>
      validateName(fullName) == null &&
      validateStudentNumber(studentNumber) == null &&
      yearLevel >= 1 &&
      yearLevel <= 6 &&
      validateSection(section) == null;
  bool get hasValidAcademicSelection =>
      AcademicOptions.validateCollege(college) == null &&
      AcademicOptions.validateProgram(college, program) == null;
  bool get isValid =>
      hasValidIdentity &&
      validateAcademic(college) == null &&
      validateAcademic(program) == null;
  Map<String, dynamic> toMap() => {
    'fullName': fullName.trim(),
    'studentNumber': studentNumber.trim(),
    'yearLevel': yearLevel,
    'section': section.trim(),
    if (college != null) 'college': college!.trim(),
    if (program != null) 'program': program!.trim(),
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
  bool get isComplete => email.isNotEmpty && details.hasValidIdentity;
  // Presentation hint only; privileged operations independently authorize in the Worker.
  bool get isPlatformAdmin => isEligible && platformRole == 'platformAdmin';
  bool get isEligible => isComplete && accountStatus == 'active';
}
