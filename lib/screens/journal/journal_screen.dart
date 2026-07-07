import 'package:flutter/material.dart';
import '../../data/journal_repository.dart';
import '../../models/journal_entry.dart';
import '../../models/daily_info.dart';
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

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final List<JournalEntry> _entries = [];

  /// Tagesinfos, die den **heutigen** Tag betreffen (oben im Journal).
  final List<DailyInfo> _todayInfos = [];

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
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(loaded);
      _todayInfos
        ..clear()
        ..addAll(infos);
    });
    // Tag-Register aus den geladenen Einträgen aufbauen.
    // reversed = chronologisch (ältester zuerst) → erste Schreibweise gewinnt.
    _tagRegistry.rebuildFrom(_entries.reversed.map((e) => e.tags));
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

  void _openTagManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagManagementScreen(
          tags: _tagRegistry.allTags,
          usage: _tagUsage(),
          onRename: _renameTag,
        ),
      ),
    );
  }

  /// Benennt einen Tag in allen Einträgen um (case-insensitiv erkannt).
  /// Trifft die Zielschreibweise einen bestehenden Tag, werden beide
  /// zusammengeführt. Nach dem Umschreiben wird das Register neu aufgebaut
  /// und nur die tatsächlich geänderten Einträge werden persistiert.
  void _renameTag(String from, String to) {
    final fromKey = from.toLowerCase();
    final cleanTo = to.trim();
    if (cleanTo.isEmpty || cleanTo == from) return;
    final toKey = cleanTo.toLowerCase();
    final changedEntries = <JournalEntry>[];
    setState(() {
      for (int i = 0; i < _entries.length; i++) {
        final e = _entries[i];
        final newTags = <String>[];
        final seen = <String>{};
        var changed = false;
        for (final t in e.tags) {
          final k = t.toLowerCase();
          final mapped = (k == fromKey || k == toKey) ? cleanTo : t;
          if (mapped != t) changed = true;
          if (seen.add(mapped.toLowerCase())) {
            newTags.add(mapped);
          } else {
            changed = true; // Duplikat (Merge) entfernt
          }
        }
        if (changed) {
          final updated = e.copyWith(tags: newTags);
          _entries[i] = updated;
          changedEntries.add(updated);
        }
      }
    });
    // Register neu aufbauen (chronologisch → erste Schreibweise gewinnt;
    // nach dem Umschreiben ist die neue Schreibweise überall identisch).
    _tagRegistry.rebuildFrom(_entries.reversed.map((e) => e.tags));
    if (changedEntries.isNotEmpty) {
      _repo.upsertAll(changedEntries);
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
        // +1 für den Daily-Info-Bereich als erstes Listenelement.
        itemCount: _entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _DailyInfoSection(
              infos: _todayInfos,
              onAdd: () => _openDailyInfoSheet(),
              onTapInfo: (info) => _openDailyInfoSheet(existing: info),
            );
          }
          final entry = _entries[index - 1];
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

/// Antippbare Datumszeile für das Daily-Info-Sheet.
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
            const Icon(Icons.calendar_today,
                size: 15, color: Colors.white38),
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
