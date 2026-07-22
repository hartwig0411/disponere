import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import 'google_auth_service.dart';

/// Fehler beim Abruf der Google Calendar API.
class GoogleCalendarException implements Exception {
  final String message;
  const GoogleCalendarException(this.message);

  @override
  String toString() => message;
}

/// Ein Eintrag aus `calendarList.list` — nur, was die Kalenderauswahl braucht.
class RemoteCalendar {
  final String id;
  final String summary;
  const RemoteCalendar({required this.id, required this.summary});
}

/// Dünner REST-Client für die Google Calendar API.
///
/// Bewusst roh über `http` gehalten (kein `googleapis`): Es werden genau zwei
/// Endpunkte gebraucht, und beide liefern flaches JSON.
///
/// **Zum Sync-Verfahren:** Google erlaubt bei einem inkrementellen Sync
/// (`syncToken`) keine Zeitfenster-Parameter — `timeMin`/`timeMax` zusammen
/// mit `syncToken` quittiert die API mit HTTP 400. Es gilt also entweder
/// Delta-Sync über den gesamten Kalender oder Vollabruf im Zeitfenster.
/// Disponere nimmt das **Zeitfenster** ([windowDaysBack]/[windowDaysAhead],
/// rollend ab dem Sync-Zeitpunkt) und ersetzt die Termine eines Kalenders
/// lokal vollständig. Löschungen und Verschiebungen ergeben sich damit von
/// selbst; es gibt keinen Token-Zustand, der ablaufen (410) und wieder
/// eingefangen werden müsste. Für einen persönlichen Kalender sind das
/// wenige hundert Einträge pro Abruf.
class GoogleCalendarService {
  GoogleCalendarService(this._auth);

  final GoogleAuthService _auth;

  static const _base = 'https://www.googleapis.com/calendar/v3';
  static const _calendarListUrl = '$_base/users/me/calendarList';

  /// Rollendes Fenster: so viele Tage zurück …
  static const windowDaysBack = 30;

  /// … und so viele Tage voraus wird gespiegelt.
  static const windowDaysAhead = 365;

  /// Seitengröße des Termin-Abrufs (API-Maximum ist 2500).
  static const _pageSize = 250;

  /// Notbremse gegen Endlosschleifen bei kaputter Paginierung.
  static const _maxPages = 40;

