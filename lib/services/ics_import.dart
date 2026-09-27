/// **E-04 · Kalendertermin teilen** (Session 69). Wandelt einen per Teilen
/// empfangenen iCalendar-Text (`.ics`, `text/calendar` — z.B. aus OneCalendar)
/// in lesbaren Import-Text für das Eintrags-Sheet.
///
/// Bewusst **ohne Paket**: ein kleiner, fehlertoleranter Leser für genau das,
/// was ein geteilter Termin braucht — Titel (`SUMMARY`), Beginn/Ende
/// (`DTSTART`/`DTEND`), Ort (`LOCATION`), Beschreibung (`DESCRIPTION`).
/// Beherrscht Zeilen-Faltung (RFC 5545 §3.1), Escapes (`\n`, `\,`, `\;`,
/// `\\`), ganztägige Termine (`VALUE=DATE`, Ende exklusiv) und UTC-Zeiten
/// (`...Z` -> Gerätezeit). Unterkomponenten wie `VALARM` werden übersprungen.
///
/// Zeitzonen mit `TZID` werden **nicht umgerechnet** (dafür bräuchte es die
/// Zeitzonen-Datenbank): die Uhrzeit wird so gezeigt, wie sie im Termin steht.
/// Liegt die TZID außerhalb der mitteleuropäischen Zone, wird sie in Klammern
/// angehängt, damit die Uhrzeit nicht stillschweigend falsch wirkt.
///
/// Ist der Text kein Kalender oder lässt sich kein Termin lesen, kommt er
/// unverändert (nur beschnitten) zurück — nichts geht verloren.
class IcsImport {
  IcsImport._();

  /// Grobe Erkennung: enthält der Text einen iCalendar-Termin?
  static bool looksLikeCalendar(String s) =>
      s.contains('BEGIN:VEVENT') || s.contains('BEGIN:VCALENDAR');

  /// Einstieg für den Teilen-Weg. Kalendertext -> lesbarer Import-Text;
  /// alles andere unverändert.
  static String toImportText(String raw) {
    if (!looksLikeCalendar(raw)) return raw;
    final List<IcsEvent> events;
    try {
      events = parse(raw);
    } catch (_) {
      return raw.trim();
    }
    if (events.isEmpty) return raw.trim();
    return events.map(format).join('\n\n');
  }

