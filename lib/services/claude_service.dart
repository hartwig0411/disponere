import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../utils/claude_prompts.dart';

/// Art des Fehlers — damit die UI mehr tun kann als eine Meldung anzeigen
/// (z.B. bei [noKey] und [auth] direkt in die Einstellungen führen).
enum ClaudeErrorKind {
  /// Kein Schlüssel hinterlegt.
  noKey,

  /// 401/403 — Schlüssel abgelehnt.
  auth,

  /// 429 — zu viele Anfragen.
  rateLimit,

  /// Kein Netz oder Zeitüberschreitung.
  network,

  /// 5xx oder ein anderer Statuscode.
  server,

  /// Antwort kam an, war aber unbrauchbar (leer, kein Text, kein JSON).
  response,
}

/// Fehler aus der Claude-Anbindung, in Klartext für die UI.
///
/// Enthält **nie** den Schlüssel — auch nicht in Auszügen (Architektur §10).
class ClaudeException implements Exception {
  final ClaudeErrorKind kind;
  final String message;

  const ClaudeException(this.kind, this.message);

  @override
  String toString() => message;
}

/// Direktaufruf der Anthropic Messages-API vom Gerät aus.
///
/// **Warum ohne Proxy:** Disponere ist eine Einzelnutzer-App; der Nutzer ist
/// der Eigentümer des Schlüssels und trägt seine eigenen Kosten. Die
/// verbreitete Warnung „niemals API-Schlüssel in Client-Apps" zielt auf
/// verteilte Apps, deren Aufrufe auf Kosten des Herausgebers laufen. Ein
/// Proxy würde hier einen Server einführen, den es nicht gibt und nicht geben
/// soll (Architektur §3 #2, §10).
///
/// Der Schlüssel liegt im Android-Keystore (`flutter_secure_storage`) — nicht
/// in SQLite, nicht in `shared_preferences`, nicht im Code. Das Repository
/// ist öffentlich.
class ClaudeService {
  /// Modell als **eine** Konstante. Nicht in den Einstellungen konfigurierbar:
  /// Handschrift ist die anspruchsvollere Aufgabe, und eine falsch getippte
  /// Modell-ID wäre nur ein 404 mit Umweg (Architektur §3 #3).
  ///
  /// Stand 23.07.2026 gegen die API-Dokumentation geprüft.
  static const String model = 'claude-sonnet-5';

  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';
  static const String _apiKeyKey = 'anthropic_api_key';

  /// Zeitlimit der Tinten-Auswertung (Architektur §7).
  static const Duration inkTimeout = Duration(seconds: 60);

  /// Zeitlimit des Verbindungstests — der schickt fast nichts und darf
  /// entsprechend schnell aufgeben.
  static const Duration testTimeout = Duration(seconds: 30);

  final FlutterSecureStorage _storage;

  ClaudeService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Schlüssel
  // ---------------------------------------------------------------------------

  /// Liegt ein Schlüssel im Keystore? Ohne Netz, ohne den Wert preiszugeben.
  Future<bool> hasKey() async {
    final key = await _storage.read(key: _apiKeyKey);
    return key != null && key.trim().isNotEmpty;
  }

