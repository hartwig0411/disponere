import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entwurfs-Sicherung für die Tipptext-Sheets (E-05, Anforderungen v6.19).
///
/// Problem aus dem Tagesbetrieb: Ungespeicherter Text im „Neuer Eintrag“-Sheet
/// oder in der Brücke Termin → Eintrag ging verloren, wenn Android die App im
/// Hintergrund beendete oder das Sheet versehentlich zugewischt wurde.
///
/// **Mechanik.** Während das Sheet offen ist, schreibt eine [DraftSession] den
/// Stand (Text + Tags) entprellt in `shared_preferences`, garantiert beim
/// Lebenszyklus-Wechsel in den Hintergrund ([flushActive], aufgerufen vom
/// Journal-Screen) und beim Schließen des Sheets. Beim nächsten Öffnen wird der
/// Entwurf vorbelegt und mit einem Hinweis angezeigt. **Gelöscht** wird er nur
/// durch Speichern oder „Verwerfen“ — Wegwischen behält ihn.
///
/// **Zwei Slots, bewusst keine Tabelle.** [entrySlot] für „Neuer Eintrag“,
/// [eventBridgeSlot] für Termin → Eintrag. Der Brücken-Entwurf trägt eine
/// Quellen-Kennung (Kalender + Termin + Tag) und kommt nur beim **selben**
/// Termin zurück. Kein Schema-Eingriff; die Ablage ist reversibel.
///
/// Gelesen wird erst beim Öffnen eines Sheets — lange nach dem App-Start, daher
/// kein Berührungspunkt mit der Start-Reihenfolge (N5).
class DraftStore {
  DraftStore._();

  static const String entrySlot = 'draft_new_entry';
  static const String eventBridgeSlot = 'draft_event_bridge';

  /// Alle Schreib- und Löschvorgänge laufen über diese Kette — so kann ein
  /// verspätetes Schreiben nie ein vorheriges Löschen überholen.
  static Future<void> _chain = Future.value();

  /// Die gerade offene Sitzung (höchstens ein Tipptext-Sheet ist offen).
  static DraftSession? _active;

  static Future<void> _enqueue(Future<void> Function() op) {
    _chain = _chain.then((_) => op()).catchError((_) {});
    return _chain;
  }

  /// Liest den Entwurf eines Slots. Mit [sourceId] nur, wenn er zu genau
  /// dieser Quelle gehört. `null`, wenn nichts (Brauchbares) vorliegt.
  static Future<Draft?> load(String slot, {String? sourceId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(slot);
      if (raw == null) return null;
      final draft = Draft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (draft.isEmpty) return null;
      if (sourceId != null && draft.sourceId != sourceId) return null;
      return draft;
    } catch (_) {
      // Kaputter Slot darf nie ein Sheet blockieren.
      return null;
    }
  }

  static Future<void> _write(String slot, Draft draft) => _enqueue(() async {
        final prefs = await SharedPreferences.getInstance();
        if (draft.isEmpty) {
          await prefs.remove(slot);
        } else {
          await prefs.setString(slot, jsonEncode(draft.toJson()));
        }
      });

  static Future<void> _clear(String slot) => _enqueue(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(slot);
      });

  /// Vom Journal-Screen bei `inactive`/`paused`/`hidden` aufgerufen: schreibt
  /// die offene Sitzung sofort, ohne auf die Entprellung zu warten.
  static void flushActive() => _active?.flush();
}

/// Ein gesicherter Entwurf: eigener Text, Tag-Feld, Zeitpunkt, optional die
/// Quelle (nur Brücke).
class Draft {
  final String text;
  final String tagText;
  final DateTime savedAt;
  final String? sourceId;

  const Draft({
    required this.text,
    required this.tagText,
    required this.savedAt,
    this.sourceId,
  });

  /// Nur der eigene Text zählt: ein reines Tag-Feld (z.B. geerbte Tags der
  /// Brücke) ist kein Entwurf, der wiederhergestellt werden müsste.
  bool get isEmpty => text.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'text': text,
        'tags': tagText,
        'savedAt': savedAt.toIso8601String(),
        if (sourceId != null) 'sourceId': sourceId,
      };

  factory Draft.fromJson(Map<String, dynamic> map) => Draft(
        text: map['text'] as String? ?? '',
        tagText: map['tags'] as String? ?? '',
        savedAt: DateTime.tryParse(map['savedAt'] as String? ?? '') ??
            DateTime.now(),
        sourceId: map['sourceId'] as String?,
      );
}

/// Eine laufende Sicherung für ein offenes Sheet. Hängt sich an die
/// Controller, schreibt entprellt, und wird am Ende entweder mit [clear]
/// (gespeichert / verworfen) oder [close] (Sheet zu, Entwurf bleibt) beendet.
class DraftSession {
  static const Duration _debounce = Duration(milliseconds: 800);

  final String slot;
  final String? sourceId;
  final TextEditingController textController;
  final TextEditingController tagController;

  /// Zeitpunkt des wiederhergestellten Entwurfs — `null`, wenn frisch
  /// begonnen. Steuert den Hinweis im Sheet.
  DateTime? restoredAt;

  Timer? _timer;
  bool _finished = false;
  bool _dirty = false;

  DraftSession({
    required this.slot,
    required this.textController,
    required this.tagController,
    this.sourceId,
    this.restoredAt,
  }) {
    textController.addListener(_onChanged);
    tagController.addListener(_onChanged);
    DraftStore._active = this;
  }

  void _onChanged() {
    if (_finished) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(_debounce, flush);
  }

  /// Schreibt den aktuellen Stand sofort (nur wenn sich etwas geändert hat).
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_finished || !_dirty) return;
    _dirty = false;
    DraftStore._write(
      slot,
      Draft(
        text: textController.text,
        tagText: tagController.text,
        savedAt: DateTime.now(),
        sourceId: sourceId,
      ),
    );
  }

  /// „Verwerfen“ im Hinweis: Slot leeren, Sitzung läuft weiter (das Sheet
  /// bleibt offen, neues Tippen wird wieder gesichert).
  void discardRestored() {
    _timer?.cancel();
    _timer = null;
    _dirty = false;
    restoredAt = null;
    DraftStore._clear(slot);
  }

  /// Gespeichert: Entwurf endgültig löschen und abmelden.
  void clear() {
    if (_finished) return;
    _detach();
    DraftStore._clear(slot);
  }

  /// Sheet geschlossen ohne Speichern: letzten Stand sichern und abmelden.
  void close() {
    if (_finished) return;
    flush();
    _detach();
  }

  void _detach() {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    textController.removeListener(_onChanged);
    tagController.removeListener(_onChanged);
    if (identical(DraftStore._active, this)) DraftStore._active = null;
  }
}

/// „14:32“ für heute, sonst „23.09., 14:32“ — für den Hinweis im Sheet.
String formatDraftTime(DateTime t) {
  final now = DateTime.now();
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  if (sameDay) return '$hh:$mm';
  final dd = t.day.toString().padLeft(2, '0');
  final mo = t.month.toString().padLeft(2, '0');
  return '$dd.$mo., $hh:$mm';
}
