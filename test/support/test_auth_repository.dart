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
