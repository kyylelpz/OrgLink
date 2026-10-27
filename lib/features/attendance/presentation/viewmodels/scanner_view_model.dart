import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';

class ScannerViewModel extends ChangeNotifier {
  ScannerViewModel(this.repository, this.allowed);
  final AttendanceRepository repository;
  final bool Function(String org) allowed;
  bool busy = false, _disposed = false, paused = false;
  AppFailure? failure;
  AttendanceResult? result;
  Future<void> scan(String raw) async {
    if (_disposed || busy || paused) return;
    paused = true;
    failure = null;
    result = null;
    QRPayload payload;
    try {
      payload = QRPayload.parse(raw);
    } catch (_) {
      failure = const AppFailure(
        'This is not a supported OrgLink attendance QR code.',
      );
      notifyListeners();
      return;
    }
    if (!allowed(payload.organizationId)) {
      failure = const AppFailure(
        'You are not authorized to verify attendance for this organization.',
      );
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final value = await repository.redeem(payload);
      if (!_disposed && allowed(payload.organizationId)) result = value;
    } catch (e) {
      if (!_disposed) failure = AppFailure.from(e);
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void next() {
    if (_disposed || busy) return;
    paused = false;
    result = null;
    failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
