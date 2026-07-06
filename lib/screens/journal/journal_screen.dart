import 'package:flutter/material.dart';
import '../../data/journal_repository.dart';
import '../../models/journal_entry.dart';
import '../../models/ink_data.dart';
import '../../screens/text/native_text_entry_screen.dart';
import '../../screens/drawing/drawing_screen.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../../widgets/ink_painter.dart';
import '../../screens/tags/tag_management_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final List<JournalEntry> _entries = [];
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
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(loaded);
    });
    // Tag-Register aus den geladenen Einträgen aufbauen.
    // reversed = chronologisch (ältester zuerst) → erste Schreibweise gewinnt.
    _tagRegistry.rebuildFrom(_entries.reversed.map((e) => e.tags));
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
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
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
