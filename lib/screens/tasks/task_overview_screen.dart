import 'package:flutter/material.dart';
import '../../data/journal_repository.dart';
import '../../models/task.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/task_sheet.dart';

/// Grüner Akzent für Aufgaben — identisch zum Journal. Provisorisch, solange
/// die App-Theme-Entscheidung aussteht.
const Color _kTaskAccent = Color(0xFF5FA86A);

/// Sortierung der **offenen** Aufgaben in der Übersicht.
enum _SortMode { day, tag }

/// Aufgaben-Übersicht (Session 17): der einzige Ort, an dem **alle** Aufgaben
/// erscheinen — offene sortierbar nach Day (Standard) oder gruppiert nach Tag,
/// erledigte eingeklappt darunter. Erledigte lassen sich hier (und nur hier)
/// wieder aufhaken.
///
/// Lädt selbst über das [repo] und aktualisiert seinen eigenen Zustand nach
/// jeder Mutation. Das Journal lädt beim Zurückkehren ohnehin neu, muss also
/// nicht aktiv benachrichtigt werden.
class TaskOverviewScreen extends StatefulWidget {
  final JournalRepository repo;
  final TagRegistry tagRegistry;

  const TaskOverviewScreen({
    super.key,
    required this.repo,
    required this.tagRegistry,
  });

  @override
  State<TaskOverviewScreen> createState() => _TaskOverviewScreenState();
}

