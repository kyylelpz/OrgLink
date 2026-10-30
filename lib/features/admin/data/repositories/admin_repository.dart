import '../models/admin_models.dart';
import '../services/admin_service.dart';

abstract interface class AdminRepository {
  Future<AdminStats> stats();
  Future<AdminManager> manager(String studentId);
  Future<AdminPage<AdminAccount>> accounts(
    String field,
    String search,
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  });
  Future<AdminPage<AdminOrganization>> organizations(
    String field,
    String search,
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  });
  Future<void> mutate(Map<String, dynamic> data);
}

class WorkerAdminRepository implements AdminRepository {
  WorkerAdminRepository(this.service);
  final AdminService service;
  @override
  Future<AdminManager> manager(String studentId) async => AdminManager.fromMap(
    await service.call('manager', {'studentId': studentId}),
  );
  @override
  Future<AdminStats> stats() async =>
      AdminStats.fromMap(await service.call('stats', {}));
  Future<AdminPage<T>> _page<T>(
    String collection,
    String field,
    String search,
    Map<String, dynamic>? cursor,
    T Function(Map<String, dynamic>) parse, {
    bool refresh = false,
  }) async {
    final result = await service.call('list', {
      'collection': collection,
      'field': field,
      'search': search,
      'cursor': ?cursor,
      if (refresh) 'refresh': true,
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
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  }) => _page(
    'users',
    field,
    search,
    cursor,
    AdminAccount.fromMap,
    refresh: refresh,
  );
  @override
  Future<AdminPage<AdminOrganization>> organizations(
    String field,
    String search,
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  }) => _page(
    'organizations',
    field,
    search,
    cursor,
    AdminOrganization.fromMap,
    refresh: refresh,
  );
  @override
  Future<void> mutate(Map<String, dynamic> data) async {
    await service.call('mutate', data);
  }
}
