import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../services/analytics_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Traduce i codici più comuni di FirebaseAuthException in un messaggio
  /// italiano comprensibile invece del testo inglese grezzo di Firebase.
  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Email o password non corrette.';
      case 'invalid-email':
        return 'L\'indirizzo email non è valido.';
      case 'user-disabled':
        return 'Questo account è stato disabilitato.';
      case 'email-already-in-use':
        return 'Esiste già un account con questa email. Prova ad accedere.';
      case 'weak-password':
        return 'La password è troppo debole (minimo 6 caratteri).';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      case 'network-request-failed':
        return 'Errore di rete. Controlla la connessione e riprova.';
      default:
        return e.message ?? 'Si è verificato un errore. Riprova.';
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      AnalyticsService.logLogin();
      // Rimosso Navigator.pushReplacement.
      // main.dart rileverà il cambio di stato dell'autenticazione
      // e reindirizzerà automaticamente a BottomNavShell.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        // Aspettato prima che main.dart reindirizzi a BottomNavShell, così
        // il nome è già disponibile al primo build della Home (altrimenti
        // "Ciao Alessandro!" fisso per tutti diventerebbe solo "Ciao!" fisso
        // per tutti fino al prossimo riavvio).
        await credential.user?.updateDisplayName(name);
        await credential.user?.reload();
      }
      AnalyticsService.logSignUp();
      // Rimosso Navigator.pushReplacement.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Inserisci la tua email qui sopra, poi tocca '
          '"Password dimenticata?".');
      return;
    }
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ti abbiamo inviato un\'email a $email per reimpostare la '
              'password.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static InputDecoration _fieldDecoration({required String labelText}) {
    return InputDecoration(
      labelText: labelText,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Spesa Intelligente',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: _fieldDecoration(labelText: 'Nome (per il nuovo account)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _fieldDecoration(labelText: 'Password'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neutral,
                  ),
                  child: const Text(
                    'Password dimenticata?',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Accedi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _signUp,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('Crea account'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
