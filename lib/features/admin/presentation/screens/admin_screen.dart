import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/image_editor.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../profile/data/models/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/capitalization_suggestion.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import '../viewmodels/admin_view_model.dart';

bool canAdminister(AuthViewModel auth) =>
    auth.user != null &&
    auth.user?.requiresEmailVerification != true &&
    auth.profileStatus == ProfileStatus.ready &&
    auth.profile?.isPlatformAdmin == true;

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.section});
  final AdminSection section;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (!canAdminister(auth)) {
      return const _AdminFrame(
        title: 'Platform Administration',
        child: AppErrorView(
          message: 'Platform administrator access is required.',
        ),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey('${auth.user!.id}/${section.name}'),
      create: (context) =>
          AdminViewModel(context.read<AdminRepository>(), section)..load(),
      child: const _AdminContent(),
    );
  }
}

class _AdminFrame extends StatelessWidget {
  const _AdminFrame({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final path = GoRouterState.of(context).uri.path;
    Future<bool> back() async {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(
          path == AppRoutes.admin ? AppRoutes.completeProfile : AppRoutes.admin,
        );
      }
      return true;
    }

    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          titleTextStyle: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.white),
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          backgroundColor: AppColors.brandMidnight,
          foregroundColor: AppColors.white,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: back,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: child,
      ),
    );
  }
}

class _AdminContent extends StatefulWidget {
  const _AdminContent();
  @override
  State<_AdminContent> createState() => _AdminContentState();
}

