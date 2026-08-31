import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  final _functions = FirebaseFunctions.instance;

  Future<String> askAssistant(String question, String spendingSummary) async {
    final callable = _functions.httpsCallable('chatWithAssistant');
    try {
      final result = await callable.call({
        'question': question,
        'spendingSummary': spendingSummary,
      });
      return result.data['answer'] as String;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return 'Hai raggiunto il limite di richieste AI del trial.';
      }
      if (e.code == 'permission-denied') {
        return 'Questa funzione richiede Premium.';
      }
      return 'Si è verificato un errore, riprova.';
    }
  }

  /// Scansiona una foto dello scontrino e/o dei prodotti fisici e restituisce
  /// i dati estratti in una Map<String, dynamic>. Fornire almeno una delle
  /// due immagini; se sono presenti entrambe, la Cloud Function tenta di
  /// abbinare ogni prodotto fotografato al prezzo letto dallo scontrino.
  Future<Map<String, dynamic>> scanReceipt({
    Uint8List? receiptImageBytes,
    Uint8List? productsImageBytes,
    List<String> envelopeNames = const [],
  }) async {
    assert(
      receiptImageBytes != null || productsImageBytes != null,
      'Fornisci almeno una foto: scontrino o prodotti.',
    );
    final callable = _functions.httpsCallable('scanReceipt');
    try {
      final payload = <String, dynamic>{'envelopeNames': envelopeNames};
      if (receiptImageBytes != null) {
        payload['receiptImageBase64'] = base64Encode(receiptImageBytes);
      }
      if (productsImageBytes != null) {
        payload['productsImageBase64'] = base64Encode(productsImageBytes);
      }
      final result = await callable.call(payload);

      final data = Map<String, dynamic>.from(result.data as Map);
      return data;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception(
          'Hai raggiunto il limite di scansione scontrini del trial.',
        );
      }
      if (e.code == 'permission-denied') {
        throw Exception('Questa funzione richiede Premium.');
      }
      throw Exception('Errore nella scansione dello scontrino: ${e.message}');
    } catch (e) {
      throw Exception(
        'Errore imprevisto durante l\'elaborazione dell\'immagine.',
      );
    }
  }
}
