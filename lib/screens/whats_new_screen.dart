import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../models/changelog_entry.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_format_it.dart';
import '../widgets/app_icons.dart';

/// Fase G del piano post-beta: changelog "Novità e aggiornamenti" letto
/// dalla collection Firestore top-level `changelog` (sola lettura per il
/// client, vedi firestore.rules) — il contenuto viene aggiunto a mano
/// (Firebase Console/Admin SDK) a ogni release, senza bisogno di una nuova
/// build dell'app per pubblicare una voce.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Novità e aggiornamenti',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: StreamBuilder<List<ChangelogEntry>>(
        stream: service.streamChangelog(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nessuna novità al momento.',
                  style: TextStyle(color: AppColors.neutral),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) => _entryCard(entries[i]),
          );
        },
      ),
    );
  }

  Widget _entryCard(ChangelogEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: const AppIcon(
                  HeroIcons.megaphone,
                  color: AppColors.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              'v${entry.version} · ${formatDateIt(entry.date)}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
          ),
          if (entry.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...entry.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.primary)),
                    Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
