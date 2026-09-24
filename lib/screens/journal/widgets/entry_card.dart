import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/journal_entry.dart';
import '../../../widgets/ink_painter.dart';
import '../../../widgets/entry_image_thumb.dart';
import '../../../widgets/card_menu_button.dart';
import 'tag_chip.dart';

/// Ein Journal-Eintrag: getippt in neutralem Dunkel, handschriftlich als echte
/// Tinte (dunkel auf hell). Rahmenlos auf Papier — Text und Tinte stehen frei.
///
/// E-06 (v6.17): Der Text der Karte ist markierbar — die umgebende
/// `SelectionArea` des Screens macht ihn auswählbar, langes Drücken markiert.
/// Das Aktionsblatt (Teilen / Löschen) hängt deshalb nicht mehr am langen
/// Drücken, sondern am ⋮-Symbol oben rechts ([onMenu]).
class EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;

  /// ⋮-Symbol: öffnet das Aktionsblatt des Eintrags (vorher langes Drücken).
  final VoidCallback onMenu;
  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onMenu,
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
          // Kein onLongPress mehr (E-06): langes Drücken gehört der
          // Markier-Geste. Das ⋮ liegt per Stack über der rechten oberen Ecke,
          // im Innenabstand der Karte — das Layout des Inhalts bleibt
          // unverändert. `passthrough` reicht die Breite des Elternteils
          // durch; `width: double.infinity` hält die Karte auch in den
          // Tag-Clustern (lose Breite) auf voller Breite, damit das ⋮ immer am
          // rechten Rand sitzt und nie über der Uhrzeit liegt.
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Container(
                width: double.infinity,
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
                    else if (entry.content.isNotEmpty || entry.hasImportBody) ...[
                      // Steffens eigene Notiz/Lösung — seine „Stimme": Blau-Schwarz
                      // (AppColors.ink). Liegt ein geteilter Fremdtext bei, wird sie
                      // zusätzlich leicht eingerückt und mit einer feinen Linie
                      // abgesetzt, damit sie vor dem Rohmaterial steht.
                      if (entry.content.isNotEmpty)
                        Container(
                          padding: entry.hasImportBody
                              ? const EdgeInsets.only(left: 10)
                              : EdgeInsets.zero,
                          decoration: entry.hasImportBody
                              ? const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                        color: AppColors.guide, width: 2),
                                  ),
                                )
                              : null,
                          child: Text(
                            entry.content,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      // Geteilter Fremdtext — zurückhaltendes Grau, kleiner. Tritt
                      // hinter die Stimme zurück, bleibt aber beim Scrollen voll
                      // lesbar (nichts wird gekürzt oder eingeklappt).
                      if (entry.hasImportBody) ...[
                        SizedBox(height: entry.content.isNotEmpty ? 10 : 0),
                        Text(
                          entry.importBody!,
                          style: const TextStyle(
                            color: AppColors.importBody,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                    // Bild-Anhang: kompaktes Vorschau-Quadrat in der Karte (E-01,
                    // v6.7), Antippen öffnet die Vollbild-Ansicht. Zurzeit höchstens
                    // ein Bild pro Eintrag — deshalb `attachments.first`.
                    if (entry.hasImage) ...[
                      SizedBox(
                          height: entry.isInk ||
                                  entry.content.isNotEmpty ||
                                  entry.hasImportBody
                              ? 12
                              : 4),
                      EntryImageThumb(path: entry.attachments.first.filePath),
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
              Positioned(
                top: 4,
                right: 4,
                child: CardMenuButton(onPressed: onMenu),
              ),
            ],
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
    // Der Platzhalter ist kein gespeicherter Text — nicht markierbar (E-06).
    return SelectionContainer.disabled(
      child: InkWell(
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
      ),
    );
  }
}
