import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../organizations/data/repositories/organization_repository.dart';
import '../../organizations/presentation/viewmodels/organization_hub_view_model.dart';
import '../data/repositories/event_repository.dart';
import 'viewmodels/event_context_view_model.dart';
import 'viewmodels/event_hub_view_model.dart';

class EventHubScope extends StatelessWidget {
  const EventHubScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => EventHubViewModel(
      context.read<EventRepository>(),
      context.read<OrganizationHubViewModel>(),
    ),
    child: child,
  );
}

class EventContextScope extends StatelessWidget {
  const EventContextScope({
    super.key,
    required this.organizationId,
    this.eventId,
    required this.child,
  });
  final String organizationId;
  final String? eventId;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthViewModel, String?>((auth) => auth.user?.id);
    if (uid == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey('$uid/$organizationId/$eventId'),
      create: (context) => EventContextViewModel(
        context.read<EventRepository>(),
        context.read<OrganizationRepository>(),
        organizationId,
        uid,
        eventId: eventId,
      ),
      child: child,
    );
  }
}
