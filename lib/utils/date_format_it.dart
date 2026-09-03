const _mesiIt = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// Data in italiano senza dipendere dai dati di localizzazione di `intl`
/// (mai inizializzati in questo progetto, es. `initializeDateFormatting`) —
/// solo una tabella statica dei mesi, coerente con `flutter_localizations`
/// già configurato in main.dart per i widget Material (date/time picker).
String formatDateIt(DateTime date) =>
    '${date.day} ${_mesiIt[date.month - 1]} ${date.year}';

/// Come [formatDateIt] ma senza l'anno, per date sempre nell'anno corrente
/// (es. "si esaurirà intorno al 24 settembre").
String formatDayMonthIt(DateTime date) =>
    '${date.day} ${_mesiIt[date.month - 1]}';
