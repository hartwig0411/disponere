import 'package:flutter/material.dart';

/// Zentrale Farb- und Theme-Quelle (helles Theme, Design v1.0).
///
/// Einzige Stelle, an der die Farbwerte der App stehen. Die Tabelle folgt
/// `docs/disponere_design_v1_0.md` §2. Ein Dunkelmodus ist fuer v1.0 nicht
/// geplant — deshalb reichen feste Konstanten plus ein Light-`ThemeData`,
/// keine Doppel-Theme-Mechanik.
class AppColors {
  AppColors._();

  // --- Flaechen & Kanten ---
  /// Seitenhintergrund (Papier).
  static const Color paper = Color(0xFFFCFCFA);

  /// Rahmen / Screen-Kante.
  static const Color border = Color(0xFFE7E6E1);

  /// Haarfeiner Trenner zwischen Tagen / leichte Kanten.
  static const Color hairline = Color(0xFFECEBE4);

  /// Fuehrungslinie (Verschachtelung).
  static const Color guide = Color(0xFFECEBE4);

  // --- Text & Tinte ---
  /// Datum (gross).
  static const Color dateLarge = Color(0xFF1C1D22);

  /// Wochentag (klein, ueber dem Datum).
  static const Color weekday = Color(0xFFA6A69E);

  /// Getippter Text / Tinte allgemein.
  static const Color text = Color(0xFF24252A);

  /// Handschriftlicher Eintrag (Tinte) — ein Hauch Blau-Schwarz.
  static const Color ink = Color(0xFF2A2B48);

  /// Platzhalter im Leerzustand.
  static const Color placeholder = Color(0xFFB4B4AA);

  // --- Akzent ---
  /// Akzentblau: Tags, Cursor, Kalender-Icon, Aufgaben-Haekchen, aktives Icon.
  static const Color accent = Color(0xFF185FA5);

  // --- Tagesinfo-Band ---
  /// Tagesinfo-Band (Flaeche).
  static const Color dailyInfoBand = Color(0xFFF4F3EC);

  /// Tagesinfo-Text.
  static const Color dailyInfoText = Color(0xFF5E5E57);

  // --- Aufgaben ---
  /// Aufgabe offen (Kaestchen-Rahmen).
  static const Color taskOpenBox = Color(0xFFB7C6D6);

  /// Erledigter Aufgabentext (durchgestrichen).
  static const Color taskDoneText = Color(0xFFA6A69E);

  // --- Bullet & Icon-Leiste ---
  /// Bullet-Punkt.
  static const Color bullet = Color(0xFFC4C3BA);

  /// Icon-Leiste inaktiv.
  static const Color iconInactive = Color(0xFF8A8A83);

  /// Icon-Leiste aktiv.
  static const Color iconActive = Color(0xFF24252A);

  // --- Abgeleitete Toene ---
  // Nicht in der Design-Tabelle, aber fuer die Umsetzung noetig; ruhig aus dem
  // Akzent bzw. den Bandtoenen abgeleitet.

  /// Fuellung heller Eingabefelder (Sheets, Datumszeilen).
  static const Color fieldFill = Color(0xFFF1F0EA);

  /// Sehr helle Akzenttoenung fuer Tag-Chips.
  static const Color tagChipBg = Color(0xFFEAF1F8);

  /// Zurueckhaltendes Rot fuer Zerstoerendes / Ueberfaelliges.
  static const Color danger = Color(0xFFB3403A);

  /// Baut das helle App-Theme. Setzt die Grundflaechen und den Akzent; die
  /// Feinfarben pro Widget kommen aus den Konstanten oben.
  static ThemeData buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: accent,
      surface: paper,
      onSurface: text,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: dateLarge,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: hairline,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: tagChipBg,
        selectionHandleColor: accent,
      ),
      splashColor: tagChipBg,
      highlightColor: Colors.transparent,
    );
  }
}
