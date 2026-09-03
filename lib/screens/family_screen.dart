import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../services/family_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../models/family.dart';
import '../widgets/app_icons.dart';
import '../widgets/family_premium_blocked_card.dart';
import 'family_dashboard_screen.dart';
import 'new_family_expense_screen.dart';
import 'premium_screen.dart';
import 'scan_family_receipt_screen.dart';

class FamilyScreen extends StatelessWidget {
  FamilyScreen({super.key});

  final _service = FamilyService();
  final _userService = FirestoreService();

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
    // Blocco C: creare una famiglia è ora una funzione Premium (Trial
    // conta come attivo), ma unirsi con un invito resta possibile per
    // chiunque con piano Free — quindi gli inviti pendenti restano sempre
    // visibili, solo il modulo di creazione è condizionato.
    return StreamBuilder<AppUser>(
      stream: _userService.streamUser(),
      builder: (context, snapshot) {
        final hasAi = snapshot.data?.hasAiAccess ?? false;
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
              if (hasAi)
                _createFamilyForm(context)
              else
                _createFamilyPremiumNotice(context),
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
      },
    );
  }

  Widget _createFamilyForm(BuildContext context) {
    final nameController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              try {
                await _service.createFamily(nameController.text);
              } on FirebaseFunctionsException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message ?? 'Impossibile creare la famiglia.'),
                  ),
                );
              }
            },
            child: const Text('Crea famiglia'),
          ),
        ),
      ],
    );
  }

  Widget _createFamilyPremiumNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creare una famiglia è una funzione Premium',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          // "2" = MAX_FAMILY_MEMBERS (functions/index.js) - 1 (l'owner):
          // testo puramente informativo, va aggiornato a mano insieme alla
          // costante server se il limite cambia in futuro.
          const Text(
            'Passa a Premium (o attiva un Trial) per creare una famiglia e '
            'invitare fino a 2 membri con piano Free.',
            style: TextStyle(fontSize: 13, color: AppColors.neutral),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: _primaryButtonStyle(AppColors.primary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PremiumScreen()),
              ),
              child: const Text('Vai a Premium'),
            ),
          ),
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
                  onPressed: () async {
                    // Blocco C: può fallire con "resource-exhausted" se la
                    // famiglia ha già raggiunto il numero massimo di membri
                    // — prima d'ora questa chiamata non poteva mai fallire
                    // per un motivo visibile all'utente, quindi non aveva
                    // alcuna gestione d'errore.
                    try {
                      await _service.acceptInvite(
                        inv['familyId'],
                        inv['inviteId'],
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore: ${e.toString()}')),
                        );
                      }
                    }
                  },
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
        if (family == null) return const SizedBox.shrink();
        // Blocco D: se il Premium/Trial dell'owner è scaduto, buste/spese/
        // entrate familiari restano intatte su Firestore (le Rules le
        // bloccano in lettura/scrittura) — FamilyAccessGate mostra subito
        // il motivo invece di un errore di permessi generico o una
        // schermata vuota se si provasse comunque a caricarle sotto.
        return FamilyAccessGate(
          family: family,
          myUid: FirebaseAuth.instance.currentUser?.uid,
          title: family.name,
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              family.name,
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
                final isOwner = family.ownerId == myUid;
                return Column(
                  children: members.map((m) {
                    final canRemove = isOwner && m.userId != family.ownerId;
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
            const SizedBox(height: 10),
            StreamBuilder<AppUser>(
              stream: _userService.streamUser(),
              builder: (context, userSnapshot) {
                final hasAi = userSnapshot.data?.hasAiAccess ?? false;
                return ElevatedButton.icon(
                  onPressed: () {
                    if (hasAi) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ScanFamilyReceiptScreen(familyId: familyId),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PremiumScreen()),
                      );
                    }
                  },
                  icon: const AppIcon(
                    HeroIcons.camera,
                    color: Colors.white,
                  ),
                  label: const Text('Scansiona scontrino famiglia'),
                  style: _primaryButtonStyle(AppColors.accent),
                );
              },
            ),
          ],
          ),
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
