/// Ein aus Google Calendar gespiegelter Termin (Schema v5).
///
/// Bewusst **kein** `JournalEntry`: Termine haben eine eigene Identität
/// (Fremdschlüssel zum Kalender, Zeitspanne statt Zeitpunkt, von außen
/// gepflegt und lokal nicht editierbar). Sie erscheinen im Journal an jedem
/// Tag, den sie berühren — dieselbe Mechanik wie bei [DailyInfo].
///
/// Datums-Keys sind `yyyy-MM-dd`, Uhrzeiten `HH:mm` in **lokaler** Zeit.
/// Beides sortiert lexikographisch = chronologisch und ist damit direkt in
/// SQL-Bereichsabfragen vergleichbar.
///
/// [allDay] unterscheidet ganztägige Termine (Google liefert `start.date`)
/// von zeitgebundenen (`start.dateTime`). Bei ganztägigen sind [startTime]
/// und [endTime] `null`.
///
/// [endDay] ist **inklusiv** — anders als bei Google, wo `end.date` eines
/// ganztägigen Termins den Tag *nach* dem Ende bezeichnet. Die Umrechnung
/// passiert einmal beim Parsen, damit alle Abfragen danach geradeaus sind.
class CalendarEvent {
  /// Kalender, aus dem der Termin stammt. Zusammen mit [eventId] der
  /// Primärschlüssel — dieselbe Einladung kann in mehreren Kalendern liegen.
  final String calendarId;

  /// Google-Event-ID.
  final String eventId;

  /// Kalenderübergreifend stabile ID. Für die spätere Deduplizierung
  /// reserviert (derselbe Termin in zwei aktivierten Kalendern), in dieser
  /// Session nur gespeichert, nicht ausgewertet.
  final String? iCalUid;

  final String summary;
  final String? location;
  final bool allDay;

  /// Erster berührter Kalendertag, `yyyy-MM-dd`.
  final String startDay;

  /// Beginn als `HH:mm`, `null` bei ganztägigen Terminen.
  final String? startTime;

  /// Letzter berührter Kalendertag, `yyyy-MM-dd`, **inklusiv**.
  final String endDay;

  /// Ende als `HH:mm`, `null` bei ganztägigen Terminen.
  final String? endTime;

  /// Vom Kalender geerbte Tags. In `event_tags` materialisiert, damit die
  /// „alles zu einem Tag"-Abfrage über Einträge, Aufgaben und Termine
  /// dieselbe Form hat.
  final List<String> tags;

  const CalendarEvent({
    required this.calendarId,
    required this.eventId,
    required this.summary,
    required this.startDay,
    required this.endDay,
    this.iCalUid,
    this.location,
    this.allDay = false,
    this.startTime,
    this.endTime,
    this.tags = const <String>[],
  });

  /// Berührt der Termin diesen Kalendertag? [day] als `yyyy-MM-dd`.
  bool coversDay(String day) => startDay.compareTo(day) <= 0 && endDay.compareTo(day) >= 0;

  /// Erstreckt sich der Termin über mehr als einen Tag?
  bool get isMultiDay => startDay != endDay;

  /// Anzeigetext der Uhrzeit für einen bestimmten Tag — `null`, wenn an
  /// diesem Tag keine sinnvolle Uhrzeit anzuzeigen ist (ganztägig oder
  /// Mitteltag eines mehrtägigen Termins).
  String? timeLabelForDay(String day) {
    if (allDay) return null;
    final start = startTime;
    final end = endTime;
    if (!isMultiDay) {
      if (start == null) return null;
      return end == null ? start : '$start–$end';
    }
    if (day == startDay) return start == null ? null : 'ab $start';
    if (day == endDay) return end == null ? null : 'bis $end';
    return null;
  }

  CalendarEvent copyWith({List<String>? tags}) {
    return CalendarEvent(
      calendarId: calendarId,
      eventId: eventId,
      summary: summary,
      startDay: startDay,
      endDay: endDay,
      iCalUid: iCalUid,
      location: location,
      allDay: allDay,
      startTime: startTime,
      endTime: endTime,
      tags: tags ?? this.tags,
    );
  }
}
