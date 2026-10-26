import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Complete Student Profile',
    message:
        'Student profile setup will be available once the profile schema is defined.',
  );
}
