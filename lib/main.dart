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
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/onboarding/setup/setup_flow.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/firestore_service.dart';
import 'services/onboarding_service.dart';

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

  await AdService.initialize();
  AnalyticsService.logAppOpen();

  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatelessWidget {
  const SmartBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBudget',
      theme: AppTheme.light(),
      home: const _RootGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Decide cosa mostrare all'avvio, in ordine:
/// 1. la mini demo interattiva (`OnboardingFlow`), una sola volta per
///    dispositivo, anche prima del login;
/// 2. login/registrazione (schermata esistente, riusata — non ne esiste
///    una seconda);
/// 3. per un account appena creato da qui, il wizard di configurazione
///    reale (`SetupFlow`: nome/entrate/buste/obiettivo);
/// 4. la Home reale, per tutti gli altri casi (account esistenti creati
///    prima di questa funzionalità non vedono mai il wizard).
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    OnboardingService.hasSeenOnboarding().then((seen) {
      if (mounted) setState(() => _onboardingSeen = seen);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingSeen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingSeen!) {
      return OnboardingFlow(
        onDone: () => setState(() => _onboardingSeen = true),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        return StreamBuilder<bool>(
          stream: FirestoreService().streamSetupCompleted(),
          builder: (context, setupSnapshot) {
            if (setupSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (setupSnapshot.data == false) {
              return const SetupFlow();
            }
            return const BottomNavShell();
          },
        );
      },
    );
  }
}
