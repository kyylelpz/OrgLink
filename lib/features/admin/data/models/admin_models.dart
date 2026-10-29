import 'dart:convert';
import 'dart:math';
import '../../../organizations/data/models/organization.dart';
import '../../../../core/services/worker_api_service.dart';

String adminRequestId() => base64UrlEncode(
  List.generate(18, (_) => Random.secure().nextInt(256)),
).replaceAll('=', '');

typedef AdminFailure = WorkerFailure;

class AdminStats {
  const AdminStats(this.users, this.pending, this.organizations);
  final int users, pending, organizations;
  factory AdminStats.fromMap(Map<String, dynamic> m) => AdminStats(
    (m['users'] as num).toInt(),
    (m['pending'] as num).toInt(),
    (m['organizations'] as num).toInt(),
  );
}

class AdminAccount {
  AdminAccount.fromMap(Map<String, dynamic> m)
    : uid = m['id'] as String,
      version = m['version'] as String,
      name = m['fullName'] as String? ?? '',
      studentId = m['studentNumber'] is String
          ? m['studentNumber'] as String
          : '',
      email = m['email'] as String? ?? '',
      role = m['platformRole'] as String? ?? '',
      status = m['accountStatus'] as String? ?? '',
      reactivationEligible = m['canReactivate'] == true;
  final bool reactivationEligible;
  bool get canReactivate =>
      status == 'disabled' && role == 'user' && reactivationEligible;
  final String uid, version, name, email, role, status, studentId;
}

class AdminOrganization {
  AdminOrganization.fromMap(Map<String, dynamic> m)
    : organization = Organization.fromMap(m['id'] as String, m),
      version = m['version'] as String,
      managerStudentId = m['managerStudentId'] as String?,
      managerName = m['managerName'] as String?;
  final String? managerStudentId, managerName;
  final Organization organization;
  final String version;
}

class AdminPage<T> {
  const AdminPage(this.items, this.nextCursor);
  final List<T> items;
  final Map<String, dynamic>? nextCursor;
}

class AdminManager {
  AdminManager.fromMap(Map<String, dynamic> m)
    : studentId = m['studentId'] as String,
      name = m['name'] as String,
      status = m['status'] as String,
      version = m['version'] as String,
      registryVersion = m['registryVersion'] as String,
      eligible = m['eligible'] == true;
  final String studentId, name, status, version, registryVersion;
  final bool eligible;
}