  /// Legt den Schlüssel ab. Leerzeichen am Rand fallen weg — beim Einfügen aus
  /// der Zwischenablage hängt gern eines dran, und ein Schlüssel mit
  /// Leerzeichen scheitert später mit einer unverständlichen 401.
  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw const ClaudeException(
        ClaudeErrorKind.noKey,
        'Der Schlüssel ist leer.',
      );
    }
    await _storage.write(key: _apiKeyKey, value: trimmed);
  }

  /// Entfernt den Schlüssel aus dem Keystore.
  Future<void> deleteKey() => _storage.delete(key: _apiKeyKey);

  Future<String> _requireKey() async {
    final key = await _storage.read(key: _apiKeyKey);
    if (key == null || key.trim().isEmpty) {
      throw const ClaudeException(
        ClaudeErrorKind.noKey,
        'Kein API-Schlüssel hinterlegt.',
      );
    }
    return key.trim();
  }

  // ---------------------------------------------------------------------------
  // Aufrufe
  // ---------------------------------------------------------------------------

  /// Minimaler Request, nur um zu sehen, ob der Schlüssel akzeptiert wird.
  ///
  /// Die eigentliche Antwort ist gleichgültig. So scheitert die Einrichtung
  /// sichtbar in den Einstellungen und nicht erst beim ersten echten Aufruf
  /// (Architektur §10).
  Future<void> testConnection() async {
    await _send(
      content: [
        {'type': 'text', 'text': ClaudePrompts.connectionTest},
      ],
      maxTokens: 64,
      timeout: testTimeout,
      thinking: false,
      allowEmpty: true,
    );
  }

  /// Schickt ein gerendertes Tinten-PNG (base64) zur Transkription und gibt
  /// den erkannten Text zurück.
  ///
  /// Thinking ist hier **ausgeschaltet**: Handschrift lesen ist Wahrnehmung,
  /// keine Abwägung. Eingeschaltet kostete es Zeit und Token, ohne die
  /// Erkennung zu verbessern.
  Future<String> transcribeInk(String base64Png) {
    return _send(
      content: [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/png',
            'data': base64Png,
          },
        },
        {'type': 'text', 'text': ClaudePrompts.inkTranscription},
      ],
      maxTokens: 4096,
      timeout: inkTimeout,
      thinking: false,
    );
  }

  /// Ein Aufruf gegen `/v1/messages`.
  ///
  /// [allowEmpty] gilt nur für den Verbindungstest: dort zählt der Statuscode,
  /// nicht der Inhalt. Überall sonst ist eine leere Antwort ein Fehler und
  /// wird **nicht** als leeres Ergebnis gespeichert (Architektur §11).
  Future<String> _send({
    required List<Map<String, dynamic>> content,
    required int maxTokens,
    required Duration timeout,
    bool thinking = true,
    bool allowEmpty = false,
  }) async {
    final apiKey = await _requireKey();

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': [
        {'role': 'user', 'content': content},
      ],
    };
    // Sampling-Parameter (temperature, top_p, top_k) werden bewusst **nicht**
    // gesetzt: Das aktuelle Modell weist abweichende Werte mit 400 ab.
    if (!thinking) {
      body['thinking'] = {'type': 'disabled'};
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'anthropic-version': _apiVersion,
              'x-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw ClaudeException(
        ClaudeErrorKind.network,
        'Zeitüberschreitung nach ${timeout.inSeconds} Sekunden. '
        'Es wurde nichts gespeichert.',
      );
    } catch (_) {
      throw const ClaudeException(
        ClaudeErrorKind.network,
        'Keine Verbindung zu api.anthropic.com. '
        'Es wurde nichts gespeichert.',
      );
    }

    // Immer über die Bytes dekodieren: ohne `charset` im Content-Type legt
    // `http` sonst Latin-1 zugrunde — aus „Frühstück" würde Buchstabensalat.
    final raw = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode != 200) {
      throw ClaudeException(
        _kindForStatus(response.statusCode),
        _errorMessage(response.statusCode, raw),
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const ClaudeException(
        ClaudeErrorKind.response,
        'Unerwartete Antwort der API (kein gültiges JSON).',
      );
    }

    // Nur die Textblöcke einsammeln. Die Antwort kann weitere Blocktypen
    // enthalten (z.B. Thinking); die gehören nicht ins Journal.
    final blocks = decoded['content'];
    final buffer = StringBuffer();
    if (blocks is List) {
      for (final block in blocks) {
        if (block is Map && block['type'] == 'text') {
          final text = block['text'];
          if (text is String) buffer.write(text);
        }
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty && !allowEmpty) {
      throw const ClaudeException(
        ClaudeErrorKind.response,
        'Die Antwort enthielt keinen Text. Es wurde nichts gespeichert.',
      );
    }
    return text;
  }

  ClaudeErrorKind _kindForStatus(int status) {
    if (status == 401 || status == 403) return ClaudeErrorKind.auth;
    if (status == 429) return ClaudeErrorKind.rateLimit;
    return ClaudeErrorKind.server;
  }

  /// Baut eine lesbare Fehlermeldung aus Statuscode und API-Meldung.
  /// Der Request-Header — und damit der Schlüssel — taucht hier nie auf.
  String _errorMessage(int status, String raw) {
    String? apiMessage;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['error'] is Map) {
        final m = (decoded['error'] as Map)['message'];
        if (m is String && m.trim().isNotEmpty) apiMessage = m.trim();
      }
    } catch (_) {
      // Keine JSON-Fehlerhülle — dann bleibt es beim Statuscode.
    }

    switch (status) {
      case 401:
      case 403:
        return 'Der Schlüssel wurde abgelehnt (HTTP $status).'
            '${apiMessage != null ? '\n$apiMessage' : ''}';
      case 429:
        return 'Zu viele Anfragen (HTTP 429). Bitte später erneut versuchen.'
            '${apiMessage != null ? '\n$apiMessage' : ''}';
      default:
        return 'Die API antwortete mit HTTP $status.'
            '${apiMessage != null ? '\n$apiMessage' : ''}';
    }
  }
}
