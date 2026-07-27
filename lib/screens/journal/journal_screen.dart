import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/journal_repository.dart';
import '../../models/journal_entry.dart';
import '../../models/daily_info.dart';
import '../../models/task.dart';
import '../../models/ink_data.dart';
import '../../models/calendar_event.dart';
import '../../models/calendar_source.dart';
import '../../screens/text/native_text_entry_screen.dart';
import '../../screens/drawing/drawing_screen.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../../widgets/ink_painter.dart';
import '../../widgets/task_sheet.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/tags/tag_management_screen.dart';
import '../../screens/tasks/task_overview_screen.dart';
import '../../screens/settings/calendar_settings_screen.dart';
import '../../screens/settings/claude_settings_screen.dart';
import '../../screens/review/week_review_screen.dart';

// Farben leben ab dem hellen Theme zentral in AppColors
// (lib/theme/app_colors.dart). Die frueheren provisorischen Akzente
// (Bernstein/Gruen/Violett) sind mit der Design-Entscheidung entfallen: ein
// ruhiges, grau getoentes Tagesinfo-Band, gedaempft-blaue Aufgaben-Kaestchen
// und ein blaues Kalender-Icon tragen jetzt alles ueber das eine Akzentblau.

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

  /// Kalender-Quellen — für das Tag-Register (damit auch ein nur an einem
  /// Kalender hängender Tag im Autocomplete auftaucht) und für die Frage,
  /// ob die TERMINE-Sektion überhaupt angezeigt wird.
  final List<CalendarSource> _calendarSources = [];

  /// Gespiegelte Kalendertermine, die den **heutigen** Tag berühren.
  final List<CalendarEvent> _todayEvents = [];

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
    final calendarSources = await _repo.loadCalendarSources();
    final events = await _repo.calendarEventsForDay(_dayKey(DateTime.now()));
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(loaded);
      _todayEvents
        ..clear()
        ..addAll(events);
      _todayInfos
        ..clear()
        ..addAll(infos);
      _todayTasks
        ..clear()
        ..addAll(surfaced);
      _allTasks
        ..clear()
        ..addAll(allTasks);
      _calendarSources
        ..clear()
        ..addAll(calendarSources);
    });
    _rebuildTagRegistry();
  }

  /// Baut das Tag-Register aus **Einträgen, Aufgaben und Kalender-Quellen** auf.
  /// Einträge zuerst (chronologisch, ältester zuerst → erste Schreibweise
  /// gewinnt), danach Aufgaben und Kalender-Tags — so definieren Einträge die
  /// kanonische Schreibweise und die übrigen übernehmen sie. Damit erscheinen
  /// auch reine Aufgaben- oder Kalender-Tags im Autocomplete und in der
  /// Tag-Verwaltung.
  void _rebuildTagRegistry() {
    final lists = <List<String>>[
      ..._entries.reversed.map((e) => e.tags),
      ..._allTasks.map((t) => t.tags),
      ..._calendarSources.map((c) => c.tags),
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

  /// Lädt die Kalender-Quellen neu (nach Rückkehr aus den Kalender-
  /// Einstellungen) und baut das Tag-Register neu auf — so landen frisch
  /// zugeordnete Kalender-Tags im Autocomplete.
  Future<void> _reloadCalendarSources() async {
    final sources = await _repo.loadCalendarSources();
    // Auch die Termine neu holen: In den Kalender-Einstellungen kann eben
    // synchronisiert oder ein Kalender ab-/zugeschaltet worden sein.
    final events = await _repo.calendarEventsForDay(_dayKey(DateTime.now()));
    if (!mounted) return;
    setState(() {
      _calendarSources
        ..clear()
        ..addAll(sources);
      _todayEvents
        ..clear()
        ..addAll(events);
    });
    _rebuildTagRegistry();
  }

  /// Kalendertag als `yyyy-MM-dd` — dasselbe Format, in dem `calendar_events`
  /// die Tage ablegt.
  static String _dayKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$m-$d';
  }

  /// Öffnet das Text-Eingabe-Sheet.
  /// [existing] == null -> Neuer (Text-)Eintrag.
  /// [existing] != null -> Bestehenden Text-Eintrag bearbeiten.
  void _openEntrySheet({JournalEntry? existing}) {
    final isEditing = existing != null;
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    final tagController = TextEditingController(
        text: existing != null ? formatTags(existing.tags) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
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
                  color: AppColors.iconInactive,
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
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Was ist gerade wichtig?',
                        hintStyle:
                            const TextStyle(color: AppColors.placeholder),
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  // Stift-Eingabe nur beim Neuanlegen: das native Feld kann
                  // (noch) nicht vorbefuellt werden -> Bearbeiten via Tastatur.
                  if (!isEditing) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.accent),
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
                      icon: const Icon(Icons.brush, color: AppColors.accent),
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
              Row(
                children: [
                  // Loeschen nur beim Bearbeiten. Ohne Rueckfrage — bewusst,
                  // damit sich Test-Eintraege zuegig von Hand wegraeumen lassen
                  // (gleicher Schnitt wie im Aufgaben-Sheet).
                  if (isEditing)
                    IconButton(
                      tooltip: 'Loeschen',
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteEntry(existing.id);
                      },
                    ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
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
            ],
          ),
        );
      },
    );
  }

  /// Tinten-Editor für einen neuen Tinten-Eintrag.
  ///
  /// **Ohne** Auswertungs-Callback: Ein Eintrag, den es noch nicht gibt, hat
  /// keine id, an der ein erkannter Text hängen könnte. Erst übernehmen, dann
  /// auswerten.
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
  ///
  /// Reicht einen bereits erkannten Text mit hinein und nimmt über
  /// [_saveInkText] einen neuen entgegen. Die Persistenz bleibt hier beim
  /// Aufrufer — derselbe Schnitt wie beim Aufgaben-Sheet.
  Future<void> _openInkEditorEdit(JournalEntry entry) async {
    final result = await Navigator.push<InkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingScreen(
          initialInk: entry.ink,
          initialTags: entry.tags,
          knownTags: _tagRegistry.allTags,
          initialInkText: entry.inkText,
          initialInkTextAt: entry.inkTextAt,
          onInkTextAccepted: (text) => _saveInkText(entry.id, text),
        ),
      ),
    );
    if (result != null && result.ink.isNotEmpty) {
      _updateInkEntry(entry.id, result.ink, result.tags);
    }
  }

  /// Übernimmt den von Claude erkannten Text zu einem Tinten-Eintrag.
  ///
  /// Schreibt gezielt die beiden Spalten (Schema v6) und zieht den Eintrag in
  /// der Liste nach, damit ein anschließendes Speichern aus dem Editor die
  /// frische Auswertung nicht mit einem veralteten Objekt überschreibt.
  Future<DateTime> _saveInkText(String id, String text) async {
    final at = await _repo.setInkText(id, text);
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1 && mounted) {
      setState(() {
        _entries[index] =
            _entries[index].copyWith(inkText: text, inkTextAt: at);
      });
    }
    return at;
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

  /// Loescht einen Eintrag (getippt wie Tinte) aus Liste und Datenbank.
  /// entry_tags folgen per ON DELETE CASCADE.
  void _deleteEntry(String id) {
    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
    _repo.delete(id);
  }

  /// Langes Druecken auf einen Eintrag -> kurze Rueckfrage, dann loeschen.
  /// Der eine Weg fuer beide Arten: getippte Eintraege oeffnen zwar ein Sheet
  /// mit Loeschen-Knopf, Tinten-Eintraege dagegen den Zeichnen-Editor (noch
  /// ohne Loeschen). Das lange Druecken deckt daher beide ab.
  Future<void> _confirmDeleteEntry(JournalEntry entry) async {
    final preview = entry.isInk
        ? 'Tinten-Eintrag'
        : (entry.content.trim().split('\n').first);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eintrag loeschen?'),
        content: Text(
          preview.isEmpty ? 'Diesen Eintrag loeschen?' : '"$preview"',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );
    if (ok == true) _deleteEntry(entry.id);
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
  /// [existing] == null -> Neue Tagesinfo (Start = heute).
  /// [existing] != null -> Bestehende Tagesinfo bearbeiten (mit Löschen).
  void _openDailyInfoSheet({DailyInfo? existing}) {
    final isEditing = existing != null;
    final textController = TextEditingController(text: existing?.text ?? '');
    DateTime startDate =
        DailyInfo.dayOnly(existing?.startDate ?? DateTime.now());
    DateTime? endDate = existing?.endDate != null
        ? DailyInfo.dayOnly(existing!.endDate!)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
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
                      const Icon(Icons.info_outline,
                          color: AppColors.dailyInfoText, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Tagesinfo bearbeiten' : 'Neue Tagesinfo',
                        style: const TextStyle(
                          color: AppColors.iconInactive,
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
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Was ist an diesem Tag bei Menschen im Umfeld?',
                      hintStyle: const TextStyle(color: AppColors.placeholder),
                      filled: true,
                      fillColor: AppColors.fieldFill,
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
                          size: 18, color: AppColors.accent),
                      label: const Text(
                        'Zeitspanne (bis-Datum)',
                        style: TextStyle(color: AppColors.accent),
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
                                  endDate =
                                      d.isBefore(startDate) ? startDate : d;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Zeitspanne entfernen',
                          icon: const Icon(Icons.close,
                              color: AppColors.iconInactive),
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
                              color: AppColors.danger),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _deleteDailyInfo(existing.id);
                          },
                        ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
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
                              color: Colors.white,
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
  /// Öffnet das wiederverwendbare Aufgaben-Sheet (Journal-Variante).
  /// Persistenz und Neuladen liegen hier: nach Speichern/Löschen wird die
  /// heutige Liste (und alle Aufgaben fürs Register) neu geladen.
  void _openTaskSheet({Task? existing}) {
    showTaskSheet(
      context: context,
      tagRegistry: _tagRegistry,
      existing: existing,
      onSave: (task) async {
        await _repo.upsertTask(task);
        await _reloadTasks();
      },
      onDelete: _deleteTask,
    );
  }

  /// Öffnet die Aufgaben-Übersicht (alle Aufgaben, sortierbar, erledigte
  /// eingeklappt). Beim Zurückkehren wird neu geladen, da dort abgehakt,
  /// bearbeitet oder gelöscht worden sein kann.
  Future<void> _openTaskOverview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskOverviewScreen(
          repo: _repo,
          tagRegistry: _tagRegistry,
        ),
      ),
    );
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

  /// Öffnet die Kalender-Einstellungen und zieht danach Quellen **und**
  /// Termine nach — dort kann synchronisiert oder umgeschaltet worden sein.
  Future<void> _openCalendarSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarSettingsScreen(tagRegistry: _tagRegistry),
      ),
    );
    await _reloadCalendarSources();
  }

  /// Öffnet die Suche und öffnet anschließend den angetippten Eintrag.
  ///
  /// Der Such-Screen liefert nur die Id zurück; geöffnet wird hier — mit
  /// genau den Wegen, die auch das Antippen einer Karte im Journal nimmt.
  /// Damit bleibt die Persistenz an einer Stelle und die Suche ein reiner
  /// Lese-Screen.
  ///
  /// **Bewusst kein Scrollen zur Karte:** Das Journal ist ein
  /// `ListView.builder` mit unterschiedlich hohen Einträgen — eine Position
  /// außerhalb des Sichtbereichs lässt sich darin nicht verlässlich
  /// ansteuern, ohne ein zusätzliches Paket einzuführen. Den Eintrag zu
  /// öffnen ist ohnehin das, was nach einem Treffer gewollt ist: lesen,
  /// gegebenenfalls ergänzen.
  Future<void> _openSearch() async {
    final entryId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (entryId == null || !mounted) return;

    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    final entry = _entries[index];
    if (entry.isInk) {
      await _openInkEditorEdit(entry);
    } else {
      _openEntrySheet(existing: entry);
    }
  }

  /// Öffnet die Claude-Einstellungen (API-Schlüssel). Kein Nachladen nötig —
  /// dort wird nichts verändert, was das Journal anzeigt.
  Future<void> _openClaudeSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClaudeSettingsScreen()),
    );
  }

  /// Öffnet die Wochenauswertung und legt bei „Übernehmen" den Eintrag an.
  ///
  /// Der Screen gibt nur den Text zurück; geschrieben wird hier — über
  /// denselben [_addEntry], den auch das Eintrags-Sheet nimmt. Damit bleibt
  /// die Persistenz an einer Stelle (wie beim Such-Screen), und die
  /// Auswertung landet als ganz gewöhnlicher Eintrag von heute im Journal.
  Future<void> _openWeekReview() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const WeekReviewScreen()),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    _addEntry(text, const ['Wochenauswertung']);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final entryCount = _entries.isEmpty ? 1 : _entries.length;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Oben links: Menue mit den selteneren Aktionen (Tags, Kalender,
        // Wochenauswertung). Design 8.
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: AppColors.iconInactive),
          tooltip: 'Menue',
          color: AppColors.paper,
          onSelected: (value) {
            switch (value) {
              case 'tags':
                _openTagManagement();
                break;
              case 'calendar':
                _openCalendarSettings();
                break;
              case 'week':
                _openWeekReview();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'tags',
              child: Row(children: [
                Icon(Icons.sell_outlined,
                    size: 18, color: AppColors.iconActive),
                SizedBox(width: 12),
                Text('Tags verwalten',
                    style: TextStyle(color: AppColors.iconActive)),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'calendar',
              child: Row(children: [
                Icon(Icons.event_outlined,
                    size: 18, color: AppColors.iconActive),
                SizedBox(width: 12),
                Text('Google Calendar',
                    style: TextStyle(color: AppColors.iconActive)),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'week',
              child: Row(children: [
                Icon(Icons.date_range,
                    size: 18, color: AppColors.iconActive),
                SizedBox(width: 12),
                Text('Wochenauswertung',
                    style: TextStyle(color: AppColors.iconActive)),
              ]),
            ),
          ],
        ),
        // Oben rechts: das Funkel-Symbol (Claude). Design 8.
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined,
                color: AppColors.accent),
            tooltip: 'Claude',
            onPressed: _openClaudeSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        // Feste Kopf-Bereiche (4): Datumskopf, Tagesinfo, Termine, Aufgaben.
        // Danach die Eintraege - oder, solange keiner da ist, die leise
        // Einladung zum Schreiben (leerer Heute-Zustand, Design 6).
        itemCount: 4 + entryCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _DateHeader(
              weekday: _weekdayName(today),
              date: _formatDate(today),
            );
          }
          if (index == 1) {
            return _DailyInfoSection(
              infos: _todayInfos,
              onAdd: () => _openDailyInfoSheet(),
              onTapInfo: (info) => _openDailyInfoSheet(existing: info),
            );
          }
          if (index == 2) {
            return _EventsSection(
              events: _todayEvents,
              day: _dayKey(today),
              // Ohne aktivierten Kalender bleibt die Sektion unsichtbar.
              visible: _calendarSources.any((c) => c.enabled),
              onOpenSettings: _openCalendarSettings,
            );
          }
          if (index == 3) {
            return _TasksSection(
              tasks: _todayTasks,
              today: today,
              onAdd: () => _openTaskSheet(),
              onToggle: _toggleTaskDone,
              onTapTask: (task) => _openTaskSheet(existing: task),
              onOpenOverview: _openTaskOverview,
            );
          }
          if (_entries.isEmpty) {
            return _EmptyEntryInvitation(onTap: () => _openEntrySheet());
          }
          final entry = _entries[index - 4];
          return _EntryCard(
            entry: entry,
            onTap: () {
              if (entry.isInk) {
                _openInkEditorEdit(entry);
              } else {
                _openEntrySheet(existing: entry);
              }
            },
            onLongPress: () => _confirmDeleteEntry(entry),
          );
        },
      ),
      bottomNavigationBar: _BottomBar(
        onJournal: () {},
        onSearch: _openSearch,
        onTasks: _openTaskOverview,
        onNewEntry: () => _openEntrySheet(),
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

/// Zweizeiliger Datumskopf: klein und grau der Wochentag, darunter gross das
/// Datum. Der ruhige Anker des heutigen Tages (Design 3/4).
class _DateHeader extends StatelessWidget {
  final String weekday;
  final String date;
  const _DateHeader({required this.weekday, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weekday,
            style: const TextStyle(
              color: AppColors.weekday,
              fontSize: 12,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: const TextStyle(
              color: AppColors.dateLarge,
              fontSize: 30,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tagesinfo-Band oben im Journal: was fuer den ganzen Tag gilt. Ruhige, grau
/// getoente Flaeche mit Info-Icon; klar von den Eintraegen abgesetzt.
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
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.dailyInfoText),
              const SizedBox(width: 6),
              const Text(
                'TAGESINFO',
                style: TextStyle(
                  color: AppColors.dailyInfoText,
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
                icon: const Icon(Icons.add,
                    size: 20, color: AppColors.dailyInfoText),
                tooltip: 'Tagesinfo hinzufuegen',
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
                  color: AppColors.dailyInfoBand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Keine Tagesinfo fuer heute - tippen zum Hinzufuegen',
                  style: TextStyle(color: AppColors.placeholder, fontSize: 13),
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
        color: AppColors.dailyInfoBand,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.isRange) ...[
                  Text(
                    _rangeLabel(info),
                    style: const TextStyle(
                      color: AppColors.dailyInfoText,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
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
          ),
        ),
      ),
    );
  }

  String _rangeLabel(DailyInfo info) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    return '${d(info.startDate)} - ${d(info.endDate!)}';
  }
}

/// Die heute anstehenden Kalendertermine, gespiegelt aus Google Calendar.
///
/// Bewusst nicht editierbar: Termine gehoeren dem Kalender, nicht dem Journal.
/// Kein Plus, kein Bearbeiten-Sheet - nur der Weg in die Einstellungen. Die
/// Sektion verschwindet ganz, solange kein Kalender aktiviert ist ([visible]).
class _EventsSection extends StatelessWidget {
  final List<CalendarEvent> events;

  /// Der dargestellte Kalendertag als `yyyy-MM-dd`.
  final String day;

  final bool visible;
  final VoidCallback onOpenSettings;

  const _EventsSection({
    required this.events,
    required this.day,
    required this.visible,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 14, color: AppColors.iconInactive),
              const SizedBox(width: 6),
              const Text(
                'TERMINE',
                style: TextStyle(
                  color: AppColors.iconInactive,
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
                icon: const Icon(Icons.tune,
                    size: 18, color: AppColors.iconInactive),
                tooltip: 'Kalender und Sync',
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Text(
                'Heute keine Termine',
                style: TextStyle(color: AppColors.placeholder, fontSize: 13),
              ),
            )
          else
            ...events.map((event) => _EventCard(event: event, day: day)),
        ],
      ),
    );
  }
}

