import 'dart:io';

import 'package:flutter/material.dart';

import '../screens/media/image_viewer_screen.dart';
import '../theme/app_colors.dart';

/// Kompaktes Vorschau-Quadrat eines Bild-Anhangs (E-01, v6.7).
///
/// Zeigt das **Motiv** quadratisch beschnitten (`BoxFit.cover`, zentriert) statt
/// eines generischen Symbol-Icons — so ist auf einen Blick erkennbar, *welches*
/// Bild an der Karte hängt. Antippen öffnet die **unveränderte** Vollbild-Ansicht.
///
/// Bewusst **eine einzige Quelle** für Journal- und Tag-Ansicht, damit ein Bild
/// überall gleich aussieht — genau die Anzeige-Drift, die E-01 schließt. Der
/// eigene Tap-Handler (`GestureDetector`) fängt die Berührung ab, bevor sie eine
/// umgebende Karte (Eintrag bearbeiten) erreicht, und öffnet stattdessen das
/// Vollbild.
///
/// `cacheWidth` dekodiert das Bild klein — die Miniatur braucht keine volle
/// Auflösung, das schont den Speicher bei vielen Bildern in der Liste.
class EntryImageThumb extends StatelessWidget {
  final String path;

  /// Kantenlänge des Quadrats. Reversible Detailentscheidung (v6.7): ~72 px.
  static const double _edge = 72;

  const EntryImageThumb({super.key, required this.path});

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
        width: _edge,
        height: _edge,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          // ~3× der Kantenlänge deckt hohe Pixeldichten scharf ab und bleibt
          // sparsam beim Speicher.
          cacheWidth: 216,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.fieldFill,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.placeholder,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
