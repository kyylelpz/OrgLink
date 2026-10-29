import 'dart:convert';
import 'dart:math';
import '../../../organizations/data/models/organization.dart';
import '../../../../core/errors/app_failure.dart';

String adminRequestId() => base64UrlEncode(
  List.generate(18, (_) => Random.secure().nextInt(256)),
).replaceAll('=', '');

class AdminFailure extends AppFailure {
  const AdminFailure(super.message, this.code);
  final String code;
}

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
      email = m['email'] as String? ?? '',
      role = m['platformRole'] as String? ?? '',
      status = m['accountStatus'] as String? ?? '',
      reactivationEligible = m['canReactivate'] == true;
  final bool reactivationEligible;
  bool get canReactivate =>
      status == 'disabled' && role == 'user' && reactivationEligible;
  final String uid, version, name, email, role, status;
}

class AdminOrganization {
  AdminOrganization.fromMap(Map<String, dynamic> m)
    : organization = Organization.fromMap(m['id'] as String, m),
      version = m['version'] as String;
  final Organization organization;
  final String version;
}

class AdminPage<T> {
  const AdminPage(this.items, this.nextCursor);
  final List<T> items;
  final Map<String, dynamic>? nextCursor;
}