class _AdminContentState extends State<_AdminContent> {
  final search = TextEditingController();
  String? searchField;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final accounts = vm.section == AdminSection.accounts;
    final title = switch (vm.section) {
      AdminSection.dashboard => 'Platform Admin',
      AdminSection.accounts => 'Account Management',
      AdminSection.organizations => 'Organization Management',
    };
    Widget body;
    if (vm.unauthorized) {
      body = AppErrorView(
        message: vm.error ?? 'Platform administrator access is required.',
      );
    } else if (vm.busy &&
        vm.stats == null &&
        vm.accounts.isEmpty &&
        vm.organizations.isEmpty) {
      body = const AppLoadingView(message: 'Loading administration...');
    } else {
      body = AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vm.error != null) ...[
              AppErrorView(
                message: vm.error!,
                onRetry: vm.busy ? null : vm.load,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (vm.message != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  vm.message!,
                  style: const TextStyle(color: AppColors.success),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (vm.section == AdminSection.dashboard) ...[
              const AppSectionHeading(
                title: 'Platform Overview',
                description:
                    'Live counts of saved user profiles and organizations.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (vm.stats case final stats?) ...[
                _metric('Users', stats.users),
                _metric('Pending Accounts', stats.pending),
                _metric('Organizations', stats.organizations),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppActionButton(
                label: 'Account Management',
                icon: Icons.manage_accounts_outlined,
                onPressed: () => context.push(AppRoutes.adminAccounts),
              ),
              const SizedBox(height: AppSpacing.md),
              AppActionButton(
                label: 'Organization Management',
                icon: Icons.business_outlined,
                onPressed: () => context.push(AppRoutes.adminOrganizations),
              ),
              const SizedBox(height: AppSpacing.md),
              AppActionButton(
                label: 'Refresh Counts',
                style: AppActionStyle.outlined,
                busy: vm.busy,
                onPressed: vm.load,
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                initialValue: searchField ?? vm.field,
                decoration: const InputDecoration(labelText: 'Search By'),
                items: [
                  DropdownMenuItem(
                    value: accounts ? 'fullName' : 'name',
                    child: const Text('Name Prefix'),
                  ),
                  if (accounts)
                    const DropdownMenuItem(
                      value: 'email',
                      child: Text('Exact Email'),
                    ),
                  DropdownMenuItem(
                    value: accounts ? 'studentNumber' : '__name__',
                    child: Text(
                      accounts ? 'Exact Student ID' : 'Exact Organization ID',
                    ),
                  ),
                ],
                onChanged: vm.busy
                    ? null
                    : (v) => setState(() => searchField = v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: search,
                enabled: !vm.busy,
                maxLength: (searchField ?? vm.field) == 'studentNumber'
                    ? 10
                    : 128,
                keyboardType: (searchField ?? vm.field) == 'studentNumber'
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  helperMaxLines: 4,
                  helperText:
                      'Names use a case-sensitive prefix; email and IDs use an exact match.',
                ),
                onSubmitted: (v) => vm.find(searchField ?? vm.field, v),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppActionButton(
                    label: 'Search',
                    busy: vm.busy,
                    onPressed: () =>
                        vm.find(searchField ?? vm.field, search.text),
                  ),
                  AppActionButton(
                    label: 'Refresh',
                    style: AppActionStyle.outlined,
                    onPressed: vm.busy ? null : vm.load,
                  ),
                  if (!accounts)
                    AppActionButton(
                      label: 'Create Organization',
                      icon: Icons.add,
                      onPressed: vm.busy ? null : () => _edit(vm, null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (accounts && vm.accounts.isEmpty ||
                  !accounts && vm.organizations.isEmpty)
                const AppEmptyView(
                  title: 'No Matching Records',
                  message: 'Try another search or return to the first page.',
                ),
              if (accounts)
                for (final account in vm.accounts) _account(vm, account)
              else
                for (final organization in vm.organizations)
                  _organization(vm, organization),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: !vm.busy && vm.hasPrevious ? vm.previous : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page ${vm.page}'),
                  TextButton(
                    onPressed: !vm.busy && vm.nextCursor != null
                        ? vm.next
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }
    return _AdminFrame(title: title, child: body);
  }

  Widget _metric(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text('$count', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
  );
  Widget _account(AdminViewModel vm, AdminAccount account) {
    final actorUid = context.read<AuthViewModel>().user!.id;
    final self = account.uid == actorUid;
    final mutable = !self && account.role == 'user' && !vm.busy;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              account.name.isEmpty ? 'Unnamed Account' : account.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(
              'Student ID: ${account.studentId.isEmpty ? 'Not Provided' : account.studentId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(account.email),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => _dialogGuard(
                  dialogContext,
                  actorUid,
                  AlertDialog(
                    title: const Text('Account Details'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.name),
                          SelectableText(
                            'Student ID: ${account.studentId.isEmpty ? 'Not Provided' : account.studentId}',
                          ),
                          SelectableText(account.email),
                          Text(displayIdentifier(account.status)),
                          Text(displayIdentifier(account.role)),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Account Details'),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppStatusChip(label: displayIdentifier(account.status)),
                AppStatusChip(label: displayIdentifier(account.role)),
              ],
            ),
            if (self) const Text('Your account cannot be changed here.'),
            if (mutable)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (account.status == 'pending') ...[
                    TextButton(
                      onPressed: () =>
                          _status(vm, account, 'approve', 'Approve Account'),
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _status(vm, account, 'reject', 'Reject Account'),
                      child: const Text('Reject'),
                    ),
                  ],
                  if (account.canReactivate)
                    TextButton(
                      onPressed: () => _status(
                        vm,
                        account,
                        'reactivate',
                        'Reactivate Account',
                      ),
                      child: const Text('Reactivate'),
                    ),
                  if (account.status == 'active')
                    TextButton(
                      onPressed: () => _status(
                        vm,
                        account,
                        'deactivate',
                        'Deactivate Account',
                      ),
                      child: const Text('Deactivate'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _organization(AdminViewModel vm, AdminOrganization record) {
    final org = record.organization;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OrganizationLogo(org.logoURL),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    org.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            SelectableText('ID: ${org.id}'),
            Text('Manager: ${record.managerName ?? 'Unavailable'}'),
            SelectableText(
              'Student ID: ${record.managerStudentId ?? 'Needs Registry Review'}',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppStatusChip(label: displayIdentifier(org.status)),
                AppStatusChip(label: displayIdentifier(org.visibility)),
              ],
            ),
            Text(org.description),
            if (org.status == 'active')
              ImageEditor(
                key: ValueKey('admin-logo/${org.id}'),
                resource: ImageResource('organization', organizationId: org.id),
                label: 'Logo',
                currentURL: org.logoURL,
                onSaved: vm.load,
              ),
            TextButton(
              onPressed: vm.busy ? null : () => _edit(vm, record),
              child: const Text('Edit Organization'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _status(
    AdminViewModel vm,
    AdminAccount account,
    String action,
    String title,
  ) async {
    final approved = await _confirm(
      context,
      title,
      '$title for ${account.name} (${account.email})? This changes platform access and preserves the student profile and history.',
    );
    if (approved && mounted && canAdminister(context.read<AuthViewModel>())) {
      await vm.submit({
        'operation': 'accountStatus',
        'targetId': account.uid,
        'version': account.version,
        'action': action,
      });
    }
  }

  Future<void> _edit(AdminViewModel vm, AdminOrganization? record) {
    final actorUid = context.read<AuthViewModel>().user!.id;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _OrganizationEditor(vm: vm, record: record, actorUid: actorUid),
    );
  }
}

Widget _dialogGuard(BuildContext context, String actorUid, Widget child) {
  final auth = context.watch<AuthViewModel>();
  if (canAdminister(auth) && auth.user!.id == actorUid) return child;
  return AlertDialog(
    title: const Text('Access Denied'),
    content: const Text('Your administrator session is no longer available.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async {
  final actorUid = context.read<AuthViewModel>().user!.id;
  return await showDialog<bool>(
        context: context,
        builder: (context) => _dialogGuard(
          context,
          actorUid,
          AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

class _OrganizationEditor extends StatefulWidget {
  const _OrganizationEditor({
    required this.vm,
    required this.record,
    required this.actorUid,
  });
  final AdminViewModel vm;
  final AdminOrganization? record;
  final String actorUid;
  @override
  State<_OrganizationEditor> createState() => _OrganizationEditorState();
}

class _OrganizationEditorState extends State<_OrganizationEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final newId = adminRequestId();
  late String visibility, status;
  bool accepts = true, saving = false, lookingUp = false;
  AdminManager? matched;
  String? error;
  @override
  void initState() {
    super.initState();
    final org = widget.record?.organization;
    final values = {
      'name': org?.name ?? '',
      'description': org?.description ?? '',
      'mission': org?.mission ?? '',
      'vision': org?.vision ?? '',
      'goals': org?.goals.join('\n') ?? '',
      'membershipRequirements': org?.membershipRequirements.join('\n') ?? '',
      'managerStudentId': widget.record?.managerStudentId ?? '',
    };
    for (final entry in values.entries) {
      controllers[entry.key] = TextEditingController(text: entry.value);
    }
    visibility = org?.visibility ?? 'public';
    status = org?.status ?? 'active';
    accepts = org?.approvalSettings['acceptsRequests'] == true || org == null;
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> findManager() async {
    final value = controllers['managerStudentId']!.text;
    if (StudentDetails.validateStudentNumber(value) != null) {
      setState(() => error = StudentDetails.validateStudentNumber(value));
      return;
    }
    setState(() {
      lookingUp = true;
      matched = null;
      error = null;
    });
    try {
      final result = await widget.vm.manager(value);
      if (mounted && controllers['managerStudentId']!.text == value) {
        setState(() {
          matched = result;
          if (!result.eligible) {
            error =
                'Only active accounts with complete profiles can become managers.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => lookingUp = false);
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final org = widget.record?.organization;
    final manager = matched;
    if (manager == null ||
        !manager.eligible ||
        manager.studentId != controllers['managerStudentId']!.text) {
      setState(
        () => error =
            'Find and review an eligible manager by Student ID before saving.',
      );
      return;
    }
    final confirmed = await _confirm(
      context,
      org == null ? 'Create Organization' : 'Save Organization',
      'Save ${controllers['name']!.text.trim()} with ${manager.name}, Student ID ${manager.studentId}, ${displayIdentifier(manager.status)}? Existing memberships, events and attendance records are retained.',
    );
    if (!mounted ||
        !confirmed ||
        !canAdminister(context.read<AuthViewModel>())) {
      return;
    }
    setState(() => saving = true);
    final changes = <String, dynamic>{
      for (final e in controllers.entries) e.key: e.value.text.trim(),
      'visibility': visibility,
      'status': status,
      'acceptsRequests': accepts,
      'managerStudentId': manager.studentId,
      'managerProfileVersion': manager.version,
      'managerRegistryVersion': manager.registryVersion,
    };
    for (final key in ['goals', 'membershipRequirements']) {
      changes[key] = controllers[key]!.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final saved = await widget.vm.submit({
      'operation': org == null ? 'createOrganization' : 'updateOrganization',
      'targetId': org?.id ?? newId,
      if (org != null) 'version': widget.record!.version,
      if (org != null) 'expectedManagerUid': org.managerUid,
      'changes': changes,
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = widget.vm.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _dialogGuard(
    context,
    widget.actorUid,
    PopScope(
      canPop: !saving && !lookingUp,
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        scrollable: true,
        title: Text(
          widget.record == null ? 'Create Organization' : 'Edit Organization',
        ),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                for (final entry in [
                  ('name', 'Organization Name', 100),
                  ('description', 'Description', 1500),
                  ('mission', 'Mission', 1000),
                  ('vision', 'Vision', 1000),
                  ('goals', 'Goals (One per Line)', 1210),
                  (
                    'membershipRequirements',
                    'Membership Requirements (One per Line)',
                    1210,
                  ),
                  ('managerStudentId', 'Manager Student ID', 10),
                ]) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: ValueKey('admin-${entry.$1}'),
                    controller: controllers[entry.$1],
                    enabled: !saving && !lookingUp,
                    maxLength: entry.$1 == 'managerStudentId' ? 10 : null,
                    keyboardType: entry.$1 == 'managerStudentId'
                        ? TextInputType.number
                        : TextInputType.text,
                    onChanged: entry.$1 == 'managerStudentId'
                        ? (_) => setState(() => matched = null)
                        : null,
                    minLines: 1,
                    maxLines:
                        [
                          'description',
                          'mission',
                          'vision',
                          'goals',
                          'membershipRequirements',
                        ].contains(entry.$1)
                        ? 4
                        : 1,
                    decoration: InputDecoration(
                      labelText: entry.$2,
                      helperMaxLines: 4,
                      helperText: entry.$1 == 'managerStudentId'
                          ? 'Enter the BulSU Student ID, then find and review the matched account.'
                          : null,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (['name'].contains(entry.$1) && v.length < 2) {
                        return 'Enter ${entry.$2.toLowerCase()}.';
                      }
                      if (v.length > entry.$3) {
                        return 'Use at most ${entry.$3} characters.';
                      }
                      if (entry.$1 == 'managerStudentId') {
                        return StudentDetails.validateStudentNumber(value);
                      }

                      return null;
                    },
                  ),
                  if (entry.$1 == 'managerStudentId') ...[
                    AppActionButton(
                      label: 'Find Manager',
                      busy: lookingUp,
                      onPressed: saving ? null : findManager,
                    ),
                    if (matched case final manager?)
                      AppSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(manager.name),
                            Text('Student ID: ${manager.studentId}'),
                            AppStatusChip(
                              label: displayIdentifier(manager.status),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (entry.$1 == 'name')
                    CapitalizationSuggestion(
                      controller: controllers['name']!,
                      enabled: !saving && !lookingUp,
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: visibility,
                  decoration: const InputDecoration(labelText: 'Visibility'),
                  items: [
                    for (final v in ['public', 'private'])
                      DropdownMenuItem(
                        value: v,
                        child: Text(displayIdentifier(v)),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (v) => setState(() => visibility = v!),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final v in ['active', 'inactive'])
                      DropdownMenuItem(
                        value: v,
                        child: Text(displayIdentifier(v)),
                      ),
                  ],
                  onChanged: saving ? null : (v) => setState(() => status = v!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Accept Membership Requests'),
                  value: accepts,
                  onChanged: saving ? null : (v) => setState(() => accepts = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving || lookingUp
                ? null
                : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          AppActionButton(
            label: 'Review and Save',
            busy: saving || lookingUp,
            onPressed: save,
          ),
        ],
      ),
    ),
  );
}
