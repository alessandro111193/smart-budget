import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';

/// ID del prodotto abbonamento in Google Play Console.
///
/// TODO(play-console): sostituire con l'ID reale del prodotto subscription
/// creato in Play Console > Monetizzazione > Prodotti in-app > Abbonamenti,
/// una volta che l'app avrà un applicationId definitivo e una scheda Play
/// Console. Finché resta questo placeholder, `loadPremiumProduct()`
/// restituirà sempre null (nessun prodotto trovato) e l'acquisto non sarà
/// possibile: è un comportamento voluto, non un bug.
const String premiumMonthlySubscriptionId = 'premium_monthly';

enum PurchaseUpdateResult { verifiedPremium, notActive, error }

/// Integrazione con Google Play Billing (abbonamento Premium reale).
///
/// Sostituisce, solo per l'attivazione di un abbonamento pagato vero, il
/// trial simulato via Firestore (`FirestoreService.startTrial`), che resta
/// invariato come percorso di sviluppo/test in emulatore: vedi
/// `premium_screen.dart` per come i due percorsi convivono.
///
/// Importante: questo servizio non imposta MAI `isPremium` lato client.
/// Comunica solo con lo store; è la Cloud Function `verifyPlayPurchase` a
/// verificare l'acquisto presso Google Play e a scrivere lo stato Premium
/// sul documento utente, secondo la regola del progetto "limiti/accessi
/// Premium verificati sempre lato server".
class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _functions = FirebaseFunctions.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return _iap.isAvailable();
  }

  /// Avvia l'ascolto degli aggiornamenti di acquisto. Va chiamato una sola
  /// volta (es. in `initState` della schermata Premium) e la subscription va
  /// chiusa con [dispose]. [onResult] viene invocato per ogni acquisto
  /// completato o fallito, dopo la verifica server-side.
  ///
  /// No-op su Web: `in_app_purchase` non registra nessuna implementazione
  /// della piattaforma lì, quindi anche solo leggere `purchaseStream` senza
  /// questo guard lancia un `LateInitializationError` (visto risolvendo un
  /// crash reale: si presentava aprendo Scanner scontrino o AI Chat da
  /// utente Free, perché entrambi rimandano a `PremiumScreen` quando manca
  /// l'accesso, e il suo `initState` chiamava `listen()` incondizionatamente).
  void listen({required void Function(PurchaseUpdateResult) onResult}) {
    if (kIsWeb) return;
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      (purchases) => _handlePurchaseUpdates(purchases, onResult),
      onError: (_) => onResult(PurchaseUpdateResult.error),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<ProductDetails?> loadPremiumProduct() async {
    final response = await _iap.queryProductDetails(
      {premiumMonthlySubscriptionId},
    );
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }
    return response.productDetails.first;
  }

  Future<void> buyPremium(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    void Function(PurchaseUpdateResult) onResult,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        onResult(PurchaseUpdateResult.error);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final result = await _verifyWithServer(purchase);
        onResult(result);
        // Conferma l'acquisto solo dopo la verifica server-side: se la
        // verifica fallisce, l'acquisto resta "pending" agli occhi di Play
        // e verrà ripresentato al prossimo avvio invece di sparire.
        if (result == PurchaseUpdateResult.verifiedPremium &&
            purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<PurchaseUpdateResult> _verifyWithServer(
    PurchaseDetails purchase,
  ) async {
    try {
      final callable = _functions.httpsCallable('verifyPlayPurchase');
      final result = await callable.call({
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'productId': purchase.productID,
      });
      final isPremium = result.data['isPremium'] == true;
      return isPremium
          ? PurchaseUpdateResult.verifiedPremium
          : PurchaseUpdateResult.notActive;
    } on FirebaseFunctionsException {
      return PurchaseUpdateResult.error;
    } catch (_) {
      return PurchaseUpdateResult.error;
    }
  }
}
