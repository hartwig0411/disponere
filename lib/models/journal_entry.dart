import 'ink_data.dart';

class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String content;
  final List<String> tags;

  /// Tinten-Körper. `null` → Text-Eintrag; gesetzt → Tinten-Eintrag.
  /// Ein Eintrag ist genau einer der beiden Modi (Session 10).
  final InkData? ink;

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.content,
    this.tags = const [],
    this.ink,
  });

  /// True, wenn der Eintrag im Tinten-Modus vorliegt (Striche statt Text).
  bool get isInk => ink != null;

  /// Erzeugt eine Kopie mit geänderten Feldern — Grundlage fürs Bearbeiten.
  /// id und timestamp bleiben standardmäßig erhalten: ein bearbeiteter
  /// Eintrag behält seinen Platz auf der Zeitachse.
  ///
  /// Hinweis: [ink] kann via copyWith nur gesetzt/aktualisiert, nicht auf
  /// `null` zurückgesetzt werden — ein Eintrag wechselt den Modus nicht.
  JournalEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? content,
    List<String>? tags,
    InkData? ink,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      ink: ink ?? this.ink,
    );
  }
}