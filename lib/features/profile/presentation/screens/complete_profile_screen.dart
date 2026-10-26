import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/screens/auth_screens.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/models/student_profile.dart';

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
  int? _year;
  bool _seeded = false;
  bool _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final auth = context.read<AuthViewModel>();
    final details = auth.profile?.details;
    _name.text = details?.fullName ?? auth.user?.displayName ?? '';
    _number.text = details?.studentNumber ?? '';
    _section.text = details?.section ?? '';
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
    final photo = auth.user?.photoURL;
    final busy = auth.isBusy || _saved;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: const [SignOutButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photo != null)
                      Center(
                        child: ClipOval(
                          child: Image.network(
                            photo,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.account_circle, size: 72),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: auth.user?.email ?? '',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Google email',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      enabled: !busy,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      validator: StudentDetails.validateName,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _number,
                      enabled: !busy,
                      maxLength: 30,
                      validator: StudentDetails.validateStudentNumber,
                      decoration: const InputDecoration(
                        labelText: 'Student number',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Year level',
                      ),
                      items: [
                        for (var year = 1; year <= 6; year++)
                          DropdownMenuItem(
                            value: year,
                            child: Text('Year $year'),
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
                    FilledButton(
                      onPressed: busy ? null : _save,
                      child: const Text('Save student profile'),
                    ),
                    if (auth.profileStatus == ProfileStatus.ready)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.go(AppRoutes.home),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
