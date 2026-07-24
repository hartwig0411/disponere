import '../data/journal_repository.dart';
import '../models/journal_entry.dart';

/// Ein Auswertungsfenster: eine Kalenderwoche, Montag bis Sonntag
/// (Architektur §8).
///
/// Das Fenster kennt nur **reine Kalendertage** — keine Uhrzeiten. Alles
/// Rechnen mit Tagen läuft über [addDays] und damit über den
/// `DateTime`-Konstruktor, nie über `add(Duration(days: n))`: Ein `Duration`
/// verschiebt die absolute Zeit, und beim Wechsel zwischen Sommer- und
/// Winterzeit landet Mitternacht plus sieben Tage auf 23:00 des Vortages.
/// Der Datums-Schlüssel wäre dann um einen Tag daneben — und die
/// Wochengrenze mit ihm.
class WeekWindow {
  /// Montag des Fensters, 00:00.
  final DateTime monday;

  /// Letzter Tag des Fensters, **inklusiv**. Bei einer abgeschlossenen Woche
  /// der Sonntag; bei der laufenden Woche der heutige Tag.
  final DateTime lastDay;

  const WeekWindow._(this.monday, this.lastDay);

  /// Verschiebt [d] um [n] Kalendertage und landet immer auf Mitternacht.
  static DateTime addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  /// Montag der Woche, in der [day] liegt. `DateTime.weekday` ist bereits
  /// ISO-konform (Montag = 1 … Sonntag = 7).
  static DateTime mondayOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return addDays(d, 1 - d.weekday);
  }

  /// Die vollständige Woche (Mo–So), in der [day] liegt.
  factory WeekWindow.fullWeekOf(DateTime day) {
    final m = mondayOf(day);
    return WeekWindow._(m, addDays(m, 6));
  }

  /// Das Fenster, das beim Öffnen vorgeschlagen wird (Architektur §8):
  ///
  /// - **Freitag ab 12:00 bis Sonntag** → die laufende Woche, Montag bis heute.
  /// - **Montag bis Freitag 11:59** → die vorige Woche, vollständig.
  ///
  /// Am Freitagmittag ist die Arbeitswoche faktisch gelaufen; bis Montag
  /// warten zu müssen wäre unbrauchbar.
  factory WeekWindow.suggested(DateTime now) {
    final running = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday ||
        (now.weekday == DateTime.friday && now.hour >= 12);
    if (running) {
      return WeekWindow._(
        mondayOf(now),
        DateTime(now.year, now.month, now.day),
      );
    }
    return WeekWindow.fullWeekOf(addDays(now, -7));
  }

  /// Sonntag der Woche — auch dann, wenn das Fenster früher endet.
  DateTime get sunday => addDays(monday, 6);

  /// Läuft die Woche noch? Dann endet das Fenster vor dem Sonntag.
  bool get isPartial => lastDay.isBefore(sunday);

  /// Die Tage des Fensters. Bewusst eine Schleife statt `difference().inDays`:
  /// Zwischen zwei Mitternachten liegt über einen Zeitumstellungs-Sonntag
  /// hinweg nur 6 Tage 23 Stunden, und `inDays` schneidet auf 6 ab.
  List<DateTime> get days {
    final out = <DateTime>[];
    var d = monday;
    while (!d.isAfter(lastDay)) {
      out.add(d);
      d = addDays(d, 1);
    }
    return out;
  }

  /// ISO-Kalenderwoche.
  int get weekNumber => isoWeekNumber(monday);

  /// Kopfzeile des Screens: `KW 30 · 20.07.–26.07.` (Architektur §8). Nennt
  /// immer die ganze Woche; dass das Fenster früher endet, sagt [isPartial]
  /// an anderer Stelle — sonst stünde dort je nach Wochentag etwas anderes.
  String get label =>
      'KW $weekNumber · ${formatShort(monday)}–${formatShort(sunday)}';

  /// Verschiebt das Fenster um [weeks] Wochen, **gedeckelt** bei [suggested]:
  /// Vorwärts gibt es nichts auszuwerten, was noch nicht stattgefunden hat.
  /// Landet die Verschiebung auf dem vorgeschlagenen Fenster, wird genau
  /// dieses zurückgegeben — mit seinem verkürzten Ende, nicht als volle Woche.
  WeekWindow shiftedWithin(int weeks, WeekWindow suggested) {
    final m = addDays(monday, weeks * 7);
    if (!m.isBefore(suggested.monday)) return suggested;
    return WeekWindow.fullWeekOf(m);
  }

  /// Ist eine Verschiebung nach vorn noch möglich?
  bool canGoForward(WeekWindow suggested) => monday.isBefore(suggested.monday);

  // ---------------------------------------------------------------------------
  // Datums-Werkzeug
  // ---------------------------------------------------------------------------

  static const List<String> _weekdayNames = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];

  /// Tage vor Monatsbeginn, ohne Schaltjahr — Grundlage für [_dayOfYear].
  static const List<int> _monthOffsets = [
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334,
  ];

  static bool _isLeapYear(int y) =>
      (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// Tag des Jahres (1–366). Bewusst gerechnet statt über `difference()` —
  /// dieselbe Zeitumstellungs-Falle wie bei [days].
  static int _dayOfYear(DateTime d) {
    var n = _monthOffsets[d.month - 1] + d.day;
    if (d.month > 2 && _isLeapYear(d.year)) n += 1;
    return n;
  }

  /// ISO-8601-Kalenderwoche: Die Woche gehört zu dem Jahr, in dem ihr
  /// **Donnerstag** liegt. Damit stimmt auch der Jahreswechsel.
  static int isoWeekNumber(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final thursday = addDays(d, 4 - d.weekday);
    return ((_dayOfYear(thursday) - 1) ~/ 7) + 1;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `20.07.`
  static String formatShort(DateTime d) => '${_two(d.day)}.${_two(d.month)}.';

  /// `20.07.2026`
  static String formatFull(DateTime d) =>
      '${_two(d.day)}.${_two(d.month)}.${d.year}';

  /// `Montag, 20.07.2026`
  static String formatWithWeekday(DateTime d) =>
      '${_weekdayNames[d.weekday - 1]}, ${formatFull(d)}';

  /// `yyyy-MM-dd` — dasselbe Format wie im Repository.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${_two(d.month)}-${_two(d.day)}';

  /// `HH:mm`
  static String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}

/// Stellt aus der Datenbank den Text zusammen, der als Kontext einer Woche an
/// Claude geht (Architektur §8).
///
/// Bewusst getrennt vom Repository: Dort liegen die Abfragen, hier die
/// **Formulierung**. Wer den Kontext ändern will — andere Reihenfolge, andere
/// Auszeichnung, mehr oder weniger Detail — fasst nur diese Datei an und nicht
/// die Persistenz.
class WeekContext {
  const WeekContext._();

  /// Baut den Kontexttext für [window].
  ///
  /// Aufbau: eine Kopfzeile mit dem Fenster, danach ein Abschnitt je Tag mit
  /// Tagesinfo, Terminen, Aufgaben und Einträgen, am Ende eine Übersicht der
  /// Tags. Die Tags sind für die Auswertung die eigentliche Struktur — sie
  /// zeigen, worauf die Woche verteilt war.
  static Future<String> build(
    JournalRepository repo,
    WeekWindow window,
  ) async {
    final entries = await repo.entriesInRange(window.monday, window.lastDay);
    final tasks = await repo.tasksInRange(window.monday, window.lastDay);
    final infos = await repo.dailyInfosInRange(window.monday, window.lastDay);
    final events =
        await repo.calendarEventsInRange(window.monday, window.lastDay);

    // Handschrift ohne Auswertung fließt nicht ein — es gibt keinen Text, den
    // man schicken könnte. Wie viele es waren, steht am Ende: sonst entstünde
    // der Eindruck, an diesen Tagen sei nichts gewesen.
    bool printable(JournalEntry e) =>
        e.isInk ? e.hasInkText : e.content.trim().isNotEmpty;
    final included = entries.where(printable).toList();
    final skippedInk = entries.where((e) => e.isInk && !e.hasInkText).length;

    final buffer = StringBuffer();
    buffer.writeln(
      'Kalenderwoche ${window.weekNumber}, '
      '${WeekWindow.formatFull(window.monday)} bis '
      '${WeekWindow.formatFull(window.lastDay)}.',
    );
    if (window.isPartial) {
      buffer.writeln(
        'Die Woche läuft noch; ausgewertet wird bis einschließlich '
        '${WeekWindow.formatWithWeekday(window.lastDay)}.',
      );
    }

    for (final day in window.days) {
      final key = WeekWindow.dateKey(day);
      final dayInfos = infos.where((i) => i.coversDay(day)).toList();
      final dayEvents = events.where((e) => e.coversDay(key)).toList();
      final dayTasks = tasks
          .where((t) => t.dueDay != null && WeekWindow.dateKey(t.dueDay!) == key)
          .toList();
      final dayEntries = included
          .where((e) => WeekWindow.dateKey(e.timestamp) == key)
          .toList();

      buffer.writeln();
      buffer.writeln('## ${WeekWindow.formatWithWeekday(day)}');

      if (dayInfos.isEmpty &&
          dayEvents.isEmpty &&
          dayTasks.isEmpty &&
          dayEntries.isEmpty) {
        buffer.writeln('(keine Aufzeichnungen)');
        continue;
      }

      if (dayInfos.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('### Tagesinfo');
        for (final info in dayInfos) {
          final span = info.isRange
              ? ' (${WeekWindow.formatShort(info.startDate)}'
                  '–${WeekWindow.formatShort(info.endDate!)})'
              : '';
          buffer.writeln('- ${_oneLine(info.text)}$span');
        }
      }

      if (dayEvents.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('### Termine');
        for (final event in dayEvents) {
          final time = event.timeLabelForDay(key) ?? 'ganztägig';
          final place = event.location != null && event.location!.isNotEmpty
              ? ', ${_oneLine(event.location!)}'
              : '';
          buffer.writeln(
            '- $time — ${_oneLine(event.summary)}$place${_tagSuffix(event.tags)}',
          );
        }
      }

      if (dayTasks.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('### Aufgaben');
        for (final task in dayTasks) {
          final state = task.done ? 'erledigt' : 'offen';
          final time = task.dueTime != null ? '${task.dueTime} ' : '';
          buffer.writeln(
            '- [$state] $time${_oneLine(task.title)}${_tagSuffix(task.tags)}',
          );
        }
      }

      if (dayEntries.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('### Einträge');
        for (final entry in dayEntries) {
          final time = WeekWindow.formatTime(entry.timestamp);
          final origin = entry.isInk ? ' (Handschrift, erkannter Text)' : '';
          buffer.writeln('- $time$origin${_tagSuffix(entry.tags)}');
          buffer.writeln(
            _indent(entry.isInk ? entry.inkText! : entry.content),
          );
        }
      }
    }

    final tagCounts = <String, int>{};
    void bump(List<String> tags) {
      for (final tag in tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    for (final e in included) {
      bump(e.tags);
    }
    for (final t in tasks) {
      bump(t.tags);
    }
    for (final e in events) {
      bump(e.tags);
    }

    if (tagCounts.isNotEmpty) {
      final sorted = tagCounts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0
              ? byCount
              : a.key.toLowerCase().compareTo(b.key.toLowerCase());
        });
      buffer.writeln();
      buffer.writeln('## Tags dieser Woche');
      for (final e in sorted) {
        buffer.writeln('- #${e.key}: ${e.value}');
      }
    }

    if (skippedInk > 0) {
      buffer.writeln();
      buffer.writeln(
        'Hinweis: $skippedInk handschriftliche '
        '${skippedInk == 1 ? 'Eintrag ist' : 'Einträge sind'} nicht '
        'ausgewertet und daher hier nicht enthalten.',
      );
    }

    return buffer.toString().trimRight();
  }

  /// Zieht Zeilenumbrüche zu Leerzeichen zusammen — für alles, was in einer
  /// Aufzählungszeile steht und diese nicht sprengen soll.
  static String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// ` · #MBS #ValSys` — oder nichts, wenn es keine Tags gibt.
  static String _tagSuffix(List<String> tags) =>
      tags.isEmpty ? '' : ' · ${tags.map((t) => '#$t').join(' ')}';

  /// Rückt einen mehrzeiligen Text um zwei Leerzeichen ein, damit er sichtbar
  /// zur Zeile darüber gehört. Zeilenumbrüche bleiben erhalten — bei einem
  /// Eintrag mit Aufzählung ist die Gliederung Teil der Aussage.
  static String _indent(String text) {
    return text
        .trim()
        .split('\n')
        .map((line) => '  ${line.trimRight()}')
        .join('\n');
  }
}