  /// Liest alle `VEVENT`-Blöcke. Unbekannte Eigenschaften werden ignoriert.
  static List<IcsEvent> parse(String raw) {
    final lines = _unfold(raw);
    final events = <IcsEvent>[];
    IcsEvent? current;
    var subDepth = 0; // > 0: innerhalb einer Unterkomponente (z.B. VALARM)

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final prop = _IcsProperty.tryParse(line);
      if (prop == null) continue;
      final value = prop.value.trim().toUpperCase();

      if (prop.name == 'BEGIN') {
        if (value == 'VEVENT' && current == null) {
          current = IcsEvent();
        } else if (current != null) {
          subDepth++;
        }
        continue;
      }
      if (prop.name == 'END') {
        if (current == null) continue;
        if (subDepth > 0) {
          subDepth--;
        } else if (value == 'VEVENT') {
          events.add(current);
          current = null;
        }
        continue;
      }
      if (current == null || subDepth > 0) continue;

      switch (prop.name) {
        case 'SUMMARY':
          current.summary = _unescape(prop.value).trim();
          break;
        case 'LOCATION':
          current.location = _unescape(prop.value).trim();
          break;
        case 'DESCRIPTION':
          current.description = _unescape(prop.value);
          break;
        case 'DTSTART':
          current.start = IcsDateTime.tryParse(prop.value, prop.params);
          break;
        case 'DTEND':
          current.end = IcsDateTime.tryParse(prop.value, prop.params);
          break;
        case 'RRULE':
          current.recurring = true;
          break;
      }
    }
    return events;
  }

  /// Ein Termin als Import-Text:
  ///
  ///     Titel
  ///     Mi, 30.09.2026, 14:00–15:30
  ///     Ort: …
  ///     (Serientermin)
  ///
  ///     Beschreibung
  static String format(IcsEvent e) {
    final head = <String>[];
    final title = e.summary;
    head.add((title == null || title.isEmpty) ? '(Ohne Titel)' : title);
    final when = _formatWhen(e.start, e.end);
    if (when != null) head.add(when);
    final loc = e.location;
    if (loc != null && loc.isNotEmpty) head.add('Ort: $loc');
    if (e.recurring) head.add('(Serientermin)');

    final desc = compactBlankLines(e.description ?? '');
    return desc.isEmpty ? head.join('\n') : '${head.join('\n')}\n\n$desc';
  }

  // --- Zeit ---------------------------------------------------------------

  static String? _formatWhen(IcsDateTime? start, IcsDateTime? end) {
    if (start == null) return null;

    if (start.allDay) {
      // Ende ist bei ganztägigen Terminen exklusiv -> letzter Tag = Ende - 1.
      // DST-sicher über den Konstruktor, nie über Duration.
      DateTime? lastDay;
      if (end != null && end.allDay) {
        final e = end.value;
        lastDay = DateTime(e.year, e.month, e.day - 1);
      }
      if (lastDay == null || !lastDay.isAfter(start.value)) {
        return '${_date(start.value)} (ganztägig)';
      }
      return '${_date(start.value)} – ${_date(lastDay)} (ganztägig)';
    }

    final zone = start.zoneNote == null ? '' : ' (${start.zoneNote})';
    final s = start.value;
    if (end == null || end.allDay) {
      return '${_date(s)}, ${_time(s)}$zone';
    }
    final e = end.value;
    if (_sameDay(s, e)) {
      return '${_date(s)}, ${_time(s)}–${_time(e)}$zone';
    }
    return '${_date(s)}, ${_time(s)} – ${_date(e)}, ${_time(e)}$zone';
  }

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  static String _date(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_two(d.day)}.${_two(d.month)}.${d.year}';

  static String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // --- Text ---------------------------------------------------------------

  /// Zeilenenden vereinheitlichen und gefaltete Zeilen zusammenziehen: eine
  /// Zeile, die mit Leerzeichen oder Tab beginnt, setzt die vorige fort (das
  /// erste Zeichen fällt weg).
  static List<String> _unfold(String raw) {
    var s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (s.startsWith('\uFEFF')) s = s.substring(1);
    final out = <String>[];
    for (final line in s.split('\n')) {
      if (out.isNotEmpty &&
          line.isNotEmpty &&
          (line.startsWith(' ') || line.startsWith('\t'))) {
        out[out.length - 1] = out.last + line.substring(1);
      } else {
        out.add(line);
      }
    }
    return out;
  }

  /// TEXT-Escapes nach RFC 5545 §3.3.11 auflösen.
  static String _unescape(String v) {
    final b = StringBuffer();
    for (var i = 0; i < v.length; i++) {
      final c = v[i];
      if (c == '\\' && i + 1 < v.length) {
        final n = v[i + 1];
        if (n == 'n' || n == 'N') {
          b.write('\n');
        } else {
          b.write(n); // \, \; \\ und alles Unbekannte: Zeichen selbst
        }
        i++;
      } else {
        b.write(c);
      }
    }
    return b.toString();
  }

  /// Leerzeilen verdichten: Zeilen rechts beschneiden, Folgen leerer Zeilen
  /// auf eine reduzieren, Rand-Leerzeilen entfernen. Gleiche Regel wie
  /// `_compactDescription` in `bridge_sheet.dart` (Session 61) — dort privat,
  /// hier bewusst eigenständig, damit das Brücken-Sheet unberührt bleibt.
  static String compactBlankLines(String s) {
    final out = <String>[];
    var blankRun = 0;
    for (final raw in s.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        if (++blankRun >= 2) continue;
      } else {
        blankRun = 0;
      }
      out.add(line);
    }
    while (out.isNotEmpty && out.first.isEmpty) {
      out.removeAt(0);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }
}

