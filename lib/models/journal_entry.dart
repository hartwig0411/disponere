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
}