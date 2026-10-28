import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/capitalization_suggestion.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/screens/auth_screens.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/student_profile.dart';
import '../widgets/profile_overview.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _section = TextEditingController();
  final _college = TextEditingController();
  final _program = TextEditingController();
  bool _editing = false;
  int? _year;
  bool _seeded = false;
  bool _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seed(context.read<AuthViewModel>());
  }

  void _seed(AuthViewModel auth) {
    final details = auth.profile?.details;
    _name.text = details?.fullName ?? auth.user?.displayName ?? '';
    _number.text = details?.studentNumber ?? '';
    _section.text = details?.section ?? '';
    _college.text = details?.college ?? '';
    _program.text = details?.program ?? '';
    final year = details?.yearLevel;
    _year = year != null && year >= 1 && year <= 6 ? year : null;
    _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _section.dispose();
    _college.dispose();
    _program.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    final succeeded = await auth.saveProfile(
      StudentDetails(
        fullName: _name.text,
        studentNumber: _number.text,
        yearLevel: _year!,
        section: _section.text,
        college: _college.text.isEmpty && auth.profile?.details.college == null
            ? null
            : _college.text,
        program: _program.text.isEmpty && auth.profile?.details.program == null
            ? null
            : _program.text,
      ),
    );
    if (!mounted || !succeeded) return;
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (_saved && auth.profileStatus == ProfileStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student profile saved.')),
          );
          context.go(AppRoutes.home);
        }
      });
    }
    if (!_editing && auth.profile?.isEligible == true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Profile'),
          leading: const AppBackButton(),
        ),
        body: ProfileOverview(
          auth: auth,
          onEdit: () {
            _seed(auth);
            setState(() => _editing = true);
          },
        ),
      );
    }
    final photo = auth.user?.photoURL;
    final busy = auth.isBusy || _saved;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        leading: auth.profile?.isEligible == true
            ? const AppBackButton()
            : null,
        actions: const [SignOutButton(compact: true)],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: const Text('Save Student Profile'),
                ),
                if (auth.profileStatus == ProfileStatus.ready)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (auth.profile?.isEligible == true) {
                              setState(() => _editing = false);
                            } else {
                              context.go(AppRoutes.accountStatus);
                            }
                          },
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: AppPageBody(
        maxWidth: AppLayout.formWidth,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeading(
                title: 'A Little About You',
                description:
                    'Your campus profile. Your Google email remains read-only.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  ProfileIdentity(name: _name.text, photo: photo, size: 60),
                  const SizedBox(width: AppSpacing.lg),
                  const Expanded(
                    child: Text(
                      'Profile photo · optional\nYour Google avatar is used when available.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                initialValue: auth.user?.email ?? '',
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Google Email'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !busy,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                validator: StudentDetails.validateName,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              CapitalizationSuggestion(controller: _name, enabled: !busy),
              const SizedBox(height: 16),
              TextFormField(
                controller: _number,
                enabled: !busy,
                maxLength: 30,
                validator: StudentDetails.validateStudentNumber,
                decoration: const InputDecoration(labelText: 'Student Number'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Year Level'),
                items: [
                  for (var year = 1; year <= 6; year++)
                    DropdownMenuItem(value: year, child: Text('Year $year')),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => _year = value),
                validator: (value) =>
                    value == null ? 'Select a year level.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _section,
                enabled: !busy,
                maxLength: 30,
                validator: StudentDetails.validateSection,
                decoration: const InputDecoration(labelText: 'Section'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('college-field'),
                controller: _college,
                enabled: !busy,
                maxLength: 160,
                validator: StudentDetails.validateAcademic,
                decoration: const InputDecoration(
                  labelText: 'College',
                  helperText: 'Optional. Enter your college name.',
                ),
              ),
              CapitalizationSuggestion(controller: _college, enabled: !busy),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('program-field'),
                controller: _program,
                enabled: !busy,
                maxLength: 160,
                validator: StudentDetails.validateAcademic,
                decoration: const InputDecoration(
                  labelText: 'Program',
                  helperText: 'Optional. Enter your program name.',
                ),
              ),
              CapitalizationSuggestion(controller: _program, enabled: !busy),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'You can update permitted profile fields later. Roles are never selected during sign-up.',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (auth.failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    auth.failure!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (busy) const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
