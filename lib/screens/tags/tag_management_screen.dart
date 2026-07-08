import 'package:flutter/material.dart';

/// Tag-Verwaltung: zeigt alle bekannten Tags mit Nutzungszähler und erlaubt
/// das **Umbenennen** (kanonische Schreibweise selbst festlegen).
///
/// Trifft die neue Schreibweise case-insensitiv einen bestehenden Tag,
/// werden beide zusammengeführt (Merge) — das ist der saubere Hebel gegen
/// die reihenfolge-abhängige Kanonisierung aus dem Tag-Register.
///
/// Das eigentliche Umschreiben der Einträge passiert in [onRename] (im
/// JournalScreen); dieser Screen hält nur eine Anzeige-Kopie aktuell.
class TagManagementScreen extends StatefulWidget {
  final List<String> tags;

  /// Nutzungszähler je Tag, Schlüssel = kleingeschriebener Tag.
  final Map<String, int> usage;

  /// Nutzungszähler je Tag über Aufgaben (analog [usage]).
  final Map<String, int> taskUsage;

  /// Wird mit (alteSchreibweise, neueSchreibweise) aufgerufen.
  final void Function(String from, String to) onRename;

  const TagManagementScreen({
    super.key,
    required this.tags,
    required this.usage,
    this.taskUsage = const {},
    required this.onRename,
  });

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  late List<String> _tags;
  late Map<String, int> _usage;
  late Map<String, int> _taskUsage;

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.tags);
    _usage = Map<String, int>.from(widget.usage);
    _taskUsage = Map<String, int>.from(widget.taskUsage);
  }

  int _countFor(String tag) => _usage[tag.toLowerCase()] ?? 0;
  int _taskCountFor(String tag) => _taskUsage[tag.toLowerCase()] ?? 0;

  /// Untertitel je Tag: Einträge und (falls vorhanden) Aufgaben getrennt.
  /// Ein reiner Aufgaben-Tag zeigt nur „N Aufgaben", ein reiner Eintrags-Tag
  /// nur „N Einträge".
  String _subtitleFor(String tag) {
    final e = _countFor(tag);
    final t = _taskCountFor(tag);
    final parts = <String>[];
    if (e > 0 || t == 0) {
      parts.add(e == 1 ? '1 Eintrag' : '$e Einträge');
    }
    if (t > 0) {
      parts.add(t == 1 ? '1 Aufgabe' : '$t Aufgaben');
    }
    return parts.join(' · ');
  }

  Future<void> _rename(String tag) async {
    final controller = TextEditingController(text: tag);
    final newTag = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Tag umbenennen',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              prefixText: '#',
              prefixStyle: const TextStyle(color: Colors.white54, fontSize: 16),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Umbenennen',
                  style: TextStyle(color: Color(0xFF4A90D9))),
            ),
          ],
        );
      },
    );

    if (newTag == null) return;
    // Eingabe säubern: führendes '#' weg, trimmen, erstes Wort nehmen.
    final cleaned = newTag.replaceAll('#', '').trim().split(RegExp(r'\s+')).first;
    if (cleaned.isEmpty || cleaned == tag) return;

    widget.onRename(tag, cleaned);

    // Anzeige-Kopie nachziehen: alten Tag entfernen, Zähler auf den neuen
    // (kleingeschriebenen) Schlüssel zusammenlegen, neu sortieren.
    setState(() {
      final fromKey = tag.toLowerCase();
      final toKey = cleaned.toLowerCase();
      final movedCount = _usage.remove(fromKey) ?? 0;
      _usage[toKey] = (_usage[toKey] ?? 0) + movedCount;

      final movedTasks = _taskUsage.remove(fromKey) ?? 0;
      _taskUsage[toKey] = (_taskUsage[toKey] ?? 0) + movedTasks;

      _tags.removeWhere((t) => t.toLowerCase() == fromKey);
      if (!_tags.any((t) => t.toLowerCase() == toKey)) {
        _tags.add(cleaned);
      } else {
        // Merge-Ziel existiert: auf die neue Schreibweise vereinheitlichen.
        _tags = _tags
            .map((t) => t.toLowerCase() == toKey ? cleaned : t)
            .toSet()
            .toList();
      }
      _tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Tags verwalten',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
      body: _tags.isEmpty
          ? const Center(
              child: Text(
                'Noch keine Tags',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _tags.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final tag = _tags[index];
                return ListTile(
                  title: Text(
                    '#$tag',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  subtitle: Text(
                    _subtitleFor(tag),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.white38),
                  onTap: () => _rename(tag),
                );
              },
            ),
    );
  }
}