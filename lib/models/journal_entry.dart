import 'attachment.dart';
import 'ink_data.dart';

class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String content;
  final List<String> tags;

  /// Bild-Anhänge des Eintrags (Schema v7, Session A). Leere Liste = kein Bild.
  /// Das Modell trägt bewusst eine Liste (1:n), auch wenn die Oberfläche zurzeit
  /// nur ein Bild pro Eintrag zulässt — siehe [Attachment].
  final List<Attachment> attachments;

  /// Tinten-Körper. `null` → Text-Eintrag; gesetzt → Tinten-Eintrag.
  /// Ein Eintrag ist genau einer der beiden Modi (Session 10).
  final InkData? ink;

  /// Von Claude erkannter Text zu [ink] (Schema v6, Session 24).
  ///
  /// Bewusst **neben** [content] und nicht darin: [content] ist, was der
  /// Nutzer geschrieben hat — [inkText] ist, was die Maschine geraten hat.
  /// Diese Grenze zu verwischen wäre in einem Journal die falsche
  /// Sparsamkeit. `null` = nie ausgewertet.
  final String? inkText;

  /// Zeitpunkt der Auswertung. Gehört zu [inkText] und wird mit ihm gesetzt.
  final DateTime? inkTextAt;

  /// Optionaler **Anzeige-Tag** (Schema v8, „datierter Eintrag"). `null` → ein
  /// gewöhnlicher Eintrag, der an dem Tag lebt, an dem er entstanden ist
  /// ([timestamp]). Gesetzt → der Eintrag **surft am gewählten Tag auf** und
  /// nur dort: er wartet still bis dahin und erscheint dann im Journal dieses
  /// Tages (Anforderungen v6.2). Kein Abhaken, keine Checkbox — er ist keine
  /// Aufgabe, sondern ein vorbereiteter Inhalt (z.B. ein Rezept mit Bild für
  /// den Kochtag). Als **date-only** DateTime geführt (Mitternacht lokal); die
  /// Uhrzeit bleibt in [timestamp] (wann er notiert wurde).
  final DateTime? displayDay;

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.content,
    this.tags = const [],
    this.ink,
    this.inkText,
    this.inkTextAt,
    this.attachments = const [],
    this.displayDay,
  });

  /// True, wenn der Eintrag im Tinten-Modus vorliegt (Striche statt Text).
  bool get isInk => ink != null;

  /// True, wenn der Eintrag auf einen bestimmten Tag vorgemerkt ist.
  bool get isDated => displayDay != null;

  /// Der Kalendertag, an dem der Eintrag im Journal erscheint (date-only): der
  /// [displayDay], falls gesetzt (datierter Eintrag), sonst der Tag seines
  /// [timestamp]. **Der eine Ort, an dem die Tag-Zuordnung eines Eintrags
  /// entschieden wird** — Journal, vergangene Tage und Tag-Ansicht fragen alle
  /// hiernach, damit ein Eintrag überall an genau einem Tag liegt.
  DateTime get journalDay {
    final d = displayDay;
    if (d != null) return DateTime(d.year, d.month, d.day);
    return DateTime(timestamp.year, timestamp.month, timestamp.day);
  }

  /// True, wenn dem Eintrag mindestens ein Bild anhängt.
  bool get hasImage => attachments.isNotEmpty;

  /// True, wenn zu diesem Eintrag ein erkannter Text vorliegt.
  bool get hasInkText => inkText != null && inkText!.isNotEmpty;

  /// Erzeugt eine Kopie mit geänderten Feldern — Grundlage fürs Bearbeiten.
  /// id und timestamp bleiben standardmäßig erhalten: ein bearbeiteter
  /// Eintrag behält seinen Platz auf der Zeitachse.
  ///
  /// Hinweis: [ink] kann via copyWith nur gesetzt/aktualisiert, nicht auf
  /// `null` zurückgesetzt werden — ein Eintrag wechselt den Modus nicht.
  /// Für [inkText] gilt dasselbe: eine erneute Auswertung überschreibt, ein
  /// „Auswertung zurücknehmen" gibt es nicht.
  ///
  /// Der [displayDay] ist die Ausnahme: Er lässt sich sowohl setzen als auch
  /// **wieder entfernen** (aus einem datierten Eintrag wieder einen normalen
  /// machen) — dafür [clearDisplayDay]. Der übliche Fallstrick nullbarer
  /// copyWith-Felder: `displayDay: null` allein kann „nicht ändern" nicht von
  /// „löschen" unterscheiden, deshalb das ausdrückliche Flag.
  JournalEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? content,
    List<String>? tags,
    InkData? ink,
    String? inkText,
    DateTime? inkTextAt,
    List<Attachment>? attachments,
    DateTime? displayDay,
    bool clearDisplayDay = false,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      ink: ink ?? this.ink,
      inkText: inkText ?? this.inkText,
      inkTextAt: inkTextAt ?? this.inkTextAt,
      attachments: attachments ?? this.attachments,
      displayDay: clearDisplayDay ? null : (displayDay ?? this.displayDay),
    );
  }
}
