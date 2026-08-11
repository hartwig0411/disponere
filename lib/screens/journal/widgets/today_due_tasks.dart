import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/task.dart';

/// Heute fällige, offene Aufgaben im Heute-Block (Design 4a, präzisiert v6.1).
///
/// Die **einzige zugelassene Ergänzung** der freien Schreibfläche: offene
/// Aufgaben, deren Fälligkeitstag GENAU heute ist. Überfällige Aufgaben und
/// solche ganz ohne Datum bleiben bewusst draußen (nur im Heute-Panel) — der
/// Aufrufer (`journal_screen`) filtert das bereits; dieses Widget rendert nur,
/// was es bekommt, und zeigt sich gar nicht, wenn nichts fällig ist.
///
/// Darstellung als **kompakter Einzeiler** (bewusst platzsparend, damit die
/// Aufgaben die Schreibfläche nicht zuwachsen):
///
///   ☐  08:00 - #Disponere-Versio - Plaud & Claude verbinden. https://…
///
/// Eine einzige Zeile, **kein** Umbruch — zu Langes wird am Screenrand mit „…"
/// abgeschnitten. Segmente (Uhrzeit · Tags · Titel) mit „ - " verbunden; fehlt
/// eines, entfällt es samt Trenner. Der `#Tag` steht im Akzentblau (reines
/// Inline-Wort, kein Chip, nicht antippbar).
///
/// Interaktion:
///  - **Checkbox** hakt ab ([onToggleTask], dieselbe Mechanik wie im Panel):
///    der Erledigt-Zustand wird lokal umgeschaltet, wodurch die Aufgabe durch
///    den `!done`-Filter des Aufrufers **sofort** aus dem Block fällt (die
///    Schreibfläche bleibt sauber; im Panel bleibt sie durchgestrichen sichtbar).
///  - **Antippen der Zeile** öffnet die Aufgabe ([onOpenTask]) — der Weg, um den
///    abgeschnittenen Rest zu sehen bzw. zu bearbeiten oder zu löschen.
class TodayDueTasks extends StatelessWidget {
  /// Bereits gefiltert: offen, mit Fälligkeitstag == heute.
  final List<Task> tasks;

  /// Hakt eine Aufgabe ab/auf (Journal-Screen: `_togglePanelTask`).
  final void Function(Task) onToggleTask;

  /// Öffnet die Aufgabe zum Ansehen/Bearbeiten (Journal-Screen:
  /// `_openTaskSheet(existing: task)`).
  final void Function(Task) onOpenTask;

  const TodayDueTasks({
    super.key,
    required this.tasks,
    required this.onToggleTask,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    // Leer -> nichts rendern (die Sektion erscheint nur, wenn heute etwas
    // fällig und offen ist). So bleibt der Heute-Block an ruhigen Tagen leer.
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dezente Beschriftung im Stil der Panel-Sektionsköpfe (Design 5) und
          // des Tagesinfo-Bandes: abgehoben durch Beschriftung, nicht durch
          // Farbe. Hebt die fälligen Aufgaben von den freien Einträgen ab.
          Row(
            children: const [
              Icon(Icons.check_box_outlined,
                  size: 14, color: AppColors.iconInactive),
              SizedBox(width: 6),
              Text(
                'HEUTE FÄLLIG',
                style: TextStyle(
                  color: AppColors.iconInactive,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final task in tasks) _taskLine(context, task),
        ],
      ),
    );
  }

  /// Eine kompakte Aufgabenzeile: Checkbox links, dahinter der einzeilige,
  /// abschneidende Text „Uhrzeit - #Tags - Titel".
  Widget _taskLine(BuildContext context, Task task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nur Abhaken (offenes Kästchen; die Aufgabe ist hier stets offen und
          // heute fällig, also nie rot/überfällig und nie erledigt sichtbar).
          InkResponse(
            onTap: () => onToggleTask(task),
            radius: 22,
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.check_box_outline_blank,
                color: AppColors.taskOpenBox,
                size: 22,
              ),
            ),
          ),
          // Der Rest der Zeile öffnet die Aufgabe. Einzeilig, schneidet ab.
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onOpenTask(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(
                  TextSpan(children: _lineSpans(task)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Baut die Inline-Segmente der Zeile: Uhrzeit (gedämpft) · Tags (Akzent) ·
  /// Titel (normal), jeweils mit „ - " getrennt; fehlende Segmente entfallen.
  List<InlineSpan> _lineSpans(Task task) {
    const base = TextStyle(fontSize: 15, height: 1.2);
    final spans = <InlineSpan>[];

    final time = task.dueTime;
    if (time != null && time.isNotEmpty) {
      spans.add(TextSpan(
        text: '$time - ',
        style: base.copyWith(color: AppColors.iconInactive),
      ));
    }

    if (task.tags.isNotEmpty) {
      final tagText = task.tags.map((t) => '#$t').join(' ');
      spans.add(TextSpan(
        text: '$tagText - ',
        style: base.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w500,
        ),
      ));
    }

    spans.add(TextSpan(
      text: task.title,
      style: base.copyWith(color: AppColors.text),
    ));

    return spans;
  }
}
