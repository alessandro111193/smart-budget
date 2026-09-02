import 'package:flutter/material.dart';

/// Tastiera numerica con supporto decimali, da usare in ogni campo dove
/// si digita un importo in euro (spesa, entrata, budget busta, ecc.) —
/// `TextInputType.number` da solo non garantisce il tasto virgola/punto
/// su tutte le tastiere.
const amountKeyboardType = TextInputType.numberWithOptions(decimal: true);

/// Converte il testo digitato in un importo, accettando sia la virgola
/// sia il punto come separatore decimale: in Italia si scrive "12,50",
/// ma `double.tryParse` di Dart si aspetta di default "12.50".
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
