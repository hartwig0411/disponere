import 'package:flutter/material.dart';

import '../../data/journal_repository.dart';
import '../../models/calendar_source.dart';
import '../../services/google_auth_service.dart';
import '../../services/google_calendar_service.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';

/// Kühles Blau wie im Journal. Provisorisch, solange die App-Theme-
/// Entscheidung aussteht.
const Color _kAccent = Color(0xFF4A90D9);
const Color _kBg = Color(0xFF1A1A2E);

/// Einstellungen → Google Calendar.
///
/// **Teil 1:** Konto verbinden/trennen und Zugriff prüfen.
/// **Teil 2 (hier):** Kalenderliste abrufen (`calendarList.list`), je Kalender
/// aktivieren und Tags zuordnen. Alles wandert sofort in die DB (Schema v4).
/// Der Sync der eigentlichen Termine folgt in Coding-Session B.
class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key, required this.tagRegistry});

  /// Geteiltes Tag-Register — für Autocomplete und Kanonisierung der
  /// Kalender-Tags. So teilen sich Journal, Aufgaben und Kalender dieselbe
  /// kanonische Schreibweise.
  final TagRegistry tagRegistry;

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  final GoogleAuthService _auth = GoogleAuthService();
  final JournalRepository _repo = JournalRepository();
  late final GoogleCalendarService _calendarService =
      GoogleCalendarService(_auth);

  bool _signedIn = false;
  bool _busy = true;
  bool _loadingCalendars = false;
  String? _message;
  bool _messageIsError = false;
  List<CalendarSource> _sources = <CalendarSource>[];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final signedIn = await _auth.isSignedIn();
    final sources =
        signedIn ? await _repo.loadCalendarSources() : <CalendarSource>[];
    _registerTags(sources);
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _sources = sources;
      _busy = false;
    });
  }

  /// Füttert die bereits zugeordneten Kalender-Tags ins geteilte Register,
  /// damit sie diese Sitzung über im Autocomplete auftauchen.
  void _registerTags(List<CalendarSource> sources) {
    for (final source in sources) {
      widget.tagRegistry.canonicalizeAll(source.tags);
    }
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

  /// Aktualisiert Verbindungsstatus und lädt bei bestehender Verbindung die
  /// Kalender-Quellen aus der DB nach.
  Future<void> _refreshStatus() async {
    final signedIn = await _auth.isSignedIn();
    final sources =
        signedIn ? await _repo.loadCalendarSources() : <CalendarSource>[];
    _registerTags(sources);
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _sources = sources;
      _busy = false;
    });
  }

  void _signIn() => _run(_auth.signIn, 'Konto verbunden.');

  void _signOut() => _run(_auth.signOut, 'Konto getrennt.');

  /// Ruft `calendarList.list` ab, gleicht die lokale Liste ab und lädt sie neu.
  /// Das ist zugleich der Zugriffstest: schlägt der Token-Refresh fehl, landet
  /// die Fehlermeldung hier.
  Future<void> _loadCalendars() async {
    setState(() {
      _loadingCalendars = true;
      _message = null;
    });
    try {
      final remote = await _calendarService.fetchCalendarList();
      final map = <String, String>{
        for (final c in remote) c.id: c.summary,
      };
      await _repo.mergeCalendarList(map);
      final sources = await _repo.loadCalendarSources();
      _registerTags(sources);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _message = '${sources.length} Kalender geladen.';
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _loadingCalendars = false);
    }
  }

  Future<void> _toggleEnabled(CalendarSource source, bool value) async {
    final updated = source.copyWith(enabled: value);
    await _repo.upsertCalendarSource(updated);
    _replaceSource(updated);
  }

  /// Öffnet einen Tag-Editor für einen Kalender. Speichert die kanonisierten
  /// Tags in die DB und ins Register.
  Future<void> _editTags(CalendarSource source) async {
    final controller = TextEditingController(text: formatTags(source.tags));
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tags, die jeder Termin dieses Kalenders erbt.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TagAutocompleteField(
                controller: controller,
                knownTags: widget.tagRegistry.allTags,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _kAccent),
                  onPressed: () {
                    final tags = widget.tagRegistry
                        .canonicalizeAll(parseTags(controller.text));
                    Navigator.pop(sheetContext, tags);
                  },
                  child: const Text('Speichern'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == null) return; // abgebrochen
    final updated = source.copyWith(tags: saved);
    await _repo.upsertCalendarSource(updated);
    _replaceSource(updated);
  }

  void _replaceSource(CalendarSource updated) {
    if (!mounted) return;
    setState(() {
      _sources = _sources
          .map((s) => s.calendarId == updated.calendarId ? updated : s)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
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
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              onPressed: _loadingCalendars ? null : _loadCalendars,
              icon: _loadingCalendars
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _loadingCalendars ? 'Lädt …' : 'Kalender laden/aktualisieren',
              ),
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
          if (_signedIn) ...[
            const SizedBox(height: 32),
            if (_sources.isEmpty)
              const Text(
                'Noch keine Kalender geladen. Tippe auf '
                '„Kalender laden/aktualisieren".',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              )
            else ...[
              const Text(
                'KALENDER',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              for (final source in _sources) _CalendarTile(
                source: source,
                onToggle: (v) => _toggleEnabled(source, v),
                onEditTags: () => _editTags(source),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Eine Kalender-Zeile: Aktiv-Schalter, Name, zugeordnete Tags + Editor.
class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.source,
    required this.onToggle,
    required this.onEditTags,
  });

  final CalendarSource source;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditTags;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: source.enabled
              ? _kAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.displayName,
                  style: TextStyle(
                    color: source.enabled ? Colors.white : Colors.white54,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch(
                value: source.enabled,
                activeColor: _kAccent,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: source.tags.isEmpty
                    ? const Text(
                        'Keine Tags',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in source.tags) _TagPill(tag: tag),
                        ],
                      ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: _kAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onEditTags,
                icon: const Icon(Icons.sell_outlined, size: 16),
                label: const Text('Tags', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kleine Tag-Pille in Akzentfarbe.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(color: _kAccent, fontSize: 12),
      ),
    );
  }
}
