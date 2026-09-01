import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../services/family_service.dart';
import '../models/family.dart';
import '../widgets/app_icons.dart';
import 'family_dashboard_screen.dart';
import 'new_family_expense_screen.dart';

class FamilyScreen extends StatelessWidget {
  FamilyScreen({super.key});

  final _service = FamilyService();

  static InputDecoration _fieldDecoration({String? labelText}) {
    return InputDecoration(
      labelText: labelText,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  static ButtonStyle _primaryButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Famiglia',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
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
            decoration: _fieldDecoration(labelText: 'Nome della famiglia'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: _primaryButtonStyle(AppColors.primary),
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                await _service.createFamily(nameController.text);
              },
              child: const Text('Crea famiglia'),
            ),
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
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.secondary.withOpacity(0.12),
                  child: const AppIcon(
                    HeroIcons.envelope,
                    color: AppColors.secondary,
                  ),
                ),
                title: Text('Invito per ${inv['email']}'),
                trailing: ElevatedButton(
                  style: _primaryButtonStyle(AppColors.primary).copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
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
            const Text(
              'Membri',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<FamilyMember>>(
              stream: _service.streamMembers(familyId),
              builder: (context, snapshot) {
                final members = snapshot.data ?? [];
                final myUid = FirebaseAuth.instance.currentUser?.uid;
                final isOwner = family?.ownerId == myUid;
                return Column(
                  children: members.map((m) {
                    final canRemove = isOwner && m.userId != family?.ownerId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                        title: Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          m.role == 'owner' ? 'Proprietario' : 'Membro',
                          style: const TextStyle(color: AppColors.neutral),
                        ),
                        trailing: canRemove
                            ? IconButton(
                                icon: const AppIcon(
                                  HeroIcons.userMinus,
                                  color: AppColors.danger,
                                ),
                                tooltip: 'Rimuovi dalla famiglia',
                                onPressed: () => _confirmRemoveMember(
                                  context,
                                  familyId,
                                  m,
                                ),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showInviteDialog(context, familyId),
              icon: const AppIcon(
                HeroIcons.userPlus,
                color: Colors.white,
              ),
              label: const Text('Invita un membro'),
              style: _primaryButtonStyle(AppColors.secondary),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyDashboardScreen(familyId: familyId),
                ),
              ),
              icon: const AppIcon(
                HeroIcons.squares2x2,
                color: Colors.white,
              ),
              label: const Text('Apri dashboard famiglia'),
              style: _primaryButtonStyle(AppColors.accent),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewFamilyExpenseScreen(familyId: familyId),
                ),
              ),
              icon: const AppIcon(
                HeroIcons.minusCircle,
                color: Colors.white,
              ),
              label: const Text('Nuova spesa familiare'),
              style: _primaryButtonStyle(AppColors.warning),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemoveMember(
    BuildContext context,
    String familyId,
    FamilyMember member,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Rimuovere il membro?'),
        content: Text(
          '${member.name} perderà l\'accesso ai dati di questa famiglia. '
          'Le spese/entrate già registrate a suo nome restano nello storico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final msg = await _service.removeMember(
                  familyId,
                  member.userId,
                );
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(msg)));
              } catch (e) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Errore: ${e.toString()}')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(
              'Rimuovi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, String familyId) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Invita un membro'),
        content: TextField(
          controller: emailController,
          decoration: _fieldDecoration(labelText: 'Email della persona'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Invita',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
