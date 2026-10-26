import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';

class OrgLinkApp extends StatelessWidget {
  const OrgLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OrgLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: context.read<GoRouter>(),
    );
  }
}
