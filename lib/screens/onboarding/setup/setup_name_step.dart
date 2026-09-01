import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../theme/icon_palette.dart';
import 'setup_scaffold.dart';

/// Passaggio 1 del wizard reale: nome utente, salvato con
/// `FirebaseAuth.updateDisplayName` — lo stesso campo già usato dal
/// saluto in Home e come nome membro famiglia di default.
class SetupNameStep extends StatefulWidget {
  const SetupNameStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<SetupNameStep> createState() => _SetupNameStepState();
}

class _SetupNameStepState extends State<SetupNameStep> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updateDisplayName(name);
      await user?.reload();
    }
    if (mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Come possiamo chiamarti?',
      loading: _saving,
      primaryLabel: 'Continua',
      onPrimary: _save,
      child: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Es. Alessandro',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: IconPalette.primary),
          ),
        ),
      ),
    );
  }
}