/// Eine Terminkarte: blaues Kalender-Icon, Zeit, Titel, optional Ort, Tags.
class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final String day;

  const _EventCard({required this.event, required this.day});

  @override
  Widget build(BuildContext context) {
    final timeLabel = event.timeLabelForDay(day);
    final label = timeLabel ?? 'ganztaegig';
    final location = event.location;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                if (event.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in event.tags) _TagChip(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Die heute erscheinenden Aufgaben plus ein dezenter Einstieg zum Anlegen.
class _TasksSection extends StatelessWidget {
  final List<Task> tasks;
  final DateTime today;
  final VoidCallback onAdd;
  final void Function(Task) onToggle;
  final void Function(Task) onTapTask;
  final VoidCallback onOpenOverview;

  const _TasksSection({
    required this.tasks,
    required this.today,
    required this.onAdd,
    required this.onToggle,
    required this.onTapTask,
    required this.onOpenOverview,
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
              const Icon(Icons.check_box_outlined,
                  size: 14, color: AppColors.iconInactive),
              const SizedBox(width: 6),
              const Text(
                'AUFGABEN',
                style: TextStyle(
                  color: AppColors.iconInactive,
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
                icon: const Icon(Icons.checklist,
                    size: 20, color: AppColors.iconInactive),
                tooltip: 'Alle Aufgaben',
                onPressed: onOpenOverview,
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add,
                    size: 20, color: AppColors.iconInactive),
                tooltip: 'Aufgabe hinzufuegen',
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
                child: const Text(
                  'Keine offenen Aufgaben - tippen zum Hinzufuegen',
                  style: TextStyle(color: AppColors.placeholder, fontSize: 13),
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

/// Eine Aufgabe im Journal: offenes Kaestchen (gedaempftes Blau), erledigt als
/// gefuelltes Kaestchen mit Haekchen und durchgestrichenem, grauem Text.
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
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkResponse(
                onTap: onToggle,
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 1),
                  child: Icon(
                    task.done
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: task.done
                        ? AppColors.accent
                        : (overdue
                            ? AppColors.danger
                            : AppColors.taskOpenBox),
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
                        color: task.done
                            ? AppColors.taskDoneText
                            : AppColors.text,
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
                          color: overdue
                              ? AppColors.danger
                              : AppColors.iconInactive,
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
    );
  }

  /// Meta-Zeile unter dem Titel: "Ueberfaellig ..." (rot), sonst Uhrzeit oder
  /// "Ohne Datum". `null` -> keine Zeile (faellig heute ohne Uhrzeit).
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

/// Leerer Heute-Zustand (Design 6): ein wartender Punkt, ein blauer Cursor und
/// ein leiser Platzhalter laden zum Schreiben ein. Antippen oeffnet das
/// Eintrags-Sheet.
class _EmptyEntryInvitation extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyEntryInvitation({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: AppColors.bullet,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              color: AppColors.accent,
            ),
            const Text(
              'Tippen oder mit dem Stift schreiben ...',
              style: TextStyle(color: AppColors.placeholder, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Antippbare Datumszeile fuer das Daily-Info-Sheet.
class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.iconInactive, fontSize: 13),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today,
                size: 15, color: AppColors.iconInactive),
          ],
        ),
      ),
    );
  }
}

/// Ein Journal-Eintrag: getippt in neutralem Dunkel, handschriftlich als echte
/// Tinte (dunkel auf hell). Rahmenlos auf Papier — Text und Tinte stehen frei.
class _EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: AppColors.placeholder,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (entry.isInk) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.brush,
                          size: 12, color: AppColors.placeholder),
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
                      painter:
                          InkPreviewPainter(entry.ink!, color: AppColors.ink),
                      child: const SizedBox.expand(),
                    ),
                  )
                else
                  Text(
                    entry.content,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
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

/// Tag-Chip im Akzentblau. Der Einstieg in die Tag-Ansicht (Antippen) kommt in
/// einem eigenen Schritt; hier vorerst reine Darstellung.
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tagChipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Untere Icon-Leiste (Design 8): Journal (heute), Suche, Aufgaben, Neuer
/// Eintrag. Das Journal-Icon steht als aktiver Tab im Akzentblau, die uebrigen
/// ruhig in Grau. Vorerst fest unten - die Praxis entscheidet ueber die
/// endgueltige Position (Design 9).
class _BottomBar extends StatelessWidget {
  final VoidCallback onJournal;
  final VoidCallback onSearch;
  final VoidCallback onTasks;
  final VoidCallback onNewEntry;
  const _BottomBar({
    required this.onJournal,
    required this.onSearch,
    required this.onTasks,
    required this.onNewEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomBarButton(
                icon: Icons.menu_book_outlined,
                tooltip: 'Journal',
                active: true,
                onTap: onJournal,
              ),
              _BottomBarButton(
                icon: Icons.search,
                tooltip: 'Suchen',
                onTap: onSearch,
              ),
              _BottomBarButton(
                icon: Icons.check_box_outlined,
                tooltip: 'Aufgaben',
                onTap: onTasks,
              ),
              _BottomBarButton(
                icon: Icons.edit_outlined,
                tooltip: 'Neuer Eintrag',
                onTap: onNewEntry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _BottomBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon,
          color: active ? AppColors.accent : AppColors.iconInactive),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
