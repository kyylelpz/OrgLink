import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../data/repositories/organization_repository.dart';
import 'viewmodels/organization_hub_view_model.dart';
import 'viewmodels/organization_details_view_model.dart';

class OrganizationScope extends StatelessWidget {
  const OrganizationScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthViewModel>().user?.id;
    if (uid == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey(uid),
      create: (context) =>
          OrganizationHubViewModel(context.read<OrganizationRepository>(), uid),
      child: child,
    );
  }
}

class OrganizationDetailsScope extends StatelessWidget {
  const OrganizationDetailsScope({
    super.key,
    required this.id,
    required this.child,
  });
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthViewModel>().user?.id;
    if (uid == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey('$uid/$id'),
      create: (context) => OrganizationDetailsViewModel(
        context.read<OrganizationRepository>(),
        id,
        uid,
      ),
      child: child,
    );
  }
}
