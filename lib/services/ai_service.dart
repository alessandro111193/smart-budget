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
}
