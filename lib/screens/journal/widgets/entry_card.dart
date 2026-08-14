import 'dart:io';

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/journal_entry.dart';
import '../../../widgets/ink_painter.dart';
import '../../media/image_viewer_screen.dart';
import 'tag_chip.dart';

/// Ein Journal-Eintrag: getippt in neutralem Dunkel, handschriftlich als echte
/// Tinte (dunkel auf hell). Rahmenlos auf Papier — Text und Tinte stehen frei.
class EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const EntryCard({
    super.key,
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
                    // Datierter Eintrag (v6.2): ein leises Kalender-Icon
                    // kennzeichnet einen vorgemerkten Eintrag — er liegt an
                    // seinem Anzeige-Tag vor, statt zur gezeigten Uhrzeit
                    // geschrieben worden zu sein. Bewusst nur das Icon (kein
                    // Text), gleiche Zurückhaltung wie beim Tinten-Icon.
                    if (entry.isDated) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.event_available,
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
                else if (entry.content.isNotEmpty)
                  Text(
                    entry.content,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                // Bild-Anhang (Session A): Miniatur in der Karte, Antippen
                // öffnet die Vollbild-Ansicht. Zurzeit höchstens ein Bild pro
                // Eintrag — deshalb `attachments.first`.
                if (entry.hasImage) ...[
                  SizedBox(
                      height: entry.isInk || entry.content.isNotEmpty ? 12 : 4),
                  _EntryThumbnail(path: entry.attachments.first.filePath),
                ],
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

/// Miniatur eines Bild-Anhangs in der Eintragskarte. Der eigene Tap-Handler
/// fängt die Berührung ab, bevor sie die Karte (Eintrag bearbeiten) erreicht,
/// und öffnet stattdessen die Vollbild-Ansicht.
///
/// `cacheWidth` dekodiert das Bild verkleinert — die Karte braucht keine volle
/// Auflösung, das schont den Speicher bei vielen Bildern in der Liste.
class _EntryThumbnail extends StatelessWidget {
  final String path;
  const _EntryThumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageViewerScreen(filePath: path),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 1080,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            alignment: Alignment.center,
            color: AppColors.fieldFill,
            child: const Text(
              'Bild nicht gefunden',
              style: TextStyle(color: AppColors.placeholder, fontSize: 13),
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
  const EmptyEntryInvitation({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // Luft nach oben zum Tagesinfo-Band (Bug 3): nur im leeren Zustand
      // sichtbar, da dieses Widget nur dann gerendert wird. Sobald der erste
      // Eintrag steht, ersetzt eine EntryCard diese Einladung und der Abstand
      // faellt automatisch weg.
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
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