class _TaskOverviewScreenState extends State<TaskOverviewScreen> {
  final List<Task> _all = [];
  _SortMode _sort = _SortMode.day;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final tasks = await widget.repo.loadAllTasks();
    if (!mounted) return;
    setState(() {
      _all
        ..clear()
        ..addAll(tasks);
      _loading = false;
    });
  }

  Future<void> _toggleDone(Task task) async {
    await widget.repo.upsertTask(task.copyWith(done: !task.done));
    await _reload();
  }

  void _openSheet(Task task) {
    showTaskSheet(
      context: context,
      tagRegistry: widget.tagRegistry,
      existing: task,
      onSave: (updated) async {
        await widget.repo.upsertTask(updated);
        await _reload();
      },
      onDelete: (id) async {
        await widget.repo.deleteTask(id);
        await _reload();
      },
    );
  }

  /// Vergleicht offene Aufgaben für die Day-Sortierung: nach Fälligkeits-Day
  /// aufsteigend (überfällige damit zuerst), gleicher Day nach Uhrzeit,
  /// undatierte ans Ende, zuletzt alphabetisch nach Titel.
  int _openCompare(Task a, Task b) {
    final ad = a.dueDay, bd = b.dueDay;
    if (ad != null && bd != null) {
      final byDay = Task.dayOnly(ad).compareTo(Task.dayOnly(bd));
      if (byDay != 0) return byDay;
      final at = a.dueTime, bt = b.dueTime;
      if (at != null && bt != null) {
        final byTime = at.compareTo(bt);
        if (byTime != 0) return byTime;
      } else if (at == null && bt != null) {
        return 1; // ohne Uhrzeit hinter mit Uhrzeit
      } else if (at != null && bt == null) {
        return -1;
      }
    } else if (ad == null && bd != null) {
      return 1; // undatiert ans Ende
    } else if (ad != null && bd == null) {
      return -1;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final open = _all.where((t) => !t.done).toList()..sort(_openCompare);
    final done = _all.where((t) => t.done).toList()..sort(_openCompare);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Aufgaben',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white54),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kTaskAccent),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSortToggle(),
                const SizedBox(height: 20),
                ..._buildOpenSection(open, today),
                const SizedBox(height: 24),
                _buildDoneSection(done, today),
              ],
            ),
    );
  }

  Widget _buildSortToggle() {
    return SegmentedButton<_SortMode>(
      segments: const [
        ButtonSegment(
          value: _SortMode.day,
          label: Text('Nach Day'),
          icon: Icon(Icons.event, size: 16),
        ),
        ButtonSegment(
          value: _SortMode.tag,
          label: Text('Nach Tag'),
          icon: Icon(Icons.sell_outlined, size: 16),
        ),
      ],
      selected: {_sort},
      onSelectionChanged: (s) => setState(() => _sort = s.first),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF1A1A2E)
              : Colors.white54,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _kTaskAccent
              : Colors.transparent,
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: _kTaskAccent.withOpacity(0.4)),
        ),
      ),
    );
  }

  List<Widget> _buildOpenSection(List<Task> open, DateTime today) {
    final header = _sectionHeader('OFFEN', open.length);
    if (open.isEmpty) {
      return [
        header,
        const SizedBox(height: 10),
        _emptyHint('Keine offenen Aufgaben'),
      ];
    }
    if (_sort == _SortMode.day) {
      return [
        header,
        const SizedBox(height: 10),
        ...open.map((t) => _OverviewTaskCard(
              task: t,
              today: today,
              onToggle: () => _toggleDone(t),
              onTap: () => _openSheet(t),
            )),
      ];
    }
    // Gruppiert nach Tag: jede Aufgabe erscheint unter jedem ihrer Tags.
    return [header, const SizedBox(height: 4), ..._buildTagGroups(open, today)];
  }

  /// Baut die nach Tag gruppierte Ansicht: ein Kopf pro Tag, darunter die
  /// zugehörigen Aufgaben. Eine Aufgabe mit mehreren Tags erscheint mehrfach
  /// (die „alles zu einem Tag"-Lesart). Aufgaben ganz ohne Tag landen in einer
  /// Gruppe „Ohne Tag" am Ende. Tag-Köpfe alphabetisch (case-insensitiv).
  List<Widget> _buildTagGroups(List<Task> open, DateTime today) {
    final groups = <String, List<Task>>{}; // key = lowercase
    final display = <String, String>{}; // key → kanonische Schreibweise
    final untagged = <Task>[];

    for (final t in open) {
      if (t.tags.isEmpty) {
        untagged.add(t);
        continue;
      }
      for (final tag in t.tags) {
        final key = tag.toLowerCase();
        (groups[key] ??= []).add(t);
        display[key] ??= widget.tagRegistry.canonicalize(tag);
      }
    }

    final keys = groups.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final key in keys) {
      final tasks = groups[key]!..sort(_openCompare);
      widgets.add(_tagGroupHeader('#${display[key] ?? key}', tasks.length));
      widgets.addAll(tasks.map((t) => _OverviewTaskCard(
            task: t,
            today: today,
            onToggle: () => _toggleDone(t),
            onTap: () => _openSheet(t),
          )));
    }
    if (untagged.isNotEmpty) {
      untagged.sort(_openCompare);
      widgets.add(_tagGroupHeader('Ohne Tag', untagged.length));
      widgets.addAll(untagged.map((t) => _OverviewTaskCard(
            task: t,
            today: today,
            onToggle: () => _toggleDone(t),
            onTap: () => _openSheet(t),
          )));
    }
    return widgets;
  }

  Widget _buildDoneSection(List<Task> done, DateTime today) {
    if (done.isEmpty) {
      return _sectionHeader('ERLEDIGT', 0);
    }
    return Theme(
      // ExpansionTile-Trennlinien entfernen, damit es zum dunklen Look passt.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white38,
        title: Row(
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Text(
              'ERLEDIGT · ${done.length}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        children: done
            .map((t) => _OverviewTaskCard(
                  task: t,
                  today: today,
                  onToggle: () => _toggleDone(t),
                  onTap: () => _openSheet(t),
                ))
            .toList(),
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Row(
      children: [
        Text(
          count > 0 ? '$label · $count' : label,
          style: TextStyle(
            color: _kTaskAccent.withOpacity(0.9),
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _tagGroupHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        '$label · $count',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kTaskAccent.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }
}

/// Aufgaben-Karte für die Übersicht. Wie im Journal (Checkbox links, Titel,
/// Meta-Zeile, Tag-Chips), zusätzlich mit durchgestrichenem Titel bei
/// erledigten Aufgaben.
class _OverviewTaskCard extends StatelessWidget {
  final Task task;
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  const _OverviewTaskCard({
    required this.task,
    required this.today,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue(today);
    final meta = _metaLabel(overdue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _kTaskAccent.withOpacity(task.done ? 0.05 : 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: task.done
                      ? Colors.white24
                      : (overdue ? Colors.redAccent : _kTaskAccent),
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkResponse(
                  onTap: onToggle,
                  radius: 22,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: Icon(
                      task.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: task.done ? Colors.white38 : _kTaskAccent,
                      size: 22,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: task.done ? Colors.white38 : Colors.white,
                          fontSize: 15,
                          height: 1.3,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: TextStyle(
                            color: (overdue && !task.done)
                                ? Colors.redAccent
                                : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (task.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: task.tags
                              .map((t) => _TagChip(label: t))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// „Überfällig · TT.MM. [· HH:mm]" (rot) bei offen+überfällig, sonst
  /// „TT.MM. [· HH:mm]", sonst nur Uhrzeit, sonst „Ohne Datum".
  String? _metaLabel(bool overdue) {
    String dm(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    if (task.dueDay == null) return 'Ohne Datum';
    final datePart = dm(task.dueDay!);
    final timePart = task.dueTime != null ? ' · ${task.dueTime}' : '';
    if (overdue && !task.done) {
      return 'Überfällig · $datePart$timePart';
    }
    return '$datePart$timePart';
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
