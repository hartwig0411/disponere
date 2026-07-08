/// Aufgabe — etwas, das erledigt werden soll (Session 16).
///
/// Bewusst getrennt von [JournalEntry] und [DailyInfo]: eine Aufgabe hat einen
/// Erledigt-Zustand und einen **optionalen** Fälligkeits-Day (Anforderung
/// v3.0, §6). Sie erscheint automatisch im Journal des Days, an dem sie zählt
/// — und bleibt bei Überfälligkeit sichtbar, bis sie erledigt ist.
///
/// Tags sind zulässig und werden wie bei Einträgen kanonisiert: Grundlage für
/// die „alles zu einem Tag"-Ansicht (und später die Perlenkette), damit
/// Aufgaben in dieser Ansicht nicht fehlen.
///
/// Datum wird als reiner Kalender-Day geführt (ohne Uhrzeit); die optionale
/// Uhrzeit steht separat in [dueTime] als `HH:mm`. Persistiert wird als
/// `yyyy-MM-dd` / `HH:mm` (siehe JournalRepository).
class Task {
  final String id;
  final String title;

  /// Fälligkeits-Day (auf Mitternacht normalisiert gedacht). `null` → kein Day
  /// gesetzt: die Aufgabe ist offen und erscheint, bis sie erledigt ist.
  final DateTime? dueDay;

  /// Optionale Uhrzeit als `HH:mm`. Nur zusammen mit [dueDay] sinnvoll; dient
  /// Anzeige und Sortierung innerhalb eines Days.
  final String? dueTime;

  final bool done;

  final List<String> tags;

  Task({
    required this.id,
    required this.title,
    this.dueDay,
    this.dueTime,
    this.done = false,
    this.tags = const [],
  });

  /// Normalisiert [d] auf den reinen Kalender-Day (ohne Uhrzeit).
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// True, wenn die Aufgabe einen Fälligkeits-Day hat.
  bool get hasDay => dueDay != null;

  /// True, wenn die Aufgabe überfällig ist bezogen auf [today]: offener
  /// Status und ein Fälligkeits-Day *vor* dem heutigen Day.
  bool isOverdue(DateTime today) {
    final day = dueDay;
    if (done || day == null) return false;
    return dayOnly(day).isBefore(dayOnly(today));
  }

  /// Kopie mit geänderten Feldern. [clearDueDay] setzt den Fälligkeits-Day
  /// zurück auf „kein Day" (da `dueDay: null` via copyWith sonst nicht von
  /// „nicht ändern" unterscheidbar wäre); [clearDueTime] analog für die
  /// Uhrzeit.
  Task copyWith({
    String? id,
    String? title,
    DateTime? dueDay,
    String? dueTime,
    bool? done,
    List<String>? tags,
    bool clearDueDay = false,
    bool clearDueTime = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDay: clearDueDay ? null : (dueDay ?? this.dueDay),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      done: done ?? this.done,
      tags: tags ?? this.tags,
    );
  }
}
