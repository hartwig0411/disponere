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

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.content,
    this.tags = const [],
    this.ink,
    this.inkText,
    this.inkTextAt,
    this.attachments = const [],
  });

  /// True, wenn der Eintrag im Tinten-Modus vorliegt (Striche statt Text).
  bool get isInk => ink != null;

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
  JournalEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? content,
    List<String>? tags,
    InkData? ink,
    String? inkText,
    DateTime? inkTextAt,
    List<Attachment>? attachments,
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
    );
  }
}
