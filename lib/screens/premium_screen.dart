import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../services/billing_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_icons.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _service = FirestoreService();
  final _billing = BillingService();

  ProductDetails? _premiumProduct;
  bool _billingAvailable = false;
  bool _purchaseInProgress = false;
  bool _restoreInProgress = false;

  @override
  void initState() {
    super.initState();
    _billing.listen(onResult: _onPurchaseResult);
    _initBilling();
    _reverifyIfNeeded();
  }

  Future<void> _initBilling() async {
    final available = await _billing.isAvailable();
    if (!available) return;
    final product = await _billing.loadPremiumProduct();
    if (!mounted) return;
    setState(() {
      _billingAvailable = true;
      _premiumProduct = product;
    });
  }

  /// Ricontrollo dello stato abbonamento ad ogni apertura di questa
  /// schermata: se l'utente risulta già Premium con un token Google Play
  /// salvato, lo riverifica presso Play invece di fidarsi solo dell'ultimo
  /// stato scritto (che potrebbe non riflettere una cancellazione/scadenza
  /// nel frattempo — vedi commento su BillingService.reverifyStoredSubscription).
  /// Il trial simulato non è coinvolto: non ha nulla da riverificare presso
  /// uno store.
  Future<void> _reverifyIfNeeded() async {
    final user = await _service.streamUser().first;
    if (!mounted || !user.isPremium) return;
    final token = user.playPurchaseToken;
    final productId = user.playProductId;
    if (token == null || productId == null) return;
    await _billing.reverifyStoredSubscription(
      purchaseToken: token,
      productId: productId,
    );
    // Non serve gestire il risultato qui: verifyPlayPurchase scrive già lo
    // stato aggiornato su Firestore, e streamUser() lo riflette da solo.
  }

  void _onPurchaseResult(PurchaseUpdateResult result) {
    if (!mounted) return;
    setState(() {
      _purchaseInProgress = false;
      _restoreInProgress = false;
    });
    final message = switch (result) {
      PurchaseUpdateResult.verifiedPremium =>
        'Abbonamento attivato, benvenuto in Premium!',
      PurchaseUpdateResult.notActive =>
        'L\'acquisto non risulta attivo su Google Play.',
      PurchaseUpdateResult.error =>
        'Non è stato possibile verificare l\'acquisto. Riprova.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _buyPremium() async {
    final product = _premiumProduct;
    if (product == null) return;
    setState(() => _purchaseInProgress = true);
    try {
      await _billing.buyPremium(product);
    } catch (_) {
      if (mounted) setState(() => _purchaseInProgress = false);
    }
  }

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: StreamBuilder<AppUser>(
        stream: _service.streamUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const AppIcon(
                        HeroIcons.star,
                        solid: true,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sblocca tutto il potenziale dell\'app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._features().map(
                      (f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const AppIcon(
                              HeroIcons.checkCircle,
                              solid: true,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              f,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _statusArea(context, user),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _features() => const [
    'AI Assistant avanzato',
    'Scanner scontrino',
    'Analisi approfondite',
    'Budget illimitati',
    'Nessuna pubblicità',
  ];

  Widget _statusArea(BuildContext context, AppUser? user) {
    if (user != null && user.isPremium) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Sei già Premium 🎉',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (user != null && user.isTrialActive) {
      final daysLeft = user.trialEnd!.difference(DateTime.now()).inDays;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trial attivo — $daysLeft giorni rimasti',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Scontrini: ${user.scontriniUsati}/${AppUser.trialMaxScontrini}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
            Text(
              'Richieste AI: ${user.richiesteAiUsate}/${AppUser.trialMaxRichiesteAi}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _service.startTrial(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Prova gratis 15 giorni',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _premiumProduct != null
              ? '${_premiumProduct!.price} / mese dopo il trial'
              : '€2,99 / mese dopo il trial',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (_billingAvailable && _premiumProduct != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _purchaseInProgress ? null : _buyPremium,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _purchaseInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Abbonati subito su Google Play'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _restoreInProgress ? null : _restorePurchases,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: _restoreInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Ripristina acquisti'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _restorePurchases() async {
    setState(() => _restoreInProgress = true);
    try {
      await _billing.restorePurchases();
    } catch (_) {
      // L'esito arriva comunque tramite _onPurchaseResult se lo store
      // trova qualcosa; qui intercettiamo solo un eventuale errore
      // nell'avvio della richiesta stessa.
    } finally {
      // _onPurchaseResult azzera già _purchaseInProgress sugli eventi
      // reali; questo timeout evita che il bottone resti bloccato in
      // caricamento se Play non trova nulla da ripristinare (nessun
      // evento arriva affatto in quel caso).
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _restoreInProgress = false);
      });
    }
  }
}
