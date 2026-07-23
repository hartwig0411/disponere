/// Die Prompts der Claude-Anbindung — bewusst als Konstanten an einer Stelle,
/// damit sie sich ändern lassen, ohne die Logik anzufassen (Architektur §8).
///
/// Die Wochenauswertung kommt in Coding-Session C, Teil 2 dazu.
class ClaudePrompts {
  const ClaudePrompts._();

  /// Transkription eines handschriftlichen Eintrags.
  ///
  /// Die Vorgaben sind streng, weil das Ergebnis **unverändert** neben der
  /// Tinte gespeichert wird: keine Einleitung, keine Nachbemerkung, keine
  /// stille Verbesserung. Was dasteht, soll dastehen — auch wenn es
  /// verschrieben ist. Unleserliches wird als `[?]` markiert, statt geraten
  /// zu werden; ein sichtbares Loch ist ehrlicher als eine plausible
  /// Erfindung.
  static const String inkTranscription = '''
Das Bild zeigt eine handschriftliche Notiz, überwiegend auf Deutsch.

Übertrage die Handschrift in Text. Halte dich genau an diese Regeln:

- Gib ausschließlich den transkribierten Text zurück. Keine Einleitung, keine
  Erklärung, keine Nachbemerkung, keine Anführungszeichen um das Ganze.
- Übernimm den Wortlaut so, wie er dasteht. Korrigiere keine Rechtschreibung,
  keine Grammatik, keinen Stil.
- Erhalte die Zeilenumbrüche der Vorlage.
- Erhalte Aufzählungszeichen, Spiegelstriche, Nummerierungen und Einrückungen,
  soweit sie erkennbar sind.
- Markiere ein Wort, das du nicht sicher lesen kannst, mit [?]. Rate nicht.
- Wenn das Bild keine lesbare Handschrift enthält, gib genau zurück:
  [keine lesbare Handschrift]
''';

  /// Minimaler Request für „Verbindung testen". Die Antwort interessiert
  /// nicht — nur, ob der Schlüssel akzeptiert wurde.
  static const String connectionTest =
      'Antworte mit genau einem Wort: OK';
}
