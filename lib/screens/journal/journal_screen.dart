import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/journal_entry.dart';
import '../../screens/text/native_text_entry_screen.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final List<JournalEntry> _entries = [];
  final TagRegistry _tagRegistry = TagRegistry();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('entries') ?? [];
    final loaded = raw.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return JournalEntry(
        id: map['id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        content: map['content'] as String,
        tags: List<String>.from(map['tags'] as List),
      );
    }).toList();
    setState(() {
      _entries.addAll(loaded);
    });
    // Tag-Register aus den geladenen Einträgen aufbauen.
    // reversed = chronologisch (ältester zuerst) → erste Schreibweise gewinnt.
    _tagRegistry.rebuildFrom(_entries.reversed.map((e) => e.tags));
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _entries.map((e) => jsonEncode({
      'id': e.id,
      'timestamp': e.timestamp.toIso8601String(),
      'content': e.content,
      'tags': e.tags,
    })).toList();
    await prefs.setStringList('entries', raw);
  }

  /// Öffnet das Eingabe-Sheet.
  /// [existing] == null → Neuer Eintrag.
  /// [existing] != null → Bestehenden Eintrag bearbeiten (Inhalt + Tags).
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
                      tooltip: 'Mit Stift schreiben',
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push<NativeTextResult>(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NativeTextEntryScreen(knownTags: _tagRegistry.allTags),
                          ),
                        );
                        if (result != null && result.text.isNotEmpty) {
                          _addEntry(result.text, result.tags);
                        }
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
    _saveEntries();
  }

  void _updateEntry(String id, String content, List<String> tags) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    setState(() {
      _entries[index] = _entries[index].copyWith(
        content: content,
        tags: canonicalTags,
      );
    });
    _saveEntries();
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
            onTap: () => _openEntrySheet(existing: entry),
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
                Text(
                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
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