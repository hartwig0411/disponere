import 'package:flutter/material.dart';
import '../../data/journal_repository.dart';
import '../../models/journal_entry.dart';
import '../../models/daily_info.dart';
import '../../models/task.dart';
import '../../models/ink_data.dart';
import '../../screens/text/native_text_entry_screen.dart';
import '../../screens/drawing/drawing_screen.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../../widgets/ink_painter.dart';
import '../../screens/tags/tag_management_screen.dart';

/// Warmer Bernstein-Akzent für Daily Info — hebt sie klar vom kühlen Blau der
/// Einträge ab und lässt Raum für spätere Aufgaben/Termine in eigenen Farben.
const Color _kDailyInfoAccent = Color(0xFFD9A441);

/// Grüner Akzent für Aufgaben — „erledigbar/aktiv", klar abgesetzt von
/// Bernstein (Daily Info) und Blau (Einträge). Provisorisch: die App-Theme-
/// Entscheidung steht noch aus.
const Color _kTaskAccent = Color(0xFF5FA86A);

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final List<JournalEntry> _entries = [];

  /// Tagesinfos, die den **heutigen** Tag betreffen (oben im Journal).
  final List<DailyInfo> _todayInfos = [];

  /// Aufgaben, die **heute** im Journal erscheinen (fällig, überfällig oder
  /// ohne Day). Erledigte fallen heraus.
  final List<Task> _todayTasks = [];

  /// **Alle** Aufgaben — Grundlage für Tag-Register, Nutzungszähler und das
  /// Durchschreiben beim Tag-Umbenennen (nicht nur die heute sichtbaren).
  final List<Task> _allTasks = [];

  final TagRegistry _tagRegistry = TagRegistry();
  final JournalRepository _repo = JournalRepository();

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Startsequenz: Einmal-Migration aus shared_preferences (falls nötig),
  /// dann Einträge aus SQLite laden und das Tag-Register aufbauen.
  Future<void> _init() async {
    await _repo.migrateFromPrefsIfNeeded();
    final loaded = await _repo.loadAll();
    final infos = await _repo.dailyInfosForDay(DateTime.now());
    final surfaced = await _repo.surfacedTasksForDay(DateTime.now());
    final allTasks = await _repo.loadAllTasks();
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(loaded);
      _todayInfos
        ..clear()
        ..addAll(infos);
      _todayTasks
        ..clear()
        ..addAll(surfaced);
      _allTasks
        ..clear()
        ..addAll(allTasks);
    });
    _rebuildTagRegistry();
  }

  /// Baut das Tag-Register aus **Einträgen und Aufgaben** auf. Einträge
  /// zuerst (chronologisch, ältester zuerst → erste Schreibweise gewinnt),
  /// danach die Aufgaben — so definieren Einträge die kanonische Schreibweise
  /// und Aufgaben übernehmen sie. Damit erscheinen auch reine Aufgaben-Tags
  /// im Autocomplete und in der Tag-Verwaltung.
  void _rebuildTagRegistry() {
    final lists = <List<String>>[
      ..._entries.reversed.map((e) => e.tags),
      ..._allTasks.map((t) => t.tags),
    ];
    _tagRegistry.rebuildFrom(lists);
  }

  /// Lädt die heute betroffenen Tagesinfos neu (nach jeder Mutation, damit
  /// z.B. eine Info mit Zukunftsdatum korrekt *nicht* heute erscheint).
  Future<void> _reloadTodayInfos() async {
    final infos = await _repo.dailyInfosForDay(DateTime.now());
    if (!mounted) return;
    setState(() {
      _todayInfos
        ..clear()
        ..addAll(infos);
    });
  }

  /// Lädt die Aufgaben neu (nach jeder Mutation): die heute sichtbaren *und*
  /// alle (für Zähler/Register). Baut anschließend das Tag-Register neu auf,
  /// damit ein neuer, nur in einer Aufgabe verwendeter Tag sofort im
  /// Autocomplete und in der Tag-Verwaltung auftaucht.
  Future<void> _reloadTasks() async {
    final surfaced = await _repo.surfacedTasksForDay(DateTime.now());
    final allTasks = await _repo.loadAllTasks();
    if (!mounted) return;
    setState(() {
      _todayTasks
        ..clear()
        ..addAll(surfaced);
      _allTasks
        ..clear()
        ..addAll(allTasks);
    });
    _rebuildTagRegistry();
  }

  /// Öffnet das Text-Eingabe-Sheet.
  /// [existing] == null → Neuer (Text-)Eintrag.
  /// [existing] != null → Bestehenden Text-Eintrag bearbeiten.
  void _openEntrySheet({JournalEntry? existing}) {
    final isEditing = existing != null;
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    final tagController = TextEditingController(
        text: existing != null ? formatTags(existing.tags) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Eintrag bearbeiten' : 'Neuer Eintrag',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: contentController,
                      autofocus: true,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Was ist gerade wichtig?',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  // Stift-Eingabe nur beim Neuanlegen: das native Feld kann
                  // (noch) nicht vorbefüllt werden → Bearbeiten via Tastatur.
                  if (!isEditing) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF4A90D9)),
                      tooltip: 'Mit Stift schreiben (Text)',
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push<NativeTextResult>(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) => NativeTextEntryScreen(
                                knownTags: _tagRegistry.allTags),
                          ),
                        );
                        if (result != null && result.text.isNotEmpty) {
                          _addEntry(result.text, result.tags);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.brush, color: Color(0xFF4A90D9)),
                      tooltip: 'Mit Stift zeichnen (Tinte)',
                      onPressed: () {
                        Navigator.pop(context);
                        _openInkEditorNew();
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TagAutocompleteField(
                controller: tagController,
                knownTags: _tagRegistry.allTags,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;
                    final tags = parseTags(tagController.text);
                    if (existing != null) {
                      _updateEntry(existing.id, content, tags);
                    } else {
                      _addEntry(content, tags);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Speichern',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Tinten-Editor für einen neuen Tinten-Eintrag.
  Future<void> _openInkEditorNew() async {
    final result = await Navigator.push<InkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingScreen(knownTags: _tagRegistry.allTags),
      ),
    );
    if (result != null && result.ink.isNotEmpty) {
      _addInkEntry(result.ink, result.tags);
    }
  }

  /// Tinten-Editor für einen bestehenden Tinten-Eintrag (Striche zurückladen,
  /// weiterschreiben/korrigieren).
  Future<void> _openInkEditorEdit(JournalEntry entry) async {
    final result = await Navigator.push<InkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingScreen(
          initialInk: entry.ink,
          initialTags: entry.tags,
          knownTags: _tagRegistry.allTags,
        ),
      ),
    );
    if (result != null && result.ink.isNotEmpty) {
      _updateInkEntry(entry.id, result.ink, result.tags);
    }
  }

  void _addEntry(String content, List<String> tags) {
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: content,
      tags: canonicalTags,
    );
    setState(() {
      _entries.insert(0, entry);
    });
    _repo.upsert(entry);
  }

  void _addInkEntry(InkData ink, List<String> tags) {
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: '',
      tags: canonicalTags,
      ink: ink,
    );
    setState(() {
      _entries.insert(0, entry);
    });
    _repo.upsert(entry);
  }

  void _updateEntry(String id, String content, List<String> tags) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final updated = _entries[index].copyWith(
      content: content,
      tags: canonicalTags,
    );
    setState(() {
      _entries[index] = updated;
    });
    _repo.upsert(updated);
  }

  void _updateInkEntry(String id, InkData ink, List<String> tags) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final updated = _entries[index].copyWith(
      ink: ink,
      tags: canonicalTags,
    );
    setState(() {
      _entries[index] = updated;
    });
    _repo.upsert(updated);
  }

  // ---------------------------------------------------------------------------
  // Daily Info (Session 15)
  // ---------------------------------------------------------------------------

  /// Öffnet das Daily-Info-Sheet.
  /// [existing] == null → Neue Tagesinfo (Start = heute).
  /// [existing] != null → Bestehende Tagesinfo bearbeiten (mit Löschen).
  void _openDailyInfoSheet({DailyInfo? existing}) {
    final isEditing = existing != null;
    final textController = TextEditingController(text: existing?.text ?? '');
    DateTime startDate =
        DailyInfo.dayOnly(existing?.startDate ?? DateTime.now());
    DateTime? endDate =
        existing?.endDate != null ? DailyInfo.dayOnly(existing!.endDate!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<DateTime?> pickDate(DateTime initial) {
              return showDatePicker(
                context: sheetContext,
                initialDate: initial,
                firstDate: DateTime(DateTime.now().year - 5),
                lastDate: DateTime(DateTime.now().year + 5),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined,
                          color: _kDailyInfoAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Tagesinfo bearbeiten' : 'Neue Tagesinfo',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Was ist an diesem Tag bei Menschen im Umfeld?',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Startdatum
                  _DateRow(
                    label: endDate == null ? 'Datum' : 'Von',
                    value: _formatDate(startDate),
                    onTap: () async {
                      final picked = await pickDate(startDate);
                      if (picked != null) {
                        setSheetState(() {
                          startDate = DailyInfo.dayOnly(picked);
                          // Enddatum nie vor Startdatum.
                          if (endDate != null && endDate!.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Zeitspanne-Umschalter + optionales Enddatum
                  if (endDate == null)
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() => endDate = startDate);
                      },
                      icon: const Icon(Icons.date_range,
                          size: 18, color: _kDailyInfoAccent),
                      label: const Text(
                        'Zeitspanne (bis-Datum)',
                        style: TextStyle(color: _kDailyInfoAccent),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _DateRow(
                            label: 'Bis',
                            value: _formatDate(endDate!),
                            onTap: () async {
                              final picked = await pickDate(endDate!);
                              if (picked != null) {
                                final d = DailyInfo.dayOnly(picked);
                                setSheetState(() {
                                  endDate = d.isBefore(startDate)
                                      ? startDate
                                      : d;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Zeitspanne entfernen',
                          icon: const Icon(Icons.close, color: Colors.white38),
                          onPressed: () {
                            setSheetState(() => endDate = null);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (existing != null)
                        IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _deleteDailyInfo(existing.id);
                          },
                        ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kDailyInfoAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            if (existing != null) {
                              _updateDailyInfo(
                                  existing.id, text, startDate, endDate);
                            } else {
                              _addDailyInfo(text, startDate, endDate);
                            }
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'Speichern',
                            style: TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addDailyInfo(
      String text, DateTime startDate, DateTime? endDate) async {
    final info = DailyInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      startDate: startDate,
      endDate: endDate,
    );
    await _repo.upsertDailyInfo(info);
    await _reloadTodayInfos();
  }

  Future<void> _updateDailyInfo(
      String id, String text, DateTime startDate, DateTime? endDate) async {
    final info = DailyInfo(
      id: id,
      text: text,
      startDate: startDate,
      endDate: endDate,
    );
    await _repo.upsertDailyInfo(info);
    await _reloadTodayInfos();
  }

  Future<void> _deleteDailyInfo(String id) async {
    await _repo.deleteDailyInfo(id);
    await _reloadTodayInfos();
  }

  // ---------------------------------------------------------------------------
  // Aufgaben (Session 16)
  // ---------------------------------------------------------------------------

  /// Öffnet das Aufgaben-Sheet.
  /// [existing] == null → Neue Aufgabe (ohne Day/Uhrzeit).
  /// [existing] != null → Bestehende Aufgabe bearbeiten (mit Löschen).
  void _openTaskSheet({Task? existing}) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final tagController = TextEditingController(
        text: existing != null ? formatTags(existing.tags) : '');
    DateTime? dueDay =
        existing?.dueDay != null ? Task.dayOnly(existing!.dueDay!) : null;
    String? dueTime = existing?.dueTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<DateTime?> pickDay(DateTime initial) {
              return showDatePicker(
                context: sheetContext,
                initialDate: initial,
                firstDate: DateTime(DateTime.now().year - 5),
                lastDate: DateTime(DateTime.now().year + 5),
              );
            }

            Future<TimeOfDay?> pickTime() {
              var initial = const TimeOfDay(hour: 9, minute: 0);
              if (dueTime != null) {
                final parts = dueTime!.split(':');
                initial = TimeOfDay(
                    hour: int.parse(parts[0]), minute: int.parse(parts[1]));
              }
              return showTimePicker(
                  context: sheetContext, initialTime: initial);
            }

            String fmtTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: _kTaskAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Aufgabe bearbeiten' : 'Neue Aufgabe',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Was ist zu tun?',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TagAutocompleteField(
                    controller: tagController,
                    knownTags: _tagRegistry.allTags,
                  ),
                  const SizedBox(height: 16),
                  // Fälligkeits-Day (optional)
                  if (dueDay == null)
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await pickDay(DateTime.now());
                        if (picked != null) {
                          setSheetState(() => dueDay = Task.dayOnly(picked));
                        }
                      },
                      icon: const Icon(Icons.event,
                          size: 18, color: _kTaskAccent),
                      label: const Text(
                        'Fälligkeit (Day)',
                        style: TextStyle(color: _kTaskAccent),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _DateRow(
                            label: 'Fällig',
                            value: _formatDate(dueDay!),
                            onTap: () async {
                              final picked = await pickDay(dueDay!);
                              if (picked != null) {
                                setSheetState(
                                    () => dueDay = Task.dayOnly(picked));
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fälligkeit entfernen',
                          icon: const Icon(Icons.close, color: Colors.white38),
                          onPressed: () => setSheetState(() {
                            dueDay = null;
                            dueTime = null; // Uhrzeit ohne Day ergibt keinen Sinn
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Uhrzeit (optional, nur mit Day)
                    if (dueTime == null)
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await pickTime();
                          if (picked != null) {
                            setSheetState(() => dueTime = fmtTime(picked));
                          }
                        },
                        icon: const Icon(Icons.access_time,
                            size: 18, color: _kTaskAccent),
                        label: const Text(
                          'Uhrzeit',
                          style: TextStyle(color: _kTaskAccent),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _DateRow(
                              label: 'Uhrzeit',
                              value: dueTime!,
                              icon: Icons.access_time,
                              onTap: () async {
                                final picked = await pickTime();
                                if (picked != null) {
                                  setSheetState(
                                      () => dueTime = fmtTime(picked));
                                }
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Uhrzeit entfernen',
                            icon:
                                const Icon(Icons.close, color: Colors.white38),
                            onPressed: () =>
                                setSheetState(() => dueTime = null),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (existing != null)
                        IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _deleteTask(existing.id);
                          },
                        ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kTaskAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;
                            final tags = parseTags(tagController.text);
                            if (existing != null) {
                              _updateTask(
                                  existing, title, dueDay, dueTime, tags);
                            } else {
                              _addTask(title, dueDay, dueTime, tags);
                            }
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'Speichern',
                            style: TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addTask(String title, DateTime? dueDay, String? dueTime,
      List<String> tags) async {
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dueDay: dueDay,
      dueTime: dueTime,
      tags: canonicalTags,
    );
    await _repo.upsertTask(task);
    await _reloadTasks();
  }

  Future<void> _updateTask(Task existing, String title, DateTime? dueDay,
      String? dueTime, List<String> tags) async {
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final updated = Task(
      id: existing.id,
      title: title,
      dueDay: dueDay,
      dueTime: dueTime,
      done: existing.done, // Erledigt-Status wird über die Checkbox gesetzt
      tags: canonicalTags,
    );
    await _repo.upsertTask(updated);
    await _reloadTasks();
  }

  /// Hakt eine Aufgabe ab bzw. wieder auf. Erledigte fallen aus der heutigen
  /// Liste (bleiben in der DB) — sichtbar wird das über [_reloadTasks].
  Future<void> _toggleTaskDone(Task task) async {
    final updated = task.copyWith(done: !task.done);
    await _repo.upsertTask(updated);
    await _reloadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await _repo.deleteTask(id);
    await _reloadTasks();
  }

  /// Nutzungszähler je Tag (Schlüssel = kleingeschrieben). Pro Eintrag zählt
  /// ein Tag höchstens einmal.
  Map<String, int> _tagUsage() {
    final usage = <String, int>{};
    for (final e in _entries) {
      final seen = <String>{};
      for (final t in e.tags) {
        final k = t.toLowerCase();
        if (seen.add(k)) {
          usage[k] = (usage[k] ?? 0) + 1;
        }
      }
    }
    return usage;
  }

  /// Nutzungszähler je Tag über **Aufgaben** (analog [_tagUsage]). Getrennt
  /// gehalten, damit die Tag-Verwaltung Einträge und Aufgaben ausweisen kann.
  Map<String, int> _taskUsage() {
    final usage = <String, int>{};
    for (final task in _allTasks) {
      final seen = <String>{};
      for (final t in task.tags) {
        final k = t.toLowerCase();
        if (seen.add(k)) {
          usage[k] = (usage[k] ?? 0) + 1;
        }
      }
    }
    return usage;
  }

  void _openTagManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagManagementScreen(
          tags: _tagRegistry.allTags,
          usage: _tagUsage(),
          taskUsage: _taskUsage(),
          onRename: _renameTag,
        ),
      ),
    );
  }

  /// Benennt einen Tag in allen Einträgen **und Aufgaben** um (case-insensitiv
  /// erkannt). Trifft die Zielschreibweise einen bestehenden Tag, werden beide
  /// zusammengeführt. Nach dem Umschreiben wird das Register neu aufgebaut und
  /// nur die tatsächlich geänderten Einträge/Aufgaben werden persistiert.
  void _renameTag(String from, String to) {
    final fromKey = from.toLowerCase();
    final cleanTo = to.trim();
    if (cleanTo.isEmpty || cleanTo == from) return;
    final toKey = cleanTo.toLowerCase();

    // Bildet eine Tag-Liste auf die neue Schreibweise ab (Merge-Duplikate
    // fallen weg). Gibt null zurück, wenn sich nichts geändert hat.
    List<String>? remap(List<String> tags) {
      final newTags = <String>[];
      final seen = <String>{};
      var changed = false;
      for (final t in tags) {
        final k = t.toLowerCase();
        final mapped = (k == fromKey || k == toKey) ? cleanTo : t;
        if (mapped != t) changed = true;
        if (seen.add(mapped.toLowerCase())) {
          newTags.add(mapped);
        } else {
          changed = true; // Duplikat (Merge) entfernt
        }
      }
      return changed ? newTags : null;
    }

    final changedEntries = <JournalEntry>[];
    final changedTasks = <Task>[];
    setState(() {
      for (int i = 0; i < _entries.length; i++) {
        final newTags = remap(_entries[i].tags);
        if (newTags != null) {
          final updated = _entries[i].copyWith(tags: newTags);
          _entries[i] = updated;
          changedEntries.add(updated);
        }
      }
      for (int i = 0; i < _allTasks.length; i++) {
        final newTags = remap(_allTasks[i].tags);
        if (newTags != null) {
          final updated = _allTasks[i].copyWith(tags: newTags);
          _allTasks[i] = updated;
          changedTasks.add(updated);
          // Heute sichtbare Kopie derselben Aufgabe mitziehen.
          final si = _todayTasks.indexWhere((x) => x.id == updated.id);
          if (si != -1) _todayTasks[si] = updated;
        }
      }
    });
    // Register neu aufbauen (Einträge + Aufgaben; nach dem Umschreiben ist die
    // neue Schreibweise überall identisch).
    _rebuildTagRegistry();
    if (changedEntries.isNotEmpty) {
      _repo.upsertAll(changedEntries);
    }
    for (final t in changedTasks) {
      _repo.upsertTask(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          _formatDate(DateTime.now()),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sell_outlined, color: Colors.white54),
            tooltip: 'Tags verwalten',
            onPressed: _openTagManagement,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A90D9),
        onPressed: () => _openEntrySheet(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        // +2 für die beiden festen Kopf-Bereiche: Daily Info, dann Aufgaben.
        itemCount: _entries.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _DailyInfoSection(
              infos: _todayInfos,
              onAdd: () => _openDailyInfoSheet(),
              onTapInfo: (info) => _openDailyInfoSheet(existing: info),
            );
          }
          if (index == 1) {
            return _TasksSection(
              tasks: _todayTasks,
              today: DateTime.now(),
              onAdd: () => _openTaskSheet(),
              onToggle: _toggleTaskDone,
              onTapTask: (task) => _openTaskSheet(existing: task),
            );
          }
          final entry = _entries[index - 2];
          return _EntryCard(
            entry: entry,
            onTap: () {
              if (entry.isInk) {
                _openInkEditorEdit(entry);
              } else {
                _openEntrySheet(existing: entry);
              }
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}

/// Farblich abgesetzter Bereich oben im Journal: die heute betroffenen
/// Tagesinfos plus ein dezenter Einstieg zum Anlegen. Klar getrennt von
/// Einträgen (kühles Blau) durch den warmen Bernstein-Akzent.
class _DailyInfoSection extends StatelessWidget {
  final List<DailyInfo> infos;
  final VoidCallback onAdd;
  final void Function(DailyInfo) onTapInfo;

  const _DailyInfoSection({
    required this.infos,
    required this.onAdd,
    required this.onTapInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 14, color: _kDailyInfoAccent),
              const SizedBox(width: 6),
              const Text(
                'TAGESINFO',
                style: TextStyle(
                  color: _kDailyInfoAccent,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add, size: 20, color: _kDailyInfoAccent),
                tooltip: 'Tagesinfo hinzufügen',
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (infos.isEmpty)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kDailyInfoAccent.withOpacity(0.25),
                  ),
                ),
                child: const Text(
                  'Keine Tagesinfo für heute — tippen zum Hinzufügen',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            ...infos.map((info) => _DailyInfoCard(
                  info: info,
                  onTap: () => onTapInfo(info),
                )),
        ],
      ),
    );
  }
}

class _DailyInfoCard extends StatelessWidget {
  final DailyInfo info;
  final VoidCallback onTap;
  const _DailyInfoCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _kDailyInfoAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: _kDailyInfoAccent, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.isRange) ...[
                  Text(
                    _rangeLabel(info),
                    style: const TextStyle(
                      color: _kDailyInfoAccent,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  info.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rangeLabel(DailyInfo info) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    return '${d(info.startDate)} – ${d(info.endDate!)}';
  }
}

/// Farblich abgesetzter Bereich unter Daily Info: die heute erscheinenden
/// Aufgaben plus ein dezenter Einstieg zum Anlegen. Grüner Akzent, klar
/// getrennt von Bernstein (Daily Info) und Blau (Einträge).
class _TasksSection extends StatelessWidget {
  final List<Task> tasks;
  final DateTime today;
  final VoidCallback onAdd;
  final void Function(Task) onToggle;
  final void Function(Task) onTapTask;

  const _TasksSection({
    required this.tasks,
    required this.today,
    required this.onAdd,
    required this.onToggle,
    required this.onTapTask,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: _kTaskAccent),
              const SizedBox(width: 6),
              const Text(
                'AUFGABEN',
                style: TextStyle(
                  color: _kTaskAccent,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add, size: 20, color: _kTaskAccent),
                tooltip: 'Aufgabe hinzufügen',
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kTaskAccent.withOpacity(0.25),
                  ),
                ),
                child: const Text(
                  'Keine offenen Aufgaben — tippen zum Hinzufügen',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            ...tasks.map((task) => _TaskCard(
                  task: task,
                  today: today,
                  onToggle: () => onToggle(task),
                  onTap: () => onTapTask(task),
                )),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  const _TaskCard({
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
        color: _kTaskAccent.withOpacity(0.10),
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
                  color: overdue ? Colors.redAccent : _kTaskAccent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox mit eigenem Tap-Ziel (unabhängig vom Karten-Tap).
                InkResponse(
                  onTap: onToggle,
                  radius: 22,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: Icon(
                      task.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _kTaskAccent,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: TextStyle(
                            color:
                                overdue ? Colors.redAccent : Colors.white38,
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

  /// Meta-Zeile unter dem Titel: „Überfällig · TT.MM. [· HH:mm]" (rot),
  /// sonst die Uhrzeit (falls gesetzt) oder „Ohne Datum". `null` → keine
  /// Zeile (fällig heute ohne Uhrzeit).
  String? _metaLabel(bool overdue) {
    String dm(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    if (overdue) {
      final base = 'Überfällig · ${dm(task.dueDay!)}';
      return task.dueTime != null ? '$base · ${task.dueTime}' : base;
    }
    if (task.dueDay == null) return 'Ohne Datum';
    return task.dueTime; // fällig heute: nur Uhrzeit, sonst null
  }
}

/// Antippbare Datumszeile für das Daily-Info-Sheet.
class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 15, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (entry.isInk) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.brush, size: 12, color: Colors.white24),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (entry.isInk)
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: InkPreviewPainter(entry.ink!),
                      child: const SizedBox.expand(),
                    ),
                  )
                else
                  Text(
                    entry.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children:
                        entry.tags.map((tag) => _TagChip(label: tag)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      ),
    );
  }
}
