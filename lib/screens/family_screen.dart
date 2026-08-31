import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/family_service.dart';
import '../models/family.dart';
import 'family_dashboard_screen.dart';
import 'new_family_expense_screen.dart';

class FamilyScreen extends StatelessWidget {
  FamilyScreen({super.key});

  final _service = FamilyService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Famiglia')),
      body: StreamBuilder<String?>(
        stream: _service.streamMyFamilyId(),
        builder: (context, snapshot) {
          final familyId = snapshot.data;
          if (familyId == null) {
            return _noFamilyView(context);
          }
          return _familyView(context, familyId);
        },
      ),
    );
  }

  Widget _noFamilyView(BuildContext context) {
    final nameController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Non fai ancora parte di una famiglia',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nome della famiglia'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              await _service.createFamily(nameController.text);
            },
            child: const Text('Crea famiglia'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Oppure, se qualcuno ti ha invitato:',
            style: TextStyle(color: AppColors.neutral, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _pendingInvites(context),
        ],
      ),
    );
  }

  Widget _pendingInvites(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamMyPendingInvites(),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? [];
        if (invites.isEmpty) {
          return const Text(
            'Nessun invito in sospeso.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral),
          );
        }
        return Column(
          children: invites.map((inv) {
            return Card(
              child: ListTile(
                title: Text('Invito per ${inv['email']}'),
                trailing: ElevatedButton(
                  onPressed: () =>
                      _service.acceptInvite(inv['familyId'], inv['inviteId']),
                  child: const Text('Accetta'),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _familyView(BuildContext context, String familyId) {
    return StreamBuilder<Family?>(
      stream: _service.streamFamily(familyId),
      builder: (context, familySnapshot) {
        final family = familySnapshot.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              family?.name ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Membri', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<List<FamilyMember>>(
              stream: _service.streamMembers(familyId),
              builder: (context, snapshot) {
                final members = snapshot.data ?? [];
                return Column(
                  children: members.map((m) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(m.colorTag.replaceFirst('#', '0xFF')),
                          ),
                          child: Text(
                            m.name.isNotEmpty ? m.name[0] : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(m.name),
                        subtitle: Text(
                          m.role == 'owner' ? 'Proprietario' : 'Membro',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showInviteDialog(context, familyId),
              icon: const Icon(Icons.person_add),
              label: const Text('Invita un membro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyDashboardScreen(familyId: familyId),
                ),
              ),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Apri dashboard famiglia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewFamilyExpenseScreen(familyId: familyId),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Nuova spesa familiare'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInviteDialog(BuildContext context, String familyId) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invita un membro'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email della persona'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final msg = await _service.inviteMember(
                  familyId,
                  emailController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Invita'),
          ),
        ],
      ),
    );
  }
}
