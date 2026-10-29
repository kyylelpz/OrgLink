import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app/dependency_injection.dart';
import 'app/startup.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppStartup(
      initialize: () async {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      },
      builder: (gate) => AppDependencies(splashGate: gate),
    ),
  );
}
