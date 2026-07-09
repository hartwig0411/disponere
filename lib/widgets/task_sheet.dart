import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/tag_parser.dart';
import '../utils/tag_registry.dart';
import 'tag_autocomplete_field.dart';

/// Grüner Akzent für Aufgaben — identisch zum Journal (`_kTaskAccent` dort).
/// Provisorisch, solange die App-Theme-Entscheidung aussteht.
const Color _kTaskAccent = Color(0xFF5FA86A);

/// Wiederverwendbares Bottom-Sheet zum Erstellen/Bearbeiten einer [Task].
///
/// Bewusst OHNE eigene Persistenz: Speichern und Neuladen liegen beim Aufrufer
/// (über [onSave]/[onDelete]) — so nutzen Journal **und** Aufgaben-Übersicht
/// dieselbe UI und aktualisieren jeweils ihren eigenen Zustand.
///
/// [onSave] erhält eine fertig gebaute Task: bei „neu" mit frischer id, bei
/// „bearbeiten" mit übernommener id und **erhaltenem** `done`-Status. Der
/// Erledigt-Status wird ausschließlich über die Checkbox gesetzt, nie hier.
/// Tags werden über die [tagRegistry] kanonisiert.
///
/// [onDelete] ist optional; nur wenn gesetzt **und** [existing] != null wird
/// der Löschen-Knopf gezeigt.
Future<void> showTaskSheet({
  required BuildContext context,
  required TagRegistry tagRegistry,
  required Future<void> Function(Task task) onSave,
  Task? existing,
  Future<void> Function(String id)? onDelete,
}) {
  final isEditing = existing != null;
  final titleController = TextEditingController(text: existing?.title ?? '');
  final tagController = TextEditingController(
      text: existing != null ? formatTags(existing.tags) : '');
  DateTime? dueDay =
      existing?.dueDay != null ? Task.dayOnly(existing!.dueDay!) : null;
  String? dueTime = existing?.dueTime;

  return showModalBottomSheet(
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
            return showTimePicker(context: sheetContext, initialTime: initial);
          }

          String fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:'
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
                  knownTags: tagRegistry.allTags,
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
                    icon:
                        const Icon(Icons.event, size: 18, color: _kTaskAccent),
                    label: const Text(
                      'Fälligkeit (Day)',
                      style: TextStyle(color: _kTaskAccent),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SheetRow(
                          label: 'Fällig',
                          value: _formatFullDate(dueDay!),
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
                          child: _SheetRow(
                            label: 'Uhrzeit',
                            value: dueTime!,
                            icon: Icons.access_time,
                            onTap: () async {
                              final picked = await pickTime();
                              if (picked != null) {
                                setSheetState(() => dueTime = fmtTime(picked));
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Uhrzeit entfernen',
                          icon: const Icon(Icons.close, color: Colors.white38),
                          onPressed: () =>
                              setSheetState(() => dueTime = null),
                        ),
                      ],
                    ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEditing && onDelete != null)
                      IconButton(
                        tooltip: 'Löschen',
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          onDelete(existing.id);
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
                          final tags = tagRegistry
                              .canonicalizeAll(parseTags(tagController.text));
                          final task = isEditing
                              ? Task(
                                  id: existing.id,
                                  title: title,
                                  dueDay: dueDay,
                                  dueTime: dueTime,
                                  // Erledigt-Status bleibt erhalten — wird nur
                                  // über die Checkbox verändert.
                                  done: existing.done,
                                  tags: tags,
                                )
                              : Task(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  title: title,
                                  dueDay: dueDay,
                                  dueTime: dueTime,
                                  tags: tags,
                                );
                          Navigator.pop(sheetContext);
                          onSave(task);
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

/// „8. Juli 2026" — ausgeschriebenes Datum für die Fällig-Zeile.
String _formatFullDate(DateTime date) {
  const months = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
  ];
  return '${date.day}. ${months[date.month - 1]} ${date.year}';
}

/// Antippbare Wert-Zeile im Sheet (Fällig-Day bzw. Uhrzeit).
class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;
  const _SheetRow({
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
