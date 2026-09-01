import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/buste_screen.dart';
import '../screens/spese_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/premium_screen.dart';
import '../services/firestore_service.dart';
import '../theme/icon_palette.dart';
import '../models/app_user.dart';
import 'app_icons.dart';
import 'free_ad_banner.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(),
      const BusteScreen(),
      const SpeseScreen(),
      AnalysisScreen(),
      StreamBuilder<AppUser>(
        stream: _service.streamUser(),
        builder: (context, snapshot) {
          final hasAi = snapshot.data?.hasAiAccess ?? false;
          return hasAi ? const AiChatScreen() : PremiumScreen();
        },
      ),
    ];

    return StreamBuilder<AppUser>(
      stream: _service.streamUser(),
      builder: (context, userSnapshot) {
        // Solo il piano Free (né Premium né Trial attivo) vede pubblicità.
        final isFree = !(userSnapshot.data?.hasAiAccess ?? true);

        return Scaffold(
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FreeAdBanner(show: isFree),
              BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: IconPalette.primary,
                unselectedItemColor: IconPalette.accent,
                items: const [
                  BottomNavigationBarItem(
                    icon: NavIcon(type: NavType.home, selected: false),
                    activeIcon: NavIcon(type: NavType.home, selected: true),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: NavIcon(type: NavType.buste, selected: false),
                    activeIcon: NavIcon(type: NavType.buste, selected: true),
                    label: 'Buste',
                  ),
                  BottomNavigationBarItem(
                    icon: NavIcon(type: NavType.spese, selected: false),
                    activeIcon: NavIcon(type: NavType.spese, selected: true),
                    label: 'Spese',
                  ),
                  BottomNavigationBarItem(
                    icon: NavIcon(type: NavType.statistiche, selected: false),
                    activeIcon: NavIcon(
                      type: NavType.statistiche,
                      selected: true,
                    ),
                    label: 'Statistiche',
                  ),
                  BottomNavigationBarItem(
                    icon: NavIcon(type: NavType.ai, selected: false),
                    activeIcon: NavIcon(type: NavType.ai, selected: true),
                    label: 'AI',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