/// Ein gelesener Termin (nur die Felder, die der Import braucht).
class IcsEvent {
  String? summary;
  String? location;
  String? description;
  IcsDateTime? start;
  IcsDateTime? end;
  bool recurring = false;
}

/// Ein `DTSTART`/`DTEND`-Wert. [value] ist die anzuzeigende Wandzeit.
class IcsDateTime {
  IcsDateTime(this.value, {required this.allDay, this.zoneNote});

  final DateTime value;
  final bool allDay;

  /// TZID außerhalb Mitteleuropas (wird in Klammern angezeigt), sonst null.
  final String? zoneNote;

  /// Zonen, deren Wandzeit hier der Gerätezeit entspricht (Steffens Alltag).
  /// Outlook schreibt Windows-Namen statt IANA-Namen.
  static const _homeZones = {
    'europe/berlin',
    'europe/vienna',
    'europe/zurich',
    'europe/amsterdam',
    'europe/brussels',
    'europe/paris',
    'europe/rome',
    'europe/madrid',
    'europe/prague',
    'europe/warsaw',
    'w. europe standard time',
    'central europe standard time',
    'romance standard time',
    'central european standard time',
  };

  /// Formen: `20260930` (Datum), `20260930T140000` (Wandzeit, ggf. mit TZID),
  /// `20260930T140000Z` (UTC -> Gerätezeit). Unlesbar -> null.
  static IcsDateTime? tryParse(String raw, Map<String, String> params) {
    final v = raw.trim();
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$')
        .firstMatch(v);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final isDateOnly =
        m.group(4) == null || (params['VALUE']?.toUpperCase() == 'DATE');
    if (isDateOnly) {
      return IcsDateTime(DateTime(y, mo, d), allDay: true);
    }
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = int.parse(m.group(6) ?? '0');
    if (m.group(7) != null) {
      return IcsDateTime(DateTime.utc(y, mo, d, h, mi, s).toLocal(),
          allDay: false);
    }
    String? note;
    final tzid = params['TZID'];
    if (tzid != null &&
        tzid.isNotEmpty &&
        !_homeZones.contains(tzid.toLowerCase())) {
      note = tzid;
    }
    return IcsDateTime(DateTime(y, mo, d, h, mi, s),
        allDay: false, zoneNote: note);
  }
}

/// Eine Inhaltszeile `NAME;PARAM=WERT;…:WERT`. Doppelpunkte und Semikolons
/// innerhalb von Anführungszeichen (z.B. `ALTREP="https://…"`) zählen nicht.
class _IcsProperty {
  _IcsProperty(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;

  static _IcsProperty? tryParse(String line) {
    var inQuote = false;
    var colon = -1;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuote = !inQuote;
      } else if (c == ':' && !inQuote) {
        colon = i;
        break;
      }
    }
    if (colon <= 0) return null;
    final head = line.substring(0, colon);
    final value = line.substring(colon + 1);

    final parts = <String>[];
    final buf = StringBuffer();
    inQuote = false;
    for (var i = 0; i < head.length; i++) {
      final c = head[i];
      if (c == '"') {
        inQuote = !inQuote;
        buf.write(c);
      } else if (c == ';' && !inQuote) {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    parts.add(buf.toString());

    final name = parts.first.trim().toUpperCase();
    if (name.isEmpty) return null;
    final params = <String, String>{};
    for (final p in parts.skip(1)) {
      final eq = p.indexOf('=');
      if (eq <= 0) continue;
      var pv = p.substring(eq + 1).trim();
      if (pv.length >= 2 && pv.startsWith('"') && pv.endsWith('"')) {
        pv = pv.substring(1, pv.length - 1);
      }
      params[p.substring(0, eq).trim().toUpperCase()] = pv;
    }
    return _IcsProperty(name, params, value);
  }
}
