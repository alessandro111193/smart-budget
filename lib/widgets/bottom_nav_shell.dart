import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/buste_screen.dart';
import '../screens/new_expense_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/premium_screen.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';

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
      const NewExpenseScreen(),
      AnalysisScreen(),
      StreamBuilder<AppUser>(
        stream: _service.streamUser(),
        builder: (context, snapshot) {
          final hasAi = snapshot.data?.hasAiAccess ?? false;
          return hasAi ? const AiChatScreen() : PremiumScreen();
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.neutral,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            label: 'Buste',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Spese',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Statistiche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
