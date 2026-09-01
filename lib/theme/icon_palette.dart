import 'package:flutter/material.dart';

/// Palette del nuovo sistema di icone, estratta dalla schermata di
/// riferimento che verrà usata per la Home definitiva (non ancora
/// sviluppata — vedi CLAUDE.md). Applicata solo alle nuove icone custom
/// (barra di navigazione, icone azione, icone categoria): il resto
/// dell'interfaccia (bottoni, AppBar, card) resta sul tema attuale
/// (`AppColors` in `lib/theme/app_theme.dart`) finché non verrà sviluppata
/// la nuova Home — a quel punto, aggiornare qui i valori aggiorna
/// automaticamente ogni icona dell'app, senza toccare le singole
/// schermate.
class IconPalette {
  static const primary = Color(0xFF00A58E);
  static const secondary = Color(0xFF008C8C);
  static const accent = Color(0xFF8C8C8C);
  static const testo = Color(0xFF1A1A1A);
  static const sfondo = Color(0xFFFFFFFF);
  static const sfondoAlt = Color(0xFFFCFCFC);

  // Colori "categoria": una base coerente riutilizzata su più categorie
  // affini, non un colore diverso per ognuna delle 26+ categorie.
  static const green = Color(0xFF16A34A);
  static const teal = Color(0xFF0D9488);
  static const blue = Color(0xFF2563EB);
  static const indigo = Color(0xFF6366F1);
  static const orange = Color(0xFFF59E0B);
  static const amber = Color(0xFFF7B733);
  static const purple = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const red = Color(0xFFEF4444);
  static const brown = Color(0xFF92400E);
  static const cyan = Color(0xFF06B6D4);
  static const emerald = Color(0xFF059669);
  static const gray = accent;
}
