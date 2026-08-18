import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/journal_entry.dart';
import '../models/task.dart';

/// Brücke Eintrag ↔ Aufgabe (Session 53, Anforderungen v6.4).
///
/// Ein Gedanke, der als Eintrag notiert wurde, soll zur **Aufgabe** werden — und
/// eine Aufgabe soll als vorbereiteter Inhalt an einem künftigen Tag
/// **aufsurfen**. Beide Richtungen sind bewusst *kein* leeres Formular: der Knopf
/// öffnet ein knappes Sheet mit vorbefülltem, **kürzbarem** Titel/Inhalt und
/// einer Datumszeile — „ein Knopf, dann das Datum", aber man sieht und kürzt,
/// was entsteht.
///
/// **Verbindung = geteilter Tag (Option A).** Das neue Objekt erbt die Tags der
/// Quelle; die Verbindung *ist* der Tag (Perlenkette wie gebaut), danach leben
/// beide eigenständig. Bewusst keine harte DB-Kopplung: Aufgabe (abhakbar) und
/// Eintrag (nicht) haben verschiedene Lebenszyklen. Die Quelle bleibt in beiden
/// Richtungen unverändert.
///
/// Die geerbten Tags erscheinen als **schreibgeschützte Chips** — man sieht die
/// entstehende Perlenkette, ändert sie hier aber nicht (das gehört ins jeweilige
/// Bearbeiten-Sheet). Persistenz und Neuladen liegen beim Aufrufer (über
/// [onCreate]); so nutzen Journal und Aufgaben-Übersicht dieselbe UI.

const Color _kAccent = AppColors.accent;

/// **Eintrag → Aufgabe.** Titel aus [JournalEntry.content] (bei Tinten-Eintrag
/// aus [JournalEntry.inkText]); geerbte Tags; das eingegebene Datum wird zum
/// **Fälligkeits-Day** der neuen Aufgabe (nur Tag, keine Uhrzeit — `dueTime`
/// entfällt). Die Fälligkeit ist hier **optional und entfernbar**: eine Aufgabe
/// ohne Day ist zulässig (sie bleibt offen, bis sie erledigt ist). Vorbelegt mit
/// dem Anzeige-Tag des Eintrags, falls datiert, sonst mit heute.
///
/// [onCreate] erhält eine fertig gebaute [Task] mit frischer id; der Aufrufer
/// persistiert (`upsertTask`) und lädt seine Liste neu.
Future<void> showEntryToTaskSheet({
  required BuildContext context,
  required JournalEntry entry,
  required Future<void> Function(Task task) onCreate,
}) {
  final seedTitle = entry.content.trim().isNotEmpty
      ? entry.content.trim()
      : (entry.inkText?.trim() ?? '');
  final titleController = TextEditingController(text: seedTitle);
  final tags = entry.tags; // geerbt, bereits kanonisch
  // Vorbelegung: Anzeige-Tag des Eintrags (falls datiert), sonst heute.
  DateTime? dueDay = entry.isDated
      ? Task.dayOnly(entry.displayDay!)
      : Task.dayOnly(DateTime.now());

  return _showBridgeSheet(
    context: context,
    headerIcon: Icons.check_circle_outline,
    headerLabel: 'ZU AUFGABE MACHEN',
    fieldHint: 'Was ist zu tun?',
    controller: titleController,
    tags: tags,
    initialDay: dueDay,
    dateRequired: false, // Aufgabe ohne Fälligkeit ist zulässig
    onSubmit: (day) {
      final title = titleController.text.trim();
      if (title.isEmpty) return false;
      final task = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        dueDay: day, // kann null sein (entfernte Fälligkeit)
        tags: tags,
      );
      onCreate(task);
      return true;
    },
  );
}

/// **Aufgabe → Eintrag.** Inhalt aus [Task.title]; geerbte Tags; das eingegebene
/// Datum wird zum **Anzeige-Tag** des neuen Eintrags — er ist damit ein
/// *datierter Eintrag* (Session 51): er surft nur am gewählten Tag auf und
/// wartet bis dahin still. Deshalb ist das Datum hier **erforderlich** (ohne
/// Anzeige-Tag wäre es ein gewöhnlicher Eintrag von heute — den kann man direkt
/// tippen). Vorbelegt mit dem Fälligkeits-Day der Aufgabe, falls vorhanden, sonst
/// mit heute. `done`/`dueTime` der Aufgabe fallen weg; Bilder bleiben an der
/// Quelle (der geteilte Tag hält sie über die Tag-Ansicht erreichbar).
///
/// [onCreate] erhält Inhalt, geerbte Tags und den Anzeige-Tag (date-only,
/// Konstruktorform — DST-sicher); der Aufrufer legt den Eintrag an.
Future<void> showTaskToEntrySheet({
  required BuildContext context,
  required Task task,
  required Future<void> Function(
          String content, List<String> tags, DateTime displayDay)
      onCreate,
}) {
  final contentController = TextEditingController(text: task.title.trim());
  final tags = task.tags; // geerbt, bereits kanonisch
  DateTime displayDay =
      task.hasDay ? Task.dayOnly(task.dueDay!) : Task.dayOnly(DateTime.now());

  return _showBridgeSheet(
    context: context,
    headerIcon: Icons.event_available,
    headerLabel: 'ALS EINTRAG VORMERKEN',
    fieldHint: 'Inhalt des Eintrags …',
    controller: contentController,
    tags: tags,
    initialDay: displayDay,
    dateRequired: true, // datierter Eintrag braucht seinen Tag
    onSubmit: (day) {
      final content = contentController.text.trim();
      if (content.isEmpty || day == null) return false;
      onCreate(content, tags, day);
      return true;
    },
  );
}

