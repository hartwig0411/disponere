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
  ///
  /// **Sechs feste Überschriften, feste Reihenfolge, immer alle vorhanden.**
  /// Das ist kein Formalismus: Die Auswertung wird in `week_review_screen.dart`
  /// als reiner Text angezeigt (`SelectableText`) und landet danach als
  /// gewöhnlicher Journaleintrag — an beiden Stellen gibt es keinen
  /// Markdown-Renderer. Sternchen und Rauten wären dort sichtbare Zeichen,
  /// keine Auszeichnung. Zugleich hält der feste Satz an Überschriften die Tür
  /// für eine spätere Baum- oder Mindmap-Darstellung offen: Sie wäre dann
  /// reine Anzeige auf vorhandenem Text, kein Umbau.
  ///
  /// Zwei Abschnitte sind gegenüber der ersten Fassung neu und stammen aus
  /// einem Beispieldokument, das Steffen als Vorbild gegeben hat: die
  /// abhakbare **Aufgabenliste** (statt Prosa über Liegengebliebenes) und die
  /// **nummerierten Vorschläge** (statt eines Absatzes „Für die kommende
  /// Woche"). Beides macht den Teil greifbar, den man nach dem Lesen
  /// tatsächlich anfasst.
  static const String weekReview = '''
Es folgt die Aufzeichnung einer Kalenderwoche aus einem persönlichen Journal:
Tagesinfos, Kalendertermine, Aufgaben und Journaleinträge, nach Tagen
gegliedert. `#`-Wörter sind Tags — sie zeigen, worauf die Woche verteilt war,
und sind die eigentliche Struktur des Materials.

Schreibe daraus eine Wochenauswertung auf Deutsch.

Verwende genau diese sechs Überschriften, in genau dieser Reihenfolge, jede
auf einer eigenen Zeile und ohne jede Auszeichnung:

Überblick
Was vorangekommen ist
Woran es hakte
Beobachtungen
Aufgaben
Vorschläge

Was in die Abschnitte gehört:

Überblick — drei bis fünf Sätze: Was hat diese Woche geprägt?

Was vorangekommen ist — was abgeschlossen, entschieden oder spürbar
weitergebracht wurde. Nenne dabei die betroffenen Tags.

Woran es hakte — wo es klemmte: Angefangenes ohne Fortsetzung, mehrfach
verschobene Termine, Themen, die auftauchten und wieder verschwanden,
Aufgaben, die die Woche überdauert haben. Ist im Material erkennbar, woran es
lag, benenne es; ist es nicht erkennbar, beschreibe nur den Umstand und rate
nicht nach der Ursache.

Beobachtungen — was dir auffällt: Schwerpunkte, Ungleichgewichte,
wiederkehrende Themen, ein Tag der aus der Reihe fällt. Nur, wenn das Material
es hergibt.

Aufgaben — die Aufgaben, die im Material vorkommen: erledigte zuerst, dann die
offenen. Eine pro Zeile, in genau dieser Form:

[x] Eine erledigte Aufgabe
[ ] Eine offene Aufgabe

Übernimm den Wortlaut aus dem Material und kürze nur, wenn er sehr lang ist.
Erfinde keine Aufgaben und leite keine aus Fließtext ab, der keine ist.

Vorschläge — höchstens vier, nummeriert mit 1., 2. und so weiter. Jeder
Vorschlag ist eine benennbare Handlung, die sich aus dem Vorliegenden ergibt,
kein allgemeiner Ratschlag. Ergibt sich nichts Konkretes, schreib in einem
Satz, dass sich aus dieser Woche nichts Konkretes ableiten lässt.

Halte dich an diese Regeln:

- Stütze jede Aussage auf das, was dasteht. Ergänze nichts, was nicht im
  Material steht — auch nichts, was naheliegend wäre.
- Alle sechs Überschriften kommen immer vor, auch bei dünnem Material. Ist ein
  Abschnitt nicht zu füllen, schreib einen Satz, dass das Material dafür nichts
  hergibt, und lass es dabei. Fülle ihn nicht auf.
- Der Text wird als reiner Text angezeigt. Verwende deshalb keine
  Markdown-Auszeichnung: keine Sternchen, keine Rauten, keine Unterstriche,
  keine Bindestriche als Aufzählungszeichen. Ausgenommen sind allein die
  Kästchen der Aufgabenliste und die Nummern der Vorschläge.
- Trenne die Abschnitte durch eine Leerzeile.
- Schreib in ganzen Sätzen, sachlich und direkt. Kein Coaching-Ton, keine
  Ermutigung, keine Bewertung der Person.
- Beginne ohne Einleitung wie „Hier ist deine Auswertung" und ende ohne
  Nachbemerkung.
- Enthält das Material praktisch nichts, sag genau das in einem Satz — dann
  entfallen die Überschriften.
''';

  /// Minimaler Request für „Verbindung testen". Die Antwort interessiert
  /// nicht — nur, ob der Schlüssel akzeptiert wurde.
  static const String connectionTest =
      'Antworte mit genau einem Wort: OK';
}
