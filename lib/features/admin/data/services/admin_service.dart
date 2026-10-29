import '../../../../core/services/worker_api_service.dart';

class AdminService extends WorkerApiService {
  AdminService(super.auth, {super.client, super.apiUrl});
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> data,
  ) => super.call('/admin/$operation', data);
}
