import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/journal_repository.dart';
import '../../models/calendar_event.dart';
import '../../models/daily_info.dart';
import '../../models/journal_entry.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ink_painter.dart';

/// Tag-Ansicht — „alles zu einem Tag über alle Tage" (Fahrplan-Schritt 2).
///
/// Der Kern der App: Einträge, Aufgaben, Termine und Tagesinfos, die denselben
/// `#Tag` tragen, an einem Ort gebündelt und nach Kalendertag gruppiert
/// (**neu nach alt**). Eine reine **Lese-Ansicht** — nicht bearbeiten oder
/// abhaken; das lebt weiter im Journal. Die übrigen Tags jedes Elements sind
/// antippbar und führen in die jeweilige Tag-Ansicht (die Quervernetzung).
class TagViewScreen extends StatefulWidget {
  final String tag;
  const TagViewScreen({super.key, required this.tag});

  @override
  State<TagViewScreen> createState() => _TagViewScreenState();
}

class _TagViewScreenState extends State<TagViewScreen> {
  final JournalRepository _repo = JournalRepository();

  bool _loading = true;
  List<_DayGroup> _groups = const [];

  int _entryCount = 0;
  int _taskCount = 0;
  int _eventCount = 0;
  int _infoCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repo.entriesForTag(widget.tag);
    final tasks = await _repo.tasksForTag(widget.tag);
    final events = await _repo.calendarEventsForTag(widget.tag);
    final infos = await _repo.dailyInfosForTag(widget.tag);

    if (!mounted) return;
    setState(() {
      _groups = _groupByDay(
        entries: entries,
        tasks: tasks,
        events: events,
        infos: infos,
      );
      _entryCount = entries.length;
      _taskCount = tasks.length;
      _eventCount = events.length;
      _infoCount = infos.length;
      _loading = false;
    });
  }

  /// Normalisiert auf den reinen Kalendertag (ohne Uhrzeit).
  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Bündelt die vier Quellen in Tages-Gruppen. Datierte Gruppen neu nach alt;
  /// Aufgaben ohne Datum sammeln sich in einer eigenen Gruppe ganz am Ende.
  List<_DayGroup> _groupByDay({
    required List<JournalEntry> entries,
    required List<Task> tasks,
    required List<CalendarEvent> events,
    required List<DailyInfo> infos,
  }) {
    final byDay = <DateTime, _DayGroup>{};
    final undated = _DayGroup(null);

    _DayGroup groupFor(DateTime day) =>
        byDay.putIfAbsent(day, () => _DayGroup(day));

    for (final info in infos) {
      groupFor(_dayOnly(info.startDate)).infos.add(info);
    }
    for (final event in events) {
      groupFor(_dayOnly(DateTime.parse(event.startDay))).events.add(event);
    }
    for (final task in tasks) {
      final due = task.dueDay;
      (due == null ? undated : groupFor(_dayOnly(due))).tasks.add(task);
    }
    for (final entry in entries) {
      // Nach `journalDay` (Anzeige-Tag bei datierten Eintraegen, sonst
      // Zeitstempel-Tag) — dieselbe Zuordnung wie im Journal, damit ein Eintrag
      // auch hier an genau einem Tag liegt.
      groupFor(entry.journalDay).entries.add(entry);
    }

    final dated = byDay.values.toList()
      ..sort((a, b) => b.day!.compareTo(a.day!));
    if (undated.isNotEmpty) dated.add(undated);
    return dated;
  }

  void _openTag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TagViewScreen(tag: tag)),
    );
  }

  String get _countLabel {
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';
    final parts = <String>[
      if (_entryCount > 0) plural(_entryCount, 'Eintrag', 'Einträge'),
      if (_taskCount > 0) plural(_taskCount, 'Aufgabe', 'Aufgaben'),
      if (_eventCount > 0) plural(_eventCount, 'Termin', 'Termine'),
      if (_infoCount > 0) plural(_infoCount, 'Info', 'Infos'),
    ];
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: AppColors.iconActive),
        title: Text(
          '#${widget.tag}',
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _groups.isEmpty
              ? _EmptyTag(tag: widget.tag)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    _TagHeader(tag: widget.tag, countLabel: _countLabel),
                    for (var i = 0; i < _groups.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.hairline,
                          ),
                        ),
                      _DaySection(
                        group: _groups[i],
                        currentTag: widget.tag,
                        onTagTap: _openTag,
                      ),
                    ],
                  ],
                ),
    );
  }
}