  /// Holt die Kalenderliste des verbundenen Kontos. Nutzt den stillen
  /// Token-Refresh von [GoogleAuthService] (wirft [GoogleAuthException],
  /// wenn kein Konto verbunden ist). `summaryOverride` (falls der Nutzer den
  /// Kalender umbenannt hat) gewinnt vor `summary`.
  Future<List<RemoteCalendar>> fetchCalendarList() async {
    final body = await _get(Uri.parse(_calendarListUrl), 'Kalenderliste');
    final items = (body['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    final result = <RemoteCalendar>[];
    for (final item in items) {
      final id = item['id'] as String?;
      if (id == null) continue;
      final summary = (item['summaryOverride'] as String?) ??
          (item['summary'] as String?) ??
          id;
      result.add(RemoteCalendar(id: id, summary: summary));
    }
    return result;
  }

  /// Spiegelt alle Termine eines Kalenders im rollenden Zeitfenster.
  ///
  /// `singleEvents=true` löst Serientermine in einzelne Vorkommen auf — die
  /// App muss dadurch keine Wiederholungsregeln auswerten. Abgesagte Termine
  /// werden übersprungen. [tags] werden an jeden Termin vererbt (die
  /// Kalender→Tag-Zuordnung aus den Einstellungen).
  ///
  /// [now] ist nur für Tests injizierbar; im Betrieb zählt die aktuelle Zeit.
  Future<List<CalendarEvent>> fetchEvents(
    String calendarId,
    List<String> tags, {
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final timeMin = anchor.subtract(const Duration(days: windowDaysBack));
    final timeMax = anchor.add(const Duration(days: windowDaysAhead));

    final events = <CalendarEvent>[];
    String? pageToken;
    var pages = 0;

    do {
      final params = <String, String>{
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'showDeleted': 'false',
        'maxResults': '$_pageSize',
        'timeMin': _rfc3339(timeMin),
        'timeMax': _rfc3339(timeMax),
        if (pageToken != null) 'pageToken': pageToken,
      };
      final uri = Uri.parse(
        '$_base/calendars/${Uri.encodeComponent(calendarId)}/events',
      ).replace(queryParameters: params);

      final body = await _get(uri, 'Termin-Abruf');
      final items = (body['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

      for (final item in items) {
        final event = _parseEvent(calendarId, item, tags);
        if (event != null) events.add(event);
      }

      pageToken = body['nextPageToken'] as String?;
      pages++;
    } while (pageToken != null && pages < _maxPages);

    return events;
  }

  // ---------------------------------------------------------------------------
  // Intern
  // ---------------------------------------------------------------------------

  /// GET mit Bearer-Token und einheitlicher Fehlerübersetzung. Der Body von
  /// Google enthält bei Fehlern eine brauchbare Beschreibung — die wandert in
  /// die Meldung, sonst steht man vor einer nackten Statusnummer.
  Future<Map<String, dynamic>> _get(Uri uri, String what) async {
    final token = await _auth.accessToken();
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw GoogleCalendarException(
        '$what fehlgeschlagen (HTTP ${resp.statusCode}). ${_errorDetail(resp.body)}',
      );
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static String _errorDetail(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Kein JSON — dann eben ohne Detail.
    }
    return '';
  }

  /// Übersetzt ein Google-Event in ein [CalendarEvent]. Gibt `null` zurück,
  /// wenn der Eintrag nicht verwertbar ist (abgesagt, ohne ID oder ohne
  /// Startangabe) — solche Zeilen kommen vor und dürfen den Sync nicht kippen.
  static CalendarEvent? _parseEvent(
    String calendarId,
    Map<String, dynamic> item,
    List<String> tags,
  ) {
    if (item['status'] == 'cancelled') return null;
    final eventId = item['id'] as String?;
    if (eventId == null) return null;

    final start = item['start'] as Map<String, dynamic>?;
    final end = item['end'] as Map<String, dynamic>?;
    if (start == null) return null;

    final startDate = start['date'] as String?;
    final startDateTime = start['dateTime'] as String?;
    final endDate = end?['date'] as String?;
    final endDateTime = end?['dateTime'] as String?;

    String startDay;
    String endDay;
    String? startTime;
    String? endTime;
    bool allDay;

    if (startDate != null) {
      // Ganztägig. Googles `end.date` ist **exklusiv** (der Tag nach dem
      // Ende) — hier einmal auf einen inklusiven Endtag umgerechnet, damit
      // alle Abfragen danach geradeaus laufen.
      allDay = true;
      startDay = startDate;
      endDay = endDate == null ? startDate : _dayBefore(endDate);
      if (endDay.compareTo(startDay) < 0) endDay = startDay;
    } else if (startDateTime != null) {
      allDay = false;
      final startLocal = DateTime.parse(startDateTime).toLocal();
      final endLocal = endDateTime != null
          ? DateTime.parse(endDateTime).toLocal()
          : startLocal;
      startDay = _dayKey(startLocal);
      startTime = _timeKey(startLocal);
      endDay = _dayKey(endLocal);
      endTime = _timeKey(endLocal);
      // Ein Termin, der exakt um Mitternacht endet, gehört noch zum Vortag —
      // sonst taucht er einen Tag zu lang im Journal auf.
      if (endDay != startDay &&
          endLocal.hour == 0 &&
          endLocal.minute == 0 &&
          endLocal.second == 0) {
        endDay = _dayKey(endLocal.subtract(const Duration(days: 1)));
        if (endDay.compareTo(startDay) < 0) endDay = startDay;
      }
    } else {
      return null;
    }

    final summary = (item['summary'] as String?)?.trim();
    final location = (item['location'] as String?)?.trim();

    return CalendarEvent(
      calendarId: calendarId,
      eventId: eventId,
      iCalUid: item['iCalUID'] as String?,
      summary: (summary == null || summary.isEmpty) ? '(ohne Titel)' : summary,
      location: (location == null || location.isEmpty) ? null : location,
      allDay: allDay,
      startDay: startDay,
      startTime: startTime,
      endDay: endDay,
      endTime: endTime,
      tags: tags,
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _dayKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${_two(dt.month)}-${_two(dt.day)}';

  static String _timeKey(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  /// Einen Tag zurück, ausgehend von einem `yyyy-MM-dd`-Schlüssel.
  static String _dayBefore(String day) {
    final parsed = DateTime.tryParse(day);
    if (parsed == null) return day;
    return _dayKey(parsed.subtract(const Duration(days: 1)));
  }

  /// RFC-3339 mit Zeitzonen-Offset — von der API für `timeMin`/`timeMax`
  /// verlangt. `toUtc()` erspart die Offset-Formatierung.
  static String _rfc3339(DateTime dt) =>
      '${dt.toUtc().toIso8601String().split('.').first}Z';
}
