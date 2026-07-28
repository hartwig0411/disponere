import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/journal_entry.dart';
import '../../../models/task.dart';
import '../../../models/daily_info.dart';
import '../../../models/calendar_event.dart';
import '../../tags/tag_view_screen.dart';
import 'date_header.dart';
import 'entry_card.dart';
import 'task_card.dart';
import 'event_card.dart';
import 'daily_info.dart';

// -----------------------------------------------------------------------------
// Design 4b — Vergangene Tage: die fertige Tagesgeschichte.
//
// Anders als heute (freie Schreibflaeche, Design 4a) werden vergangene Tage
// nach `#Tag` gruppiert: tag-lose Notizen oben (chronologisch), darunter je ein
// Cluster pro Tag, geordnet nach der ersten Uhrzeit des Tages. Termine und
// Aufgaben bleiben INLINE (das „Auftauchen am richtigen Tag" ist Teil der Seele
// der App) — dafuer nach ihrem Kalendertag bzw. Faelligkeitstag eingeordnet.
//
// Mehrfach-Auftauchen ist gewollt: ein Element mit mehreren Tags erscheint unter
// jedem seiner Tags — stets DASSELBE Element (dieselbe Karte, dieselben Chips).
// Das Abhaken einer Aufgabe streicht alle Vorkommen mit, weil die Timeline nach
// jeder Mutation aus dem Repository neu aufgebaut wird (kein Widget-Cache).
// -----------------------------------------------------------------------------

/// Ein vereinheitlichtes Journal-Element eines Tages: Eintrag ODER Aufgabe ODER
/// Termin, jeweils mit Uhrzeit (fuer die Sortierung) und Tags.
class JournalItem {
  final DateTime time;
  final JournalEntry? entry;
  final Task? task;
  final CalendarEvent? event;

  const JournalItem._({
    required this.time,
    this.entry,
    this.task,
    this.event,
  });

  factory JournalItem.entry(JournalEntry e, DateTime time) =>
      JournalItem._(time: time, entry: e);
  factory JournalItem.task(Task t, DateTime time) =>
      JournalItem._(time: time, task: t);
  factory JournalItem.event(CalendarEvent ev, DateTime time) =>
      JournalItem._(time: time, event: ev);

  /// Alle Tags des Elements (leer = tag-lose Notiz).
  List<String> get tags =>
      entry?.tags ?? task?.tags ?? event?.tags ?? const <String>[];
}

/// Ein `#Tag`-Cluster innerhalb eines vergangenen Tages.
class TagCluster {
  /// Anzeigeform des Tags (kanonisch, ohne fuehrendes `#`).
  final String tag;

  /// Erste Uhrzeit im Cluster — bestimmt die Cluster-Reihenfolge im Tag.
  final DateTime firstTime;

  /// Elemente des Clusters, chronologisch (aufsteigend).
  final List<JournalItem> items;

  const TagCluster({
    required this.tag,
    required this.firstTime,
    required this.items,
  });
}

/// Ein vergangener Tag mit Tagesinfo, tag-losen Notizen und `#Tag`-Clustern.
class PastDay {
  final DateTime day;
  final List<DailyInfo> infos;
  final List<JournalItem> taglessNotes;
  final List<TagCluster> clusters;

  const PastDay({
    required this.day,
    required this.infos,
    required this.taglessNotes,
    required this.clusters,
  });