/// Eine Tages-Gruppe innerhalb der Tag-Ansicht. `day == null` → Aufgaben ohne
/// Datum. Die Elemente folgen der Journal-Reihenfolge (Design §4): Tagesinfo,
/// Termine, Aufgaben, Einträge.
class _DayGroup {
  final DateTime? day;
  final List<DailyInfo> infos = [];
  final List<CalendarEvent> events = [];
  final List<Task> tasks = [];
  final List<JournalEntry> entries = [];

  _DayGroup(this.day);

  bool get isNotEmpty =>
      infos.isNotEmpty ||
      events.isNotEmpty ||
      tasks.isNotEmpty ||
      entries.isNotEmpty;
}

/// Kopf der Ansicht: der Tag groß im Akzentblau, darunter die Zählzeile.
class _TagHeader extends StatelessWidget {
  final String tag;
  final String countLabel;
  const _TagHeader({required this.tag, required this.countLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#$tag',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          if (countLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              countLabel,
              style: const TextStyle(
                color: AppColors.iconInactive,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ein Tag mit Datumskopf und seinen Elementen.
class _DaySection extends StatelessWidget {
  final _DayGroup group;
  final String currentTag;
  final ValueChanged<String> onTagTap;
  const _DaySection({
    required this.group,
    required this.currentTag,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayLabel(day: group.day),
        const SizedBox(height: 12),
        for (final info in group.infos) _InfoTile(info: info),
        for (final event in group.events)
          _EventTile(
            event: event,
            currentTag: currentTag,
            onTagTap: onTagTap,
          ),
        for (final task in group.tasks)
          _TaskTile(
            task: task,
            currentTag: currentTag,
            onTagTap: onTagTap,
          ),
        for (final entry in group.entries)
          _EntryTile(
            entry: entry,
            currentTag: currentTag,
            onTagTap: onTagTap,
          ),
      ],
    );
  }
}

/// Datums-Zwischenüberschrift einer Tages-Gruppe. Bei `day == null` steht dort
/// „Ohne Datum". Der heutige Tag wird als „HEUTE" ausgezeichnet.
class _DayLabel extends StatelessWidget {
  final DateTime? day;
  const _DayLabel({required this.day});

  static const _weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  static const _months = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  @override
  Widget build(BuildContext context) {
    final d = day;
    if (d == null) {
      return const Text(
        'OHNE DATUM',
        style: TextStyle(
          color: AppColors.weekday,
          fontSize: 12,
          letterSpacing: 2,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final over = TextStyle(
      color: isToday ? AppColors.accent : AppColors.weekday,
      fontSize: 12,
      letterSpacing: 2,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isToday ? 'HEUTE' : _weekdays[d.weekday - 1].toUpperCase(),
            style: over),
        const SizedBox(height: 3),
        Text(
          '${d.day}. ${_months[d.month - 1]} ${d.year}',
          style: const TextStyle(
            color: AppColors.dateLarge,
            fontSize: 19,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Tagesinfo-Kachel — getönte Fläche wie im Journal, mit optionalem
/// Zeitspannen-Label.
class _InfoTile extends StatelessWidget {
  final DailyInfo info;
  const _InfoTile({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dailyInfoBand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.dailyInfoText),
              const SizedBox(width: 6),
              Text(
                info.isRange ? _rangeLabel(info) : 'Tagesinfo',
                style: const TextStyle(
                  color: AppColors.dailyInfoText,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            info.text,
            style: const TextStyle(
              color: AppColors.dailyInfoText,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _rangeLabel(DailyInfo info) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    return '${d(info.startDate)} - ${d(info.endDate!)}';
  }
}

/// Termin-Kachel — gespiegelt aus dem Journal-`_EventCard`, aber ohne
/// Interaktion.
class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final String currentTag;
  final ValueChanged<String> onTagTap;
  const _EventTile({
    required this.event,
    required this.currentTag,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = event.timeLabelForDay(event.startDay) ?? 'ganztägig';
    final location = event.location;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 10),
            child: Icon(Icons.event, size: 18, color: AppColors.accent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.summary,
                  style: const TextStyle(color: AppColors.text, fontSize: 15),
                ),
                if (location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 13, color: AppColors.placeholder),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                              color: AppColors.iconInactive, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                _OtherTags(
                  tags: event.tags,
                  currentTag: currentTag,
                  onTagTap: onTagTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aufgaben-Kachel — Status sichtbar (Kästchen, Durchstreichung, überfällig),
/// aber read-only: kein Abhaken hier.
class _TaskTile extends StatelessWidget {
  final Task task;
  final String currentTag;
  final ValueChanged<String> onTagTap;
  const _TaskTile({
    required this.task,
    required this.currentTag,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final overdue = task.isOverdue(today);
    final meta = _metaLabel(overdue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 1),
            child: Icon(
              task.done ? Icons.check_box : Icons.check_box_outline_blank,
              color: task.done
                  ? AppColors.accent
                  : (overdue ? AppColors.danger : AppColors.taskOpenBox),
              size: 22,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.done ? AppColors.taskDoneText : AppColors.text,
                    fontSize: 15,
                    height: 1.3,
                    decoration: task.done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.taskDoneText,
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: TextStyle(
                      color:
                          overdue ? AppColors.danger : AppColors.iconInactive,
                      fontSize: 12,
                    ),
                  ),
                ],
                _OtherTags(
                  tags: task.tags,
                  currentTag: currentTag,
                  onTagTap: onTagTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Meta-Zeile unter dem Titel — gespiegelt aus dem Journal-`_TaskCard`.
  String? _metaLabel(bool overdue) {
    String dm(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    if (overdue) {
      final base = 'Ueberfaellig - ${dm(task.dueDay!)}';
      return task.dueTime != null ? '$base - ${task.dueTime}' : base;
    }
    if (task.dueDay == null) return 'Ohne Datum';
    return task.dueTime;
  }
}

/// Eintrags-Kachel — getippt oder Tinte (Vorschau via [InkPreviewPainter]).
class _EntryTile extends StatelessWidget {
  final JournalEntry entry;
  final String currentTag;
  final ValueChanged<String> onTagTap;
  const _EntryTile({
    required this.entry,
    required this.currentTag,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final hh = entry.timestamp.hour.toString().padLeft(2, '0');
    final mm = entry.timestamp.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$hh:$mm',
                style: const TextStyle(
                  color: AppColors.placeholder,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              if (entry.isInk) ...[
                const SizedBox(width: 8),
                const Icon(Icons.brush, size: 12, color: AppColors.placeholder),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (entry.isInk)
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: InkPreviewPainter(entry.ink!, color: AppColors.ink),
                child: const SizedBox.expand(),
              ),
            )
          else if (entry.content.isNotEmpty)
            Text(
              entry.content,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          // Bild-Anhang (Session A): Miniatur direkt aus der Bilddatei. Ein
          // reiner Bild-Eintrag (leerer Inhalt, keine Tinte) zeigt nur die
          // Miniatur — der leere Text oben fällt dann weg.
          if (entry.hasImage) ...[
            const SizedBox(height: 8),
            _EntryImage(path: entry.attachments.first.filePath),
          ],
          _OtherTags(
            tags: entry.tags,
            currentTag: currentTag,
            onTagTap: onTagTap,
          ),
        ],
      ),
    );
  }
}

/// Bild-Miniatur einer Eintrags-Kachel. Rendert direkt aus der Bilddatei
/// ([Attachment.filePath]) — ein separates Thumbnail gibt es (noch) nicht,
/// `thumbPath` ist ungenutzt. In der Höhe begrenzt und mit `cacheWidth`
/// sparsam dekodiert; dieselbe Vorschau wie im Journal, hier rein zum Ansehen.
class _EntryImage extends StatelessWidget {
  final String path;
  const _EntryImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 720,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 100,
          alignment: Alignment.center,
          color: AppColors.fieldFill,
          child: const Text(
            'Bild nicht gefunden',
            style: TextStyle(color: AppColors.placeholder),
          ),
        ),
      ),
    );
  }
}

/// Zeigt die **übrigen** Tags eines Elements (alle außer dem aktuell
/// betrachteten) als antippbare Chips. Antippen springt in die Tag-Ansicht des
/// jeweiligen Tags — das ist die Quervernetzung über Tags.
class _OtherTags extends StatelessWidget {
  final List<String> tags;
  final String currentTag;
  final ValueChanged<String> onTagTap;
  const _OtherTags({
    required this.tags,
    required this.currentTag,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final key = currentTag.toLowerCase();
    final others = tags.where((t) => t.toLowerCase() != key).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final tag in others)
            _TagLink(label: tag, onTap: () => onTagTap(tag)),
        ],
      ),
    );
  }
}

/// Antippbarer Tag-Chip (Akzentblau). Gegenstück zum Journal-`_TagChip`, hier
/// mit Navigation in die jeweilige Tag-Ansicht.
class _TagLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TagLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tagChipBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            '#$label',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Leerzustand: der Tag existiert (angetippt), trägt aber nichts.
class _EmptyTag extends StatelessWidget {
  final String tag;
  const _EmptyTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tag, size: 40, color: AppColors.placeholder),
            const SizedBox(height: 12),
            Text(
              'Noch nichts unter #$tag',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
