/// Die Prompts der Claude-Anbindung — bewusst als Konstanten an einer Stelle,
/// damit sie sich ändern lassen, ohne die Logik anzufassen (Architektur §8).
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

  /// Auswertung einer Kalenderwoche.
  ///
  /// Der zusammengestellte Kontext (siehe `week_context.dart`) folgt als
  /// zweiter Textblock. Die Vorgaben sind weniger streng als bei der
  /// Transkription — hier ist Verdichtung erwünscht —, aber die Grenze ist
  /// dieselbe: Was nicht dasteht, wird nicht ergänzt. Eine Wochenauswertung,
  /// die plausibel klingt und erfunden ist, wäre schlimmer als keine.
  static const String weekReview = '''
Es folgt die Aufzeichnung einer Kalenderwoche aus einem persönlichen Journal:
Tagesinfos, Kalendertermine, Aufgaben und Journaleinträge, nach Tagen
gegliedert. `#`-Wörter sind Tags — sie zeigen, worauf die Woche verteilt war,
und sind die eigentliche Struktur des Materials.

Schreibe daraus eine Wochenauswertung auf Deutsch. Gliedere sie so:

**Überblick** — drei bis fünf Sätze: Was hat diese Woche geprägt?

**Was vorangekommen ist** — was abgeschlossen, entschieden oder spürbar
weitergebracht wurde. Nenne dabei die betroffenen Tags.

**Was liegen geblieben ist** — offene Aufgaben, Angefangenes ohne Fortsetzung,
Themen, die auftauchten und wieder verschwanden.

**Beobachtungen** — was dir auffällt: Schwerpunkte, Ungleichgewichte,
wiederkehrende Themen, ein Tag der aus der Reihe fällt. Nur, wenn das Material
es hergibt.

**Für die kommende Woche** — was sich aus dem Vorliegenden ergibt. Keine
allgemeinen Ratschläge.

Halte dich an diese Regeln:

- Stütze jede Aussage auf das, was dasteht. Ergänze nichts, was nicht im
  Material steht — auch nichts, was naheliegend wäre.
- Ist das Material für einen Abschnitt zu dünn, schreibe das in einem Satz und
  lass den Abschnitt kurz. Fülle ihn nicht auf.
- Schreib in ganzen Sätzen, sachlich und direkt. Kein Coaching-Ton, keine
  Ermutigung, keine Bewertung der Person.
- Beginne ohne Einleitung wie „Hier ist deine Auswertung" und ende ohne
  Nachbemerkung.
- Enthält das Material praktisch nichts, sag genau das in einem Satz.
''';

  /// Minimaler Request für „Verbindung testen". Die Antwort interessiert
  /// nicht — nur, ob der Schlüssel akzeptiert wurde.
  static const String connectionTest =
      'Antworte mit genau einem Wort: OK';
}
