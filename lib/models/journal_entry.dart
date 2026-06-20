class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String content;
  final List<String> tags;

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.content,
    this.tags = const [],
  });

  /// Erzeugt eine Kopie mit geänderten Feldern — Grundlage fürs Bearbeiten.
  /// id und timestamp bleiben standardmäßig erhalten: ein bearbeiteter
  /// Eintrag behält seinen Platz auf der Zeitachse.
  JournalEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? content,
    List<String>? tags,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      tags: tags ?? this.tags,
    );
  }
}