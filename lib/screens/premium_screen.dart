import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';

class PremiumScreen extends StatelessWidget {
  PremiumScreen({super.key});

  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: StreamBuilder<AppUser>(
        stream: _service.streamUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sblocca tutto il potenziale',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _feature('🤖', 'AI Assistant avanzato'),
                _feature('📸', 'Scanner scontrino'),
                _feature('📊', 'Analisi approfondite'),
                _feature('🚫', 'Nessuna pubblicità'),
                const SizedBox(height: 24),
                if (user != null && user.isPremium)
                  const Text(
                    'Sei già Premium 🎉',
                    style: TextStyle(color: AppColors.primary, fontSize: 16),
                  )
                else if (user != null && user.isTrialActive)
                  Text(
                    'Trial attivo fino al ${user.trialEnd!.day}/${user.trialEnd!.month}/${user.trialEnd!.year}\n'
                    'Scontrini usati: ${user.scontriniUsati}/${AppUser.trialMaxScontrini}\n'
                    'Richieste AI usate: ${user.richiesteAiUsate}/${AppUser.trialMaxRichiesteAi}',
                  )
                else
                  ElevatedButton(
                    onPressed: () => _service.startTrial(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: const Text('Prova gratis 15 giorni'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _feature(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
