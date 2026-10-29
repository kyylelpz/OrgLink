import '../models/admin_models.dart';
import '../services/admin_service.dart';

abstract interface class AdminRepository {
  Future<AdminStats> stats();
  Future<AdminPage<AdminAccount>> accounts(
    String field,
    String search,
    Map<String, dynamic>? cursor,
  );
  Future<AdminPage<AdminOrganization>> organizations(
    String field,
    String search,
    Map<String, dynamic>? cursor,
  );
  Future<void> mutate(Map<String, dynamic> data);
}

class WorkerAdminRepository implements AdminRepository {
  WorkerAdminRepository(this.service);
  final AdminService service;
  @override
  Future<AdminStats> stats() async =>
      AdminStats.fromMap(await service.call('stats', {}));
  Future<AdminPage<T>> _page<T>(
    String collection,
    String field,
    String search,
    Map<String, dynamic>? cursor,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final result = await service.call('list', {
      'collection': collection,
      'field': field,
      'search': search,
      'cursor': ?cursor,
    });
    return AdminPage(
      (result['items'] as List)
          .map((m) => parse(Map<String, dynamic>.from(m as Map)))
          .toList(),
      result['nextCursor'] == null
          ? null
          : Map<String, dynamic>.from(result['nextCursor'] as Map),
    );
  }

  @override
  Future<AdminPage<AdminAccount>> accounts(
    String field,
    String search,
    Map<String, dynamic>? cursor,
  ) => _page('users', field, search, cursor, AdminAccount.fromMap);
  @override
  Future<AdminPage<AdminOrganization>> organizations(
    String field,
    String search,
    Map<String, dynamic>? cursor,
  ) => _page('organizations', field, search, cursor, AdminOrganization.fromMap);
  @override
  Future<void> mutate(Map<String, dynamic> data) async {
    await service.call('mutate', data);
  }
}
