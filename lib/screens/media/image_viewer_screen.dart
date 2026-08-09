import 'dart:io';

import 'package:flutter/material.dart';

/// Vollbild-Ansicht eines Bild-Anhangs. Bewusst schlicht: schwarzer Grund,
/// Zoom per Zwei-Finger, Antippen oder Zurück schließt.
///
/// Der schwarze Grund ist hier **kein** Verstoß gegen das helle Theme, sondern
/// die richtige Bühne fürs Bild — wie in jeder Foto-Ansicht. Er ist lokal auf
/// diesen Screen begrenzt.
class ImageViewerScreen extends StatelessWidget {
  final String filePath;
  const ImageViewerScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.file(
              File(filePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Bild nicht gefunden.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
