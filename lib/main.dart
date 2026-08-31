import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav_shell.dart';
import 'screens/login_screen.dart';

// Metti questo a false quando vuoi testare contro Firebase vero
// anche da un ambiente di sviluppo (utile per verificare la build release
// prima di pubblicare). In produzione (release build) non ha comunque
// effetto: kDebugMode è sempre false in una build release.
const bool useEmulators = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Gli emulatori si collegano SOLO in debug locale, MAI in una build release.
  // Così puoi continuare a sviluppare offline, ma un tester che installa
  // l'APK release parlerà sempre con Firebase vero, non con il tuo localhost.
  if (kDebugMode && useEmulators) {
    FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
    FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }

  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatelessWidget {
  const SmartBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBudget',
      theme: AppTheme.light(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const BottomNavShell();
          }
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
