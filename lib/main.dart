import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const OrgLinkApp());
}

class OrgLinkApp extends StatelessWidget {
  const OrgLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('OrgLink'),
        ),
        body: const Center(
          child: Text(
            'Firebase initialized successfully!',
          ),
        ),
      ),
    );
  }
}