/// Daily Info — menschlicher Kontext für einen Tag oder eine Zeitspanne.
///
/// Bewusst **kein** [JournalEntry] (Session 15): eine Daily Info hat eine
/// Zeitspanne (Start, optional Ende) statt eines Zeitpunkts und erscheint
/// automatisch im Journal **aller betroffenen Tage**. Sie ist klar getrennt
/// von Einträgen, Aufgaben und Kalenderterminen (Anforderung v3.0).
///
/// Daten werden als reine Kalendertage geführt (ohne Uhrzeit); persistiert
/// wird als `yyyy-MM-dd`-String (siehe JournalRepository).
class DailyInfo {
  final String id;
  final String text;

  /// Erster betroffener Tag (auf Mitternacht normalisiert gedacht).
  final DateTime startDate;

  /// Letzter betroffener Tag. `null` → Einzeltag (nur [startDate]).
  final DateTime? endDate;

  DailyInfo({
    required this.id,
    required this.text,
    required this.startDate,
    this.endDate,
  });

  /// True, wenn die Info eine Zeitspanne (von/bis) abdeckt statt eines Tages.
  bool get isRange => endDate != null;

  /// Normalisiert [d] auf den reinen Kalendertag (ohne Uhrzeit).
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Deckt diese Info den gegebenen Tag ab?
  bool coversDay(DateTime day) {
    final d = dayOnly(day);
    final start = dayOnly(startDate);
    final end = dayOnly(endDate ?? startDate);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// Kopie mit geänderten Feldern. [clearEndDate] setzt eine Zeitspanne
  /// zurück auf einen Einzeltag (da `endDate: null` via copyWith sonst nicht
  /// von „nicht ändern" unterscheidbar wäre).
  DailyInfo copyWith({
    String? id,
    String? text,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return DailyInfo(
      id: id ?? this.id,
      text: text ?? this.text,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}
