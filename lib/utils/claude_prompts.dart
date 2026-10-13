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
  /// zweiter Textblock. Verdichtung ist erwünscht, die Grenze bleibt: Was
  /// nicht dasteht, wird nicht ergänzt.
  ///
  /// **Gliederung nach Tag, jede Information genau einmal** (Session 70).
  /// Die frühere Fassung mit sechs festen Abschnitten (Überblick, Was
  /// vorangekommen ist, Woran es hakte, Beobachtungen, Aufgaben, Vorschläge)
  /// ging jedes Thema in jedem Abschnitt erneut durch: dieselbe Checkliste
  /// stand vier Mal da, und „Beobachtungen“ und „Vorschläge“ zogen Deutungen
  /// nach sich, die im Material nicht standen. Jetzt: ein Block pro Tag mit
  /// Stand / Erledigt / Offen, Aufgaben im Block ihres Tags, keine eigene
  /// Aufgabenliste, keine Beobachtungen, keine Vorschläge.
  ///
  /// Der Text wird als reiner Text angezeigt (`SelectableText`) und landet
  /// als gewöhnlicher Journaleintrag — dort gibt es keinen Markdown-Renderer.
  /// Daher keine Auszeichnung; `#` nur als Teil eines Tag-Namens.
  ///
  /// Ein ausdrückliches „Thema erledigt“-Signal gibt es (noch) nicht: Ohne
  /// erledigte Aufgabe gilt ein Thema als offen und wird nicht kommentiert.
  /// Reicht das in der Praxis nicht, ist der nächste Schritt eine Markierung
  /// in der App, nicht ein schärferer Prompt.
  static const String weekReview = '''
Es folgt die Aufzeichnung einer Kalenderwoche aus einem persönlichen Journal:
Tagesinfos, Kalendertermine, Aufgaben und Journaleinträge, nach Tagen
gegliedert. Wörter mit # sind Tags. Sie stehen für Projekte und Themen und sind
die Gliederung der Auswertung. Aufgaben sind mit [erledigt] oder [offen]
markiert.

Schreibe daraus eine kurze, sachliche Wochenauswertung auf Deutsch.

Aufbau:

Erste Zeile: KW <Nummer> · <Montag als TT.MM.>–<letzter ausgewerteter Tag als
TT.MM.JJJJ>, genau wie im Material angegeben.

Danach ein Block pro Tag. Reihenfolge: der Tag mit den meisten Nennungen
zuerst (siehe „Tags dieser Woche“ im Material). Jeder Block beginnt mit dem Tag
selbst auf einer eigenen Zeile, zum Beispiel #Comos. Darunter höchstens diese
drei Zeilen, jede nur, wenn das Material sie hergibt:

Eine Zeile Stand: was diese Woche zu dem Tag passiert ist, in einem oder zwei
kurzen Sätzen, mit Wochentag, wenn er etwas klärt (zum Beispiel „Mi“ oder
„Neu am Fr“).
Erledigt: was abgeschlossen ist. Mehr als drei erledigte Aufgaben fasst du mit
Anzahl zusammen (zum Beispiel „7 von 10 Punkten der Checkliste“) statt sie
aufzuzählen.
Offen: jede offene Aufgabe einzeln, im Wortlaut aus dem Material, gekürzt nur
wenn sie sehr lang ist. Steht im Material, worauf sie wartet oder mit wem sie
zu klären ist, nenne das in Klammern.

Was zu keinem Tag gehört, kommt in einen Block „Ohne Tag“ ganz am Ende der
Tag-Blöcke. Trägt etwas mehrere Tags, steht es nur in einem Block — dort, wo es
inhaltlich hingehört.

Zum Schluss, nur wenn vorhanden, ein Block „Termine aus dem Material“: Termine
und Fristen nach dem Ende der Woche, die im Material ausdrücklich mit Datum
genannt sind, eine pro Zeile.

Regeln:

- Jede Information steht genau einmal. Keine Zusammenfassung vorweg, keine
  Wiederholung am Ende.
- Nur was dasteht. Keine Deutung, keine Ursachenvermutung, keine Bewertung,
  keine Ratschläge, keine Vorschläge, keine Aussagen über die Woche als Ganzes
  (welcher Tag am vollsten war, welches Thema dominierte, dass das Wochenende
  leer blieb).
- Hat ein Thema keine erledigte Aufgabe, gilt es als offen. Kommentiere das
  nicht („ohne dass eine Lösung dokumentiert ist“ und Ähnliches entfällt).
- Leere Tage werden nicht erwähnt.
- Kurze, vollständige Sätze oder knappe Aufzählungen mit Komma. Kein
  Coaching-Ton, keine Füllwörter.
- Reiner Text: keine Sternchen, keine Unterstriche, keine Rauten außer im
  Tag-Namen, keine Bindestriche als Aufzählungszeichen.
- Zwischen den Blöcken eine Leerzeile.
- Beginne ohne Einleitung und ende ohne Nachbemerkung.
- Enthält das Material praktisch nichts, schreib genau das in einem Satz.

Prüfe vor der Ausgabe jeden Satz gegen das Material: Steht das dort so? Ist es
schon an anderer Stelle gesagt? Enthält er ein wertendes Wort wie
„dominierend“, „geprägt“, „erfolgreich“, „leider“, „nur“, „noch immer“?
Streiche, was diese Prüfung nicht besteht.
''';

  /// Minimaler Request für „Verbindung testen". Die Antwort interessiert
  /// nicht — nur, ob der Schlüssel akzeptiert wurde.
  static const String connectionTest =
      'Antworte mit genau einem Wort: OK';
}
