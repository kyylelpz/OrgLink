import '../../../../core/widgets/profile_photo_crop_dialog.dart';
import '../../../../core/utils/event_poster_layout.dart';
import '../../../../core/widgets/image_editor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/worker_api_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/capitalization_suggestion.dart';
import '../../../../core/constants/app_routes.dart';
import '../../data/models/event.dart';
import '../viewmodels/event_context_view_model.dart';
import '../widgets/event_access_view.dart';
import '../widgets/event_widgets.dart';

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key});
  @override
  State<EventEditorScreen> createState() => EventEditorScreenState();
}

class EventEditorScreenState extends State<EventEditorScreen> {
  Future<bool>? _leaving;
  String get ownerUid => context.read<EventContextViewModel>().uid;
  Future<bool> confirmExit() async {
    final model = context.read<EventContextViewModel>();
    if (model.eventId != null) return true;
    if (model.busy) return false;
    if (model.selectedPoster == null) return true;
    if (_leaving != null) return _leaving!;
    _leaving = showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Leave Without Poster?'),
        content: Text(
          model.creationSaved
              ? 'Your draft is saved, but its poster upload was not confirmed. Leaving will discard the local image. Check the saved draft before uploading again.'
              : 'The selected poster and unsaved event details will be discarded. Stay to finish saving your draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
    try {
      return await _leaving!;
    } finally {
      _leaving = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          backgroundColor: AppColors.brandMidnight,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppShape.featureRadius),
            ),
          ),
          leading: const AppBackButton(),
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
      capacity = TextEditingController();
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: state.errorText,
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: AppShape.action,
            borderSide: BorderSide.none,
          ),
        ),
        child: InkWell(
          onTap: busy ? null : () => pick(value, change),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  schedule(value),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return AppPageBody(
      child: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              AppSectionHeading(
                title: model.eventId == null
                    ? 'Create Something Great'
                    : 'Fine-tune Your Event',
                description: model.organization.value!.name,
                prominent: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Save your event details as a draft. Approval and publication are separate actions.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Poster and details share the event information card.
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionHeading(title: 'Event Poster'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '(Optional)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (model.eventId != null) ...[
                      if (model.event?.value != null)
                        EventPoster(
                          event: model.event!.value!,
                          organizationName: model.organization.value!.name,
                        ),
                      ImageEditor(
                        key: ValueKey('poster/${model.eventId}'),
                        resource: ImageResource(
                          'event',
                          organizationId: model.organizationId,
                          eventId: model.eventId,
                        ),
                        label: 'Poster',
                        currentURL: model.event?.value?.posterURL,
                      ),
                    ] else ...[
                      if (model.selectedPoster case final bytes?)
                        AspectRatio(
                          aspectRatio: EventPosterLayout.aspectRatio(context),
                          child: Image.memory(
                            bytes,
                            key: const ValueKey('selected-event-poster'),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Text(
                                'This image cannot be previewed. Choose another image.',
                              ),
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: model.busy
                                ? null
                                : () => model.selectPoster(
                                    context.read<ImageUploadService?>() ??
                                        ImageUploadService(
                                          WorkerApiService(
                                            FirebaseAuth.instance,
                                          ),
                                        ),
                                    prepare: (bytes) =>
                                        showEventPosterCrop(context, bytes),
                                  ),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(
                              model.selectedPoster == null
                                  ? 'Select Poster'
                                  : 'Change Poster',
                            ),
                          ),
                          if (model.selectedPoster != null)
                            TextButton(
                              onPressed: model.busy
                                  ? null
                                  : model.removeSelectedPoster,
                              child: const Text('Remove Poster'),
                            ),
                        ],
                      ),
                      const Text(
                        'JPEG, PNG or WebP, up to 5 MiB. The poster uploads after your draft is saved.',
                      ),
                      if (model.creationSaved)
                        const Text(
                          'Your draft is saved. Retry the poster upload or open the saved draft. Event details are locked here to prevent duplicate creation.',
                        ),
                      if (model.posterMessage != null)
                        Text(model.posterMessage!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const AppSectionHeading(title: 'Event Details'),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: title,
                      textCapitalization: TextCapitalization.words,
                      enabled: !model.formLocked,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: AppShape.action,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) => EventDraft.requiredText(value),
                    ),
                    CapitalizationSuggestion(
                      controller: title,
                      enabled: !model.formLocked,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: description,
                      enabled: !model.formLocked,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: AppShape.action,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) =>
                          EventDraft.requiredText(value, maximum: 5000),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // SCHEDULE CARD
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionHeading(title: 'Schedule and Capacity'),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: venue,
                      enabled: !model.formLocked,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: 'Venue',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: AppShape.action,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) => EventDraft.requiredText(value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: capacity,
                      enabled: !model.formLocked,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Maximum Attendees',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: AppShape.action,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        final count = int.tryParse(value ?? '');
                        return count == null || count < 1 || count > 100000
                            ? 'Enter a capacity from 1 to 100000.'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    dateField(
                      'Start Date and Time',
                      start,
                      (value) => start = value,
                      (value) => value == null || !value.isAfter(DateTime.now())
                          ? 'Choose a future start.'
                          : null,
                      model.formLocked,
                    ),
                    dateField(
                      'End Date and Time',
                      end,
                      (value) => end = value,
                      (value) => value == null || !value.isAfter(start)
                          ? 'End must follow start.'
                          : null,
                      model.formLocked,
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
                      model.formLocked,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: visibility,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Event Visibility',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: AppShape.action,
                          borderSide: BorderSide.none,
                        ),
                      ),
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
                      onChanged: model.formLocked
                          ? null
                          : (value) => setState(() => visibility = value!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (model.failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    model.failure!.message,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (model.busy && !model.selectingPoster)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: LinearProgressIndicator(
                    value: model.posterProgress == 1
                        ? null
                        : model.posterProgress,
                  ),
                ),
              FilledButton(
                onPressed: model.busy
                    ? null
                    : () async {
                        if (!model.creationSaved &&
                            !form.currentState!.validate()) {
                          return;
                        }
                        final id = model.creationSaved
                            ? await model.retryPoster()
                            : await model.save(
                                EventDraft(
                                  title: title.text,
                                  description: description.text,
                                  startAt: start,
                                  endAt: end,
                                  venue: venue.text,
                                  capacity: int.parse(capacity.text),
                                  registrationDeadline: deadline,
                                  visibility: visibility,
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  model.creationSaved
                      ? model.selectedPoster == null
                            ? 'Open Draft'
                            : 'Retry Upload'
                      : 'Save Draft',
                ),
              ),
              if (model.creationSaved && model.selectedPoster != null)
                TextButton(
                  onPressed: model.busy
                      ? null
                      : () => context.go(
                          AppRoutes.event(
                            model.organizationId,
                            model.createdDraftId!,
                          ),
                        ),
                  child: const Text('Open Saved Draft'),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
