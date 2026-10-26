import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../viewmodels/event_context_view_model.dart';

class EventAccessView extends StatelessWidget {
  const EventAccessView({
    super.key,
    this.requireEvent = false,
    required this.builder,
  });
  final bool requireEvent;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    if (model.organization.loading ||
        model.membership.loading ||
        (requireEvent && model.event!.loading)) {
      return const AppLoadingView();
    }
    if (model.organization.failure != null) {
      return AppErrorView(
        message: model.organization.failure!.message,
        onRetry: model.organization.retry,
      );
    }
    if (model.membership.failure != null) {
      return AppErrorView(
        message: model.membership.failure!.message,
        onRetry: model.membership.retry,
      );
    }
    if (requireEvent && model.event!.failure != null) {
      return AppErrorView(
        message: model.event!.failure!.message,
        onRetry: model.event!.retry,
      );
    }
    if (model.organization.value == null ||
        (requireEvent && model.event!.value == null)) {
      return const Center(child: Text('Event or organization unavailable.'));
    }
    return builder(context);
  }
}
