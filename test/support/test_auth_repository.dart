import 'dart:async';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/data/repositories/auth_repository.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'package:orglink/features/profile/data/repositories/profile_repository.dart';

const student = AuthUser(
  id: 'student',
  email: 'student@example.edu',
  displayName: 'Student Name',
);
const validDetails = StudentDetails(
  fullName: 'Student Name',
  studentNumber: '2026-001',
  yearLevel: 1,
  section: 'A',
  college: AcademicOptions.college,
  program: 'Bachelor of Science in Computer Engineering',
);
StudentProfile profile({
  String status = 'active',
  StudentDetails details = validDetails,
}) => StudentProfile(
  uid: 'student',
  email: 'student@example.edu',
  details: details,
  platformRole: 'user',
  accountStatus: status,
);

class TestAuthRepository implements AuthRepository {
  final controller = StreamController<AuthUser?>.broadcast();
  Object? signOutError;
  Object? signInError;
  bool cancelSignIn = false;
  Completer<void>? signInGate;
  int signInCalls = 0;
  @override
  Stream<AuthUser?> authStateChanges() => controller.stream;
  @override
  Future<bool> signInWithGoogle() async {
    signInCalls++;
    await signInGate?.future;
    if (signInError case final error?) throw error;
    if (cancelSignIn) return false;
    controller.add(student);
    return true;
  }

  AuthUser? emailUser;
  int emailSignIns = 0,
      emailRegistrations = 0,
      verifications = 0,
      resets = 0,
      links = 0;
  @override
  Future<void> signInWithEmail(String email, String password) async {
    emailSignIns++;
    await signInGate?.future;
    if (signInError case final error?) throw error;
    controller.add(
      emailUser ??
          AuthUser(
            id: 'email-student',
            email: email,
            emailVerified: false,
            providers: const ['password'],
          ),
    );
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    emailRegistrations++;
    await signInWithEmail(email, password);
  }

  @override
  Future<void> sendVerification() async {
    verifications++;
    if (signInError case final error?) throw error;
  }

  @override
  Future<AuthUser?> reloadUser() async => emailUser;
  @override
  Future<void> resetPassword(String email) async {
    resets++;
    if (signInError case final error?) throw error;
  }

  @override
  Future<void> linkPassword(String password) async {
    links++;
    if (signInError case final error?) throw error;
  }

  int resetChecks = 0, passwordChanges = 0, emailApplies = 0;
  @override
  Future<void> verifyResetCode(String code) async {
    resetChecks++;
    if (signInError case final error?) throw error;
  }

  @override
  Future<void> confirmPasswordReset(String code, String password) async {
    passwordChanges++;
    if (signInError case final error?) throw error;
  }

  @override
  Future<void> applyEmailVerification(String code) async {
    emailApplies++;
    if (signInError case final error?) throw error;
  }

  @override
  Future<void> signOut() async {
    if (signOutError case final error?) throw error;
    controller.add(null);
  }
}

class TestProfileRepository implements ProfileRepository {
  final controller = StreamController<StudentProfile?>.broadcast();
  int watchCalls = 0;
  int saveCalls = 0;
  Completer<void>? saveGate;
  Object? saveError;
  StudentDetails? savedDetails;
  @override
  Stream<StudentProfile?> watch(String uid) {
    watchCalls++;
    return controller.stream;
  }

  @override
  Future<void> save(AuthUser user, StudentDetails details) async {
    saveCalls++;
    savedDetails = details;
    await saveGate?.future;
    if (saveError case final error?) throw error;
    controller.add(profile(details: details));
  }
}
