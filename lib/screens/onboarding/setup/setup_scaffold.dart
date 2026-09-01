import 'package:flutter/material.dart';

import '../../../theme/icon_palette.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Chrome condiviso dai passaggi del wizard di configurazione reale:
/// titolo, contenuto scorrevole, bottone primario in basso e un link
/// secondario opzionale (es. "Salta questo passaggio").
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
    this.loading = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IconPalette.sfondoAlt,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingHeader(title: title, subtitle: subtitle),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IconPalette.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            IconPalette.primary.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (primaryEnabled && !loading) ? onPrimary : null,
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              primaryLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (secondaryLabel != null)
                    TextButton(
                      onPressed: loading ? null : onSecondary,
                      style: TextButton.styleFrom(
                        foregroundColor: IconPalette.accent,
                      ),
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
