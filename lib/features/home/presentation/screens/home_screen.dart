import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Home Dashboard',
    message: 'Your OrgLink dashboard will be available here.',
  );
}
