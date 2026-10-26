import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../data/models/event.dart';
import '../viewmodels/event_context_view_model.dart';
import '../widgets/event_access_view.dart';
import '../widgets/event_widgets.dart';

class EventEditorScreen extends StatelessWidget {
  const EventEditorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            model.eventId == null
                ? AppRoutes.manageEvents(model.organizationId)
                : AppRoutes.event(model.organizationId, model.eventId!),
          ),
        ),
        title: Text(model.eventId == null ? 'Create Event' : 'Edit Event'),
      ),
      body: EventAccessView(
        requireEvent: model.eventId != null,
        builder: (context) {
          if (model.eventId == null ? !model.canCreate : !model.canEdit) {
            return const Center(
              child: Text('You do not have permission to edit this event.'),
            );
          }
          return const _EventForm();
        },
      ),
    );
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm();
  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      venue = TextEditingController(),
      capacity = TextEditingController(),
      poster = TextEditingController();
  late DateTime start, end, deadline;
  String visibility = 'public';
  bool seeded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (seeded) return;
    final model = context.read<EventContextViewModel>(),
        draft = context.read<EventContextViewModel>().event?.value?.draft;
    start =
        draft?.startAt.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    end = draft?.endAt.toLocal() ?? start.add(const Duration(hours: 2));
    deadline =
        draft?.registrationDeadline.toLocal() ??
        start.subtract(const Duration(hours: 1));
    title.text = draft?.title ?? '';
    description.text = draft?.description ?? '';
    venue.text = draft?.venue ?? '';
    capacity.text = '${draft?.capacity ?? 50}';
    poster.text = draft?.posterURL ?? '';
    visibility =
        draft?.visibility ??
        (model.organization.value?.visibility == 'private'
            ? 'private'
            : 'public');
    seeded = true;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    venue.dispose();
    capacity.dispose();
    poster.dispose();
    super.dispose();
  }

  Future<void> pick(DateTime current, void Function(DateTime) change) async {
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time != null && mounted) {
      setState(
        () => change(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        ),
      );
    }
  }

  Widget dateField(
    String label,
    DateTime value,
    void Function(DateTime) change,
    String? Function(DateTime?) validate,
    bool busy,
  ) => FormField<DateTime>(
    key: ValueKey('$label/$value'),
    initialValue: value,
    validator: validate,
    builder: (state) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: state.errorText,
        ),
        child: TextButton(
          onPressed: busy ? null : () => pick(value, change),
          child: Text(schedule(value)),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              model.organization.value!.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: title,
              enabled: !model.busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Event Title'),
              validator: (value) => EventDraft.requiredText(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: description,
              enabled: !model.busy,
              maxLines: 4,
              maxLength: 5000,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) =>
                  EventDraft.requiredText(value, maximum: 5000),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: venue,
              enabled: !model.busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Venue'),
              validator: (value) => EventDraft.requiredText(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: capacity,
              enabled: !model.busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum Attendees'),
              validator: (value) {
                final count = int.tryParse(value ?? '');
                return count == null || count < 1 || count > 100000
                    ? 'Enter a capacity from 1 to 100000.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            dateField(
              'Start Date and Time',
              start,
              (value) => start = value,
              (value) => value == null || !value.isAfter(DateTime.now())
                  ? 'Choose a future start.'
                  : null,
              model.busy,
            ),
            dateField(
              'End Date and Time',
              end,
              (value) => end = value,
              (value) => value == null || !value.isAfter(start)
                  ? 'End must follow start.'
                  : null,
              model.busy,
            ),
            dateField(
              'Registration Deadline',
              deadline,
              (value) => deadline = value,
              (value) =>
                  value == null ||
                      !value.isAfter(DateTime.now()) ||
                      value.isAfter(start)
                  ? 'Deadline must be in the future and no later than start.'
                  : null,
              model.busy,
            ),
            DropdownButtonFormField<String>(
              initialValue: visibility,
              decoration: const InputDecoration(labelText: 'Event Visibility'),
              items: [
                if (model.organization.value!.visibility == 'public')
                  const DropdownMenuItem(
                    value: 'public',
                    child: Text('Public'),
                  ),
                const DropdownMenuItem(
                  value: 'private',
                  child: Text('Members Only'),
                ),
              ],
              onChanged: model.busy
                  ? null
                  : (value) => setState(() => visibility = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: poster,
              enabled: !model.busy,
              decoration: const InputDecoration(
                labelText: 'Poster HTTPS URL (optional)',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final uri = Uri.tryParse(value.trim());
                return uri?.scheme == 'https' && uri!.host.isNotEmpty
                    ? null
                    : 'Enter a valid HTTPS URL.';
              },
            ),
            const SizedBox(height: 16),
            if (model.failure != null) Text(model.failure!.message),
            if (model.busy) const LinearProgressIndicator(),
            FilledButton(
              onPressed: model.busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      final id = await model.save(
                        EventDraft(
                          title: title.text,
                          description: description.text,
                          startAt: start,
                          endAt: end,
                          venue: venue.text,
                          capacity: int.parse(capacity.text),
                          registrationDeadline: deadline,
                          visibility: visibility,
                          posterURL: poster.text,
                        ),
                      );
                      if (context.mounted && id != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Event draft saved. Submit it for manager approval.',
                            ),
                          ),
                        );
                        context.go(AppRoutes.event(model.organizationId, id));
                      }
                    },
              child: const Text('Save Draft'),
            ),
          ],
        ),
      ),
    );
  }
}
