/// Woher ein Suchtreffer stammt.
///
/// Die Unterscheidung ist kein Schmuck: Ein Fund in [content] steht in dem,
/// was Steffen selbst geschrieben hat — ein Fund in [inkText] steht in dem,
/// was die Maschine aus seiner Handschrift geraten hat. Wer das nicht
/// auseinanderhalten kann, weiß bei einem Treffer nicht, wie sehr er ihm
/// trauen darf.
enum SearchHitSource {
  /// Getroffen in `entries.content` — vom Nutzer geschriebener Text.
  content,

  /// Getroffen in `entries.ink_text` — von Claude erkannter Text (Schema v6).
  inkText,
}

/// Ein Suchtreffer: ein Eintrag, in dem der Suchbegriff vorkommt.
///
/// Bewusst **kein** `JournalEntry`: Die Suche lädt nur vier Spalten und nie
/// die Tinte. Ein `JournalEntry` mit leerem `ink`-Feld wäre eine Lüge über
/// den geladenen Zustand — er sähe aus wie ein Text-Eintrag. Zum Öffnen
/// genügt die [entryId]; den vollständigen Eintrag hat das Journal ohnehin
/// schon in der Hand.
class SearchHit {
  /// Id des getroffenen Eintrags — der Rückgabewert des Such-Screens.
  final String entryId;

  /// Zeitstempel des Eintrags (Sortierung und Anzeige).
  final DateTime timestamp;

  /// In welchem Feld der Begriff gefunden wurde.
  final SearchHitSource source;

  /// Textausschnitt um die Fundstelle, Zeilenumbrüche zu Leerzeichen
  /// zusammengezogen. Ohne Hervorhebung des Begriffs (Architektur §9) —
  /// der Ausschnitt zeigt nur den Zusammenhang.
  final String snippet;

  /// True, wenn der Eintrag ein Tinten-Eintrag ist. Rein für die Anzeige;
  /// ein Treffer in einem Tinten-Eintrag stammt immer aus [inkText], aber
  /// nicht jeder Tinten-Eintrag ist ausgewertet.
  final bool isInk;

  const SearchHit({
    required this.entryId,
    required this.timestamp,
    required this.source,
    required this.snippet,
    required this.isInk,
  });

  /// True, wenn der Treffer aus einer Maschinenerkennung stammt.
  bool get fromInkText => source == SearchHitSource.inkText;
}
