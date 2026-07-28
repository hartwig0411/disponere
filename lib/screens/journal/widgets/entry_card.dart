import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/journal_entry.dart';
import '../../../widgets/ink_painter.dart';
import 'tag_chip.dart';

/// Ein Journal-Eintrag: getippt in neutralem Dunkel, handschriftlich als echte
/// Tinte (dunkel auf hell). Rahmenlos auf Papier — Text und Tinte stehen frei.
class EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const EntryCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: AppColors.placeholder,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (entry.isInk) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.brush,
                          size: 12, color: AppColors.placeholder),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (entry.isInk)
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter:
                          InkPreviewPainter(entry.ink!, color: AppColors.ink),
                      child: const SizedBox.expand(),
                    ),
                  )
                else
                  Text(
                    entry.content,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        entry.tags.map((tag) => TagChip(label: tag)).toList(),
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

/// Leerer Heute-Zustand (Design 6): ein wartender Punkt, ein blauer Cursor und
/// ein leiser Platzhalter laden zum Schreiben ein. Antippen oeffnet das
/// Eintrags-Sheet.
class EmptyEntryInvitation extends StatelessWidget {
  final VoidCallback onTap;
  const EmptyEntryInvitation({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: AppColors.bullet,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              color: AppColors.accent,
            ),
            const Text(
              'Tippen oder mit dem Stift schreiben ...',
              style: TextStyle(color: AppColors.placeholder, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
