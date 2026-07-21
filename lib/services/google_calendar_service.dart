import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_auth_service.dart';

/// Fehler beim Abruf der Google Calendar API.
class GoogleCalendarException implements Exception {
  final String message;
  const GoogleCalendarException(this.message);

  @override
  String toString() => message;
}

/// Ein Eintrag aus `calendarList.list` — nur, was Teil 2 braucht.
class RemoteCalendar {
  final String id;
  final String summary;
  const RemoteCalendar({required this.id, required this.summary});
}

/// Dünner REST-Client für die Google Calendar API.
///
/// Teil 2 nutzt ausschließlich `calendarList.list`. Bewusst roh über `http`
/// gehalten (kein `googleapis`) — die Paket-Entscheidung für die Sync-Engine
/// fällt in Session B und berührt diese Klasse höchstens intern.
class GoogleCalendarService {
  GoogleCalendarService(this._auth);

  final GoogleAuthService _auth;

  static const _calendarListUrl =
      'https://www.googleapis.com/calendar/v3/users/me/calendarList';

  /// Holt die Kalenderliste des verbundenen Kontos. Nutzt den stillen
  /// Token-Refresh von [GoogleAuthService] (wirft [GoogleAuthException],
  /// wenn kein Konto verbunden ist). `summaryOverride` (falls der Nutzer den
  /// Kalender umbenannt hat) gewinnt vor `summary`.
  Future<List<RemoteCalendar>> fetchCalendarList() async {
    final token = await _auth.accessToken();
    final resp = await http.get(
      Uri.parse(_calendarListUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      throw GoogleCalendarException(
        'Kalenderliste fehlgeschlagen (HTTP ${resp.statusCode}).',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
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
}
