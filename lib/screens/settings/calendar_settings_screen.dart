import 'package:flutter/material.dart';

import '../../services/google_auth_service.dart';

/// Kühles Blau wie im Journal. Provisorisch, solange die App-Theme-
/// Entscheidung aussteht.
const Color _kAccent = Color(0xFF4A90D9);

/// Einstellungen → Google Calendar (Coding-Session A).
///
/// **Teil 1:** Konto verbinden/trennen und Zugriff prüfen. Die Kalenderliste
/// mit Tag-Mapping folgt in Teil 2, der Sync in Coding-Session B.
class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  final GoogleAuthService _auth = GoogleAuthService();

  bool _signedIn = false;
  bool _busy = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final signedIn = await _auth.isSignedIn();
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _busy = false;
    });
  }

  /// Führt eine Auth-Aktion aus und übersetzt Fehler in eine lesbare Meldung.
  /// AppAuth wirft bei Abbruch oder fehlendem Browser eine PlatformException —
  /// die soll als Text im Screen landen, nicht als roter Bildschirm.
  Future<void> _run(Future<void> Function() action, String successText) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _message = successText;
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
    }
    await _refreshStatus();
  }

  void _signIn() => _run(_auth.signIn, 'Konto verbunden.');

  void _signOut() => _run(_auth.signOut, 'Konto getrennt.');

  /// Der eigentliche Test: holt ein Access-Token über den stillen Refresh und
  /// zeigt nur die Länge — das Token selbst gehört nicht auf den Bildschirm.
  void _checkAccess() => _run(() async {
        final token = await _auth.accessToken();
        if (token.isEmpty) {
          throw const GoogleAuthException('Leeres Token erhalten.');
        }
      }, 'Zugriff funktioniert — gültiges Token erhalten.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white54),
        title: const Text(
          'GOOGLE CALENDAR',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(
                _signedIn ? Icons.check_circle_outline : Icons.link_off,
                color: _signedIn ? _kAccent : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                _signedIn ? 'Konto verbunden' : 'Kein Konto verbunden',
                style: TextStyle(
                  color: _signedIn ? Colors.white70 : Colors.white38,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Disponere liest deinen Kalender nur — es schreibt nichts zurück.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
          const SizedBox(height: 32),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kAccent,
                  ),
                ),
              ),
            )
          else if (!_signedIn)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              onPressed: _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Google-Konto verbinden'),
            )
          else ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kAccent,
                side: const BorderSide(color: _kAccent),
              ),
              onPressed: _checkAccess,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Zugriff prüfen'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white38),
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Konto trennen'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_messageIsError ? Colors.red : _kAccent)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (_messageIsError ? Colors.red : _kAccent)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: SelectableText(
                _message!,
                style: TextStyle(
                  color: _messageIsError ? Colors.red.shade200 : Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Text(
            'Kalender-Auswahl und Tag-Zuordnung folgen im nächsten Schritt.',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}