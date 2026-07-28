import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/task.dart';
import 'tag_chip.dart';

/// Eine Aufgabe im Heute-Panel: offenes Kaestchen (gedaempftes Blau), erledigt
/// als gefuelltes Kaestchen mit Haekchen und durchgestrichenem, grauem Text.
/// [onToggle] hakt ab/auf — im Panel das einzige interaktive Element der Zeile.
/// [onTap] ist optional; ist er null, ist die Zeile bewusst nicht antippbar
/// (Design 5: „nur Abhaken, kein Oeffnen").
class TaskCard extends StatelessWidget {
  final Task task;
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  const TaskCard({
    required this.task,
    required this.today,
    required this.onToggle,
    this.onTap,
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
                            .map((t) => TagChip(label: t))
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
