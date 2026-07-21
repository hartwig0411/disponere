/// Ein Google-Kalender als lokale Quelle für die Einblendung.
///
/// Gespiegelt aus `calendarList.list` und um lokalen Zustand angereichert:
/// [enabled] (wird der Kalender abgefragt und eingeblendet?) und [tags]
/// (die Kalender→Tag-Zuordnung, die später jeder Termin dieses Kalenders erbt).
/// [syncToken] ist für die Sync-Engine (Session B) reserviert und in Teil 2
/// stets `null`.
class CalendarSource {
  final String calendarId;
  final String displayName;
  final bool enabled;
  final List<String> tags;
  final String? syncToken;

  const CalendarSource({
    required this.calendarId,
    required this.displayName,
    this.enabled = false,
    this.tags = const <String>[],
    this.syncToken,
  });

  CalendarSource copyWith({
    String? displayName,
    bool? enabled,
    List<String>? tags,
    String? syncToken,
  }) {
    return CalendarSource(
      calendarId: calendarId,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      tags: tags ?? this.tags,
      syncToken: syncToken ?? this.syncToken,
    );
  }
}
