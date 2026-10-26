import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/dependency_injection.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_feedback.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const AppDependencies());
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'OrgLink startup',
      ),
    );
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: AppErrorView(
            message:
                'OrgLink could not start. Please close and reopen the app.',
          ),
        ),
      ),
    );
  }
}
