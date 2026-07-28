import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/calendar_event.dart';
import '../../../models/task.dart';
import 'event_card.dart';
import 'task_card.dart';

/// Heute-Panel (Design 5): Overlay-Drawer von rechts mit der heutigen Agenda —
/// Termine und Aufgaben. Haelt die Journalspalte frei (Design 4a). Aufgaben
/// sind direkt abhakbar (das einzige interaktive Element der Zeile, Design 5:
/// „nur Abhaken"); Termine sind reine Anzeige. Ein „+" im Kopf legt eine neue
/// Aufgabe an — der verbliebene Anlege-Einstieg, seit die Aufgaben aus der
/// Journalspalte gewandert sind. Leerfall: „Heute nichts geplant".
class TodayPanel extends StatelessWidget {
  final List<CalendarEvent> events;
  final List<Task> tasks;
  final DateTime today;
  final String day;
  final bool calendarEnabled;
  final void Function(Task) onToggleTask;
  final VoidCallback onAddTask;

  const TodayPanel({
    required this.events,
    required this.tasks,
    required this.today,
    required this.day,
    required this.calendarEnabled,
    required this.onToggleTask,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    // Termine nur mit aktivem Kalender; Aufgaben unabhaengig davon.
    final hasEvents = calendarEnabled && events.isNotEmpty;
    final hasTasks = tasks.isNotEmpty;
    final nothingPlanned = !hasEvents && !hasTasks;

    return Drawer(
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kopf: „HEUTE" + Datum, rechts „+" (neue Aufgabe) und Schliessen.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HEUTE',
                          style: TextStyle(
                            color: AppColors.weekday,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _headerDate(today),
                          style: const TextStyle(
                            color: AppColors.dateLarge,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add,
                        color: AppColors.iconInactive, size: 22),
                    tooltip: 'Aufgabe hinzufuegen',
                    onPressed: onAddTask,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close,
                        color: AppColors.iconInactive, size: 22),
                    tooltip: 'Schliessen',
                    onPressed: () => Scaffold.of(context).closeEndDrawer(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            Expanded(
              child: nothingPlanned
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Heute nichts geplant',
                          style: TextStyle(
                              color: AppColors.placeholder, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 24),
                      children: [
                        if (hasEvents) ...[
                          _sectionLabel(Icons.event_outlined, 'TERMINE'),
                          const SizedBox(height: 12),
                          ...events.map((e) => EventCard(event: e, day: day)),
                          if (hasTasks) const SizedBox(height: 20),
                        ],
                        if (hasTasks) ...[
                          _sectionLabel(Icons.check_box_outlined, 'AUFGABEN'),
                          const SizedBox(height: 12),
                          ...tasks.map(
                            (t) => TaskCard(
                              task: t,
                              today: today,
                              onToggle: () => onToggleTask(t),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kleiner Abschnittskopf im Panel (Termine / Aufgaben), im Stil der
  /// frueheren Sektionskoepfe.
  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.iconInactive),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.iconInactive,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _headerDate(DateTime d) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return '${d.day}. ${months[d.month - 1]}';
  }
}