  // ---------------------------------------------------------------------------
  // Aufbau der Timeline aus den Roh-Listen. Rein funktional, damit sie nach
  // jeder Mutation frisch aus dem Repository-Stand berechnet werden kann.
  //
  // Erwartet bereits VERGANGENE Daten:
  // - [pastEntries]  Eintraege mit Zeitstempel vor heute
  // - [pastTasks]    Aufgaben mit Faelligkeit in der Vergangenheit (offen UND
  //                  erledigt); Aufgaben ohne Day gehoeren zu keinem Tag und
  //                  bleiben im Heute-Panel — hier also draussen.
  // - [pastEvents]   Termine, die die Vergangenheit beruehren (mehrtaegige
  //                  erscheinen an jedem beruehrten Tag).
  // - [pastInfos]    Tagesinfos, die die Vergangenheit beruehren.
  // [today] ist Mitternacht heute (exklusive Obergrenze).
  //
  // Ein Tag bekommt nur dann einen Block, wenn er echte Aktivitaet traegt
  // (Eintrag, Aufgabe oder Termin). Tagesinfos sind ambient: sie schmuecken
  // vorhandene Tage, erzeugen aber keinen leeren Block (sonst spammt ein
  // mehrtaegiger Urlaub die Vergangenheit mit inhaltslosen Tagen zu).
  // ---------------------------------------------------------------------------
  static List<PastDay> buildTimeline({
    required List<JournalEntry> pastEntries,
    required List<Task> pastTasks,
    required List<CalendarEvent> pastEvents,
    required List<DailyInfo> pastInfos,
    required DateTime today,
  }) {
    final buckets = <String, List<JournalItem>>{};

    void add(String key, JournalItem item) {
      (buckets[key] ??= <JournalItem>[]).add(item);
    }

    // Eintraege — nach ihrem Kalendertag.
    for (final e in pastEntries) {
      final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      if (!day.isBefore(today)) continue;
      add(_dayKey(day), JournalItem.entry(e, e.timestamp));
    }

    // Aufgaben — nach ihrem Faelligkeitstag (offen und erledigt).
    for (final t in pastTasks) {
      final due = t.dueDay;
      if (due == null) continue;
      final day = DateTime(due.year, due.month, due.day);
      if (!day.isBefore(today)) continue;
      add(_dayKey(day), JournalItem.task(t, _taskTime(t, day)));
    }

    // Termine — an jedem beruehrten (vergangenen) Tag. Datumsarithmetik ueber
    // den Konstruktor DateTime(y, m, d+1), nie ueber Duration (DST-sicher).
    for (final ev in pastEvents) {
      var day = _parseDay(ev.startDay);
      final end = _parseDay(ev.endDay);
      while (!day.isAfter(end)) {
        if (!day.isBefore(today)) break; // ab heute nichts mehr (nur Vergangenheit)
        final key = _dayKey(day);
        add(key, JournalItem.event(ev, _eventTime(ev, day, key)));
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }

    final days = <PastDay>[];
    for (final entry in buckets.entries) {
      final day = _parseDay(entry.key);
      final items = entry.value;

      final infos = pastInfos.where((i) => i.coversDay(day)).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      // Tag-lose Notizen (inkl. untagged Aufgaben/Termine) oben, chronologisch.
      final tagless = items.where((it) => it.tags.isEmpty).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      // Cluster: jedes getaggte Element unter JEDEM seiner Tags.
      final byTag = <String, _ClusterAcc>{};
      for (final it in items) {
        for (final tag in it.tags) {
          final key = tag.toLowerCase();
          (byTag[key] ??= _ClusterAcc(tag)).items.add(it);
        }
      }

      final clusters = byTag.values.map((acc) {
        acc.items.sort((a, b) => a.time.compareTo(b.time));
        return TagCluster(
          tag: acc.display,
          firstTime: acc.items.first.time,
          items: acc.items,
        );
      }).toList()
        ..sort((a, b) {
          final c = a.firstTime.compareTo(b.firstTime);
          return c != 0
              ? c
              : a.tag.toLowerCase().compareTo(b.tag.toLowerCase());
        });

      days.add(PastDay(
        day: day,
        infos: infos,
        taglessNotes: tagless,
        clusters: clusters,
      ));
    }

    // Neu nach alt: j-uengster vergangener Tag zuerst (direkt unter heute).
    days.sort((a, b) => b.day.compareTo(a.day));
    return days;
  }

  static DateTime _taskTime(Task t, DateTime day) =>
      _withTime(day, t.dueTime);

  static DateTime _eventTime(CalendarEvent ev, DateTime day, String key) {
    // Nur am Starttag mit echter Startzeit greift die Uhrzeit; ganztaegige und
    // Folgetage sortieren als Tagesbeginn (00:00) an den Anfang.
    if (!ev.allDay && ev.startDay == key) {
      return _withTime(day, ev.startTime);
    }
    return DateTime(day.year, day.month, day.day);
  }

  /// `day` mit einer `HH:mm`-Zeit kombinieren; ohne Zeit -> Tagesbeginn.
  static DateTime _withTime(DateTime day, String? hhmm) {
    if (hhmm == null) return DateTime(day.year, day.month, day.day);
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseDay(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

/// Sammelt waehrend des Aufbaus die Elemente eines Tags samt Anzeigeform.
class _ClusterAcc {
  final String display;
  final List<JournalItem> items = <JournalItem>[];
  _ClusterAcc(this.display);
}

// -----------------------------------------------------------------------------

/// Rendert einen vergangenen Tag: Hairline-Trenner, zweizeiliger Datumskopf,
/// Tagesinfo-Band, tag-lose Notizen und die `#Tag`-Cluster mit feinen
/// Fuehrungslinien links (Design 4b).
class PastDayView extends StatelessWidget {
  final PastDay pastDay;
  final void Function(JournalEntry) onTapEntry;
  final void Function(JournalEntry) onLongPressEntry;
  final void Function(Task) onToggleTask;
  final void Function(DailyInfo) onTapInfo;

  const PastDayView({
    super.key,
    required this.pastDay,
    required this.onTapEntry,
    required this.onLongPressEntry,
    required this.onToggleTask,
    required this.onTapInfo,
  });

  @override
  Widget build(BuildContext context) {
    final dayKey = PastDay._dayKey(pastDay.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Haarfeiner Trenner zwischen zwei Tagen (Design 4).
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Container(height: 1, color: AppColors.hairline),
        ),
        DateHeader(
          weekday: _weekdayName(pastDay.day),
          date: _formatDate(pastDay.day),
        ),
        // Tagesinfo-Band: nur wenn vorhanden. Vergangene Tage zeigen keine
        // Einladung zum Hinzufuegen — nur die Infos selbst, antippbar.
        if (pastDay.infos.isNotEmpty) ...[
          for (final info in pastDay.infos)
            DailyInfoCard(info: info, onTap: () => onTapInfo(info)),
          const SizedBox(height: 8),
        ],
        // Tag-lose Notizen oben.
        for (final item in pastDay.taglessNotes) _itemWidget(context, item, dayKey),
        // `#Tag`-Cluster.
        for (final cluster in pastDay.clusters)
          _clusterWidget(context, cluster, dayKey),
      ],
    );
  }

  Widget _itemWidget(BuildContext context, JournalItem item, String dayKey) {
    final entry = item.entry;
    if (entry != null) {
      return EntryCard(
        entry: entry,
        onTap: () => onTapEntry(entry),
        onLongPress: () => onLongPressEntry(entry),
      );
    }
    final task = item.task;
    if (task != null) {
      // `today` = der gezeigte Tag selbst: so greift die rote „Ueberfaellig"-
      // Logik nicht (die ist ein Heute-Begriff). Die Karte zeigt schlicht die
      // Uhrzeit bzw. das erledigte Haekchen. Kein Antippen (nur Abhaken).
      return TaskCard(
        task: task,
        today: pastDay.day,
        onToggle: () => onToggleTask(task),
      );
    }
    return EventCard(event: item.event!, day: dayKey);
  }

  Widget _clusterWidget(BuildContext context, TagCluster cluster, String dayKey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cluster-Kopf: der Tag im Akzentblau, kleiner und leiser als das
          // Datum. Antippen oeffnet „alles zu diesem Tag" (Design 3/8).
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TagViewScreen(tag: cluster.tag)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '#${cluster.tag}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Elemente mit feiner Fuehrungslinie links (die Verschachtelung, die
          // Logseq so nicht hat).
          Container(
            margin: const EdgeInsets.only(left: 3, top: 2, bottom: 4),
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.guide, width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in cluster.items)
                  _itemWidget(context, item, dayKey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayName(DateTime date) {
    const names = [
      'MONTAG',
      'DIENSTAG',
      'MITTWOCH',
      'DONNERSTAG',
      'FREITAG',
      'SAMSTAG',
      'SONNTAG',
    ];
    return names[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}
