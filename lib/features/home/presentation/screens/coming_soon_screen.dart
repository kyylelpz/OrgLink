import 'package:flutter/material.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_feedback.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), leading: const AppBackButton()),
    body: AppEmptyView(title: 'Coming Soon', message: message, icon: icon),
  );
}
