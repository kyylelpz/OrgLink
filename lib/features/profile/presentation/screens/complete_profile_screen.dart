import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- ADDED
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
  String? _college;
  String? _program;
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
    _college = AcademicOptions.colleges.contains(details?.college)
        ? details?.college
        : null;
    _program = AcademicOptions.programsFor(_college).contains(details?.program)
        ? details?.program
        : null;
    final year = details?.yearLevel;
    _year = year != null && year >= 1 && year <= 6 ? year : null;
    _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _section.dispose();
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
        college: _college,
        program: _program,
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

    // VIEW STATE
    if (!_editing && auth.profile?.isEligible == true) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.brandMist,
          appBar: AppBar(
            title: const Text('Your Profile'),
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
            automaticallyImplyLeading: false,
          ),
          body: ProfileOverview(
            auth: auth,
            onEdit: () {
              _seed(auth);
              setState(() => _editing = true);
            },
          ),
        ),
      );
    }

    // EDIT STATE
    final photo = auth.user?.photoURL;
    final busy = auth.isBusy || _saved;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          title: const Text('Student Profile'),
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
                  description: 'Your campus profile.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    ProfileIdentity(name: _name.text, photo: photo, size: 60),
                    const SizedBox(width: AppSpacing.lg),
                    const Expanded(child: Text('Profile photo')),
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
                  decoration: const InputDecoration(
                    labelText: 'Student Number',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: 'Year Level'),
                  items: [
                    for (var year = 1; year <= 6; year++)
                      DropdownMenuItem(
                        value: year,
                        child: Text(
                          'Year $year',
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
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
                DropdownButtonFormField<String>(
                  key: const ValueKey('college-field'),
                  initialValue: _college,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'College'),
                  items: [
                    for (final college in AcademicOptions.colleges)
                      DropdownMenuItem(
                        value: college,
                        child: Text(college, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          _college = value;
                          _program = null;
                        }),
                  validator: AcademicOptions.validateCollege,
                ),
                const SizedBox(height: AppSpacing.lg),
                KeyedSubtree(
                  key: const ValueKey('program-field'),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('program/$_college'),
                    initialValue: _program,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(labelText: 'Program'),
                    selectedItemBuilder: (context) => [
                      for (final program in AcademicOptions.programsFor(
                        _college,
                      ))
                        Text(program, overflow: TextOverflow.ellipsis),
                    ],
                    items: [
                      for (final program in AcademicOptions.programsFor(
                        _college,
                      ))
                        DropdownMenuItem(
                          value: program,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(child: Text(program)),
                                if (_program == program)
                                  const Icon(
                                    Icons.check,
                                    color: AppColors.brandBlue,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    onChanged: busy || _college == null
                        ? null
                        : (value) => setState(() => _program = value),
                    validator: (value) =>
                        AcademicOptions.validateProgram(_college, value),
                  ),
                ),
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
      ),
    );
  }
}