// ---------------------------------------------------------------------------
// Gemeinsames Sheet
// ---------------------------------------------------------------------------

/// Das eine winzige Sheet für beide Richtungen. [onSubmit] baut das Zielobjekt
/// und meldet über den Rückgabewert, ob gespeichert wurde (false → Sheet bleibt
/// offen, z.B. leeres Feld). Bei `true` schließt das Sheet.
Future<void> _showBridgeSheet({
  required BuildContext context,
  required IconData headerIcon,
  required String headerLabel,
  required String fieldHint,
  required TextEditingController controller,
  required List<String> tags,
  required DateTime? initialDay,
  required bool dateRequired,
  required bool Function(DateTime? day) onSubmit,
}) {
  DateTime? day = initialDay;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<DateTime?> pickDay(DateTime initial) {
            final first = DateTime(DateTime.now().year - 5);
            final last = DateTime(DateTime.now().year + 5);
            // initialDate muss in [first, last] liegen — eine weit zurück-
            // liegende Quelle (z.B. Aufgabe aus der Vergangenheit) sonst
            // Assertion-Absturz. Deshalb klammern.
            var seed = initial;
            if (seed.isBefore(first)) seed = first;
            if (seed.isAfter(last)) seed = last;
            return showDatePicker(
              context: sheetContext,
              initialDate: seed,
              firstDate: first,
              lastDate: last,
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
                    Icon(headerIcon, color: _kAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      headerLabel,
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
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  style: const TextStyle(color: AppColors.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: fieldHint,
                    hintStyle: const TextStyle(color: AppColors.placeholder),
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                // Geerbte Tags: schreibgeschützt, zeigen die entstehende
                // Perlenkette. Leere Liste → nichts anzeigen.
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        tags.map((t) => _ReadOnlyTagChip(label: t)).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                // Datumszeile
                if (day == null)
                  // Nur erreichbar, wenn nicht erforderlich (dann entfernbar).
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await pickDay(DateTime.now());
                      if (picked != null) {
                        setSheetState(() => day = Task.dayOnly(picked));
                      }
                    },
                    icon: const Icon(Icons.event, size: 18, color: _kAccent),
                    label: const Text(
                      'Datum',
                      style: TextStyle(color: _kAccent),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _SheetRow(
                          label: dateRequired ? 'Am Tag' : 'Fällig',
                          value: _formatFullDate(day!),
                          onTap: () async {
                            final picked = await pickDay(day!);
                            if (picked != null) {
                              setSheetState(() => day = Task.dayOnly(picked));
                            }
                          },
                        ),
                      ),
                      if (!dateRequired)
                        IconButton(
                          tooltip: 'Datum entfernen',
                          icon: const Icon(Icons.close,
                              color: AppColors.iconInactive),
                          onPressed: () => setSheetState(() => day = null),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final saved = onSubmit(day);
                      if (saved) Navigator.pop(sheetContext);
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
          );
        },
      );
    },
  );
}

/// „8. Juli 2026" — ausgeschriebenes Datum für die Datumszeile (wie im
/// Aufgaben-Sheet).
String _formatFullDate(DateTime date) {
  const months = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
  ];
  return '${date.day}. ${months[date.month - 1]} ${date.year}';
}

/// Schreibgeschützter Tag-Chip: gleiche Optik wie [TagChip] (tagChipBg +
/// Akzent), aber **ohne** Navigation — in einem Modal-Sheet würde ein Tippen
/// überraschend einen Screen darüber schieben. Hier zeigt der Chip nur die
/// geerbte Verbindung.
class _ReadOnlyTagChip extends StatelessWidget {
  final String label;
  const _ReadOnlyTagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tagChipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

/// Antippbare Wert-Zeile im Sheet (das Datum) — dieselbe Optik wie im
/// Aufgaben-Sheet.
class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SheetRow({
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
