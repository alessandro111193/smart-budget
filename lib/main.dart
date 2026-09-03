import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

/// Permette a `main()` (fuori dall'albero widget) di mostrare uno SnackBar
/// dalla Home o da qualunque altra schermata sia aperta al momento —
/// FirebaseMessaging.onMessage non era mai ascoltato prima d'ora, quindi
/// una notifica arrivata ad app aperta non produceva alcun feedback visivo
/// (restava comunque nello storico "Notifiche", solo senza un avviso
/// immediato).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Su web (incluso il target usato dalla PWA su iOS) il SDK sceglie da solo
  // la persistenza migliore disponibile, ma può degradare in silenzio a
  // "solo in memoria" (login perso ad ogni riapertura) in contesti dove
  // IndexedDB è ristretto — richiederla esplicitamente evita quel fallback
  // silenzioso. Non è garantito risolva del tutto il problema su iPhone:
  // Safari/WebKit hanno una storia nota di trattare la storage di una PWA
  // aggiunta alla schermata Home in modo separato e più volatile rispetto a
  // Safari normale, un limite della piattaforma non testabile da qui (nessun
  // dispositivo iOS reale in questo ambiente).
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

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

  // Notifica ricevuta mentre l'app è già aperta: FCM di default non mostra
  // alcun banner di sistema in questo caso (a differenza di quando l'app è
  // in background), quindi senza questo listener la notifica sarebbe
  // visibile solo riaprendo la schermata "Notifiche" in un secondo momento.
  FirebaseMessaging.onMessage.listen((message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text([title, body].whereType<String>().join(' — ')),
        duration: const Duration(seconds: 4),
      ),
    );
  });

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
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
