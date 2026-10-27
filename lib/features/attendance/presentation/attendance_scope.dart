import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../events/presentation/viewmodels/event_context_view_model.dart';
import '../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../data/repositories/attendance_repository.dart';
import 'viewmodels/attendance_view_model.dart';
import 'viewmodels/my_attendance_view_model.dart';

class AttendanceScope extends StatelessWidget {
  const AttendanceScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    key: ValueKey('${context.watch<AuthViewModel>().user?.id}/attendance'),
    create: (context) => AttendanceViewModel(
      context.read<AttendanceRepository>(),
      context.read<EventContextViewModel>(),
    ),
    child: child,
  );
}

class MyAttendanceScope extends StatelessWidget {
  const MyAttendanceScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    key: ValueKey('${context.watch<AuthViewModel>().user?.id}/mine'),
    create: (context) => MyAttendanceViewModel(
      context.read<AttendanceRepository>(),
      context.read<EventHubViewModel>(),
    ),
    child: child,
  );
}
