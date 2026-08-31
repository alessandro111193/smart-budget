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

  /// Chiede all'AI una proposta di distribuzione di una nuova entrata tra
  /// le buste esistenti. Restituisce solo un suggerimento: il chiamante
  /// deve sempre mostrarlo con un'azione esplicita di conferma prima di
  /// applicarlo, mai applicarlo da solo.
  Future<IncomeDistributionSuggestion> suggestIncomeDistribution({
    required double incomeAmount,
    required List<({String id, String name})> envelopes,
    required String summary,
  }) async {
    final callable = _functions.httpsCallable('suggestIncomeDistribution');
    try {
      final result = await callable.call({
        'incomeAmount': incomeAmount,
        'envelopes': envelopes
            .map((e) => {'id': e.id, 'name': e.name})
            .toList(),
        'summary': summary,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final allocazioni = List<Map<String, dynamic>>.from(
        data['allocazioni'] ?? [],
      );
      return IncomeDistributionSuggestion(
        motivazione: data['motivazione'] as String? ?? '',
        allocations: {
          for (final a in allocazioni)
            a['envelopeId'] as String: (a['importo'] as num).toDouble(),
        },
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception(
          'Hai raggiunto il limite di analisi AI del trial.',
        );
      }
      if (e.code == 'permission-denied') {
        throw Exception('Questa funzione richiede Premium.');
      }
      throw Exception(
        'Errore nel calcolo della distribuzione consigliata: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Errore imprevisto durante il calcolo della distribuzione.',
      );
    }
  }

  /// Genera un insight AI. Per "daily_tip"/"monthly_report" non serve
  /// passare [summary]: la Cloud Function aggrega i dati da Firestore e
  /// restituisce dalla cache se ancora valida per oggi/questo mese. Per
  /// "habit_analysis" [summary] è obbligatorio (riepilogo già compatto
  /// costruito lato client, es. con HabitInsights.buildSummary).
  Future<Map<String, dynamic>> generateInsight({
    required String kind,
    String? summary,
  }) async {
    final callable = _functions.httpsCallable('generateAiInsight');
    try {
      final payload = <String, dynamic>{'kind': kind};
      if (summary != null) payload['summary'] = summary;
      final result = await callable.call(payload);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception('Hai raggiunto il limite di analisi AI del trial.');
      }
      if (e.code == 'permission-denied') {
        throw Exception('Questa funzione richiede Premium.');
      }
      throw Exception('Errore nella generazione dell\'insight: ${e.message}');
    } catch (e) {
      throw Exception('Errore imprevisto durante la generazione.');
    }
  }

  /// Chiede all'AI una lista della spesa che rispetti un budget, basata
  /// sui prodotti abituali dell'utente. Restituisce solo un suggerimento:
  /// il chiamante deve sempre farlo confermare esplicitamente prima di
  /// aggiungere gli articoli alla lista della spesa vera.
  Future<ShoppingListSuggestion> suggestShoppingList({
    required double budget,
    required String summary,
  }) async {
    final callable = _functions.httpsCallable('suggestShoppingList');
    try {
      final result = await callable.call({
        'budget': budget,
        'summary': summary,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final articoli = List<Map<String, dynamic>>.from(
        data['articoli'] ?? [],
      );
      return ShoppingListSuggestion(
        motivazione: data['motivazione'] as String? ?? '',
        totaleStimato: (data['totaleStimato'] as num?)?.toDouble() ?? 0,
        items: [
          for (final a in articoli)
            (
              nome: a['nome'] as String,
              prezzoStimato: (a['prezzoStimato'] as num).toDouble(),
            ),
        ],
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception('Hai raggiunto il limite di analisi AI del trial.');
      }
      if (e.code == 'permission-denied') {
        throw Exception('Questa funzione richiede Premium.');
      }
      throw Exception(
        'Errore nel calcolo della lista della spesa: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Errore imprevisto durante il calcolo della lista della spesa.',
      );
    }
  }
}

/// Risultato di [AiService.suggestIncomeDistribution]: quanto assegnare a
/// ciascuna busta (per envelopeId) e la motivazione in una frase.
class IncomeDistributionSuggestion {
  final String motivazione;
  final Map<String, double> allocations;

  IncomeDistributionSuggestion({
    required this.motivazione,
    required this.allocations,
  });
}

/// Risultato di [AiService.suggestShoppingList].
class ShoppingListSuggestion {
  final String motivazione;
  final double totaleStimato;
  final List<({String nome, double prezzoStimato})> items;

  ShoppingListSuggestion({
    required this.motivazione,
    required this.totaleStimato,
    required this.items,
  });
}
