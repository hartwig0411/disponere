import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/calendar_event.dart';
import 'tag_chip.dart';

/// Eine Terminkarte: blaues Kalender-Icon, Zeit, Titel, optional Ort, Tags.
class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final String day;

  const EventCard({required this.event, required this.day});

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
                      for (final tag in event.tags) TagChip(label: tag),
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
