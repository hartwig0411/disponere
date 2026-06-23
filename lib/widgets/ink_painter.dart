import 'package:flutter/material.dart';
import '../models/ink_data.dart';

/// Live-Painter für den Tinten-Editor.
/// Zeichnet die Striche 1:1 im Canvas-Koordinatensystem.
class InkLivePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  InkLivePainter(
    this.strokes, {
    this.color = Colors.white,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        // Einzelpunkt: kleiner Punkt, damit ein Tippen sichtbar bleibt.
        if (stroke.length == 1) {
          canvas.drawCircle(
            stroke.first,
            strokeWidth / 2,
            Paint()..color = color,
          );
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(InkLivePainter oldDelegate) => true;
}

/// Vorschau-Painter für die Journal-Karte.
/// Skaliert die gespeicherte [InkData] maßstabsgerecht (uniform, zentriert)
/// in den verfügbaren Platz.
class InkPreviewPainter extends CustomPainter {
  final InkData ink;
  final Color color;
  final double strokeWidth;

  InkPreviewPainter(
    this.ink, {
    this.color = Colors.white,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ink.isEmpty || ink.width <= 0 || ink.height <= 0) return;

    final scale = (size.width / ink.width) < (size.height / ink.height)
        ? size.width / ink.width
        : size.height / ink.height;
    final dx = (size.width - ink.width * scale) / 2;
    final dy = (size.height - ink.height * scale) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    Offset map(Offset p) => Offset(p.dx * scale + dx, p.dy * scale + dy);

    for (final stroke in ink.strokes) {
      final pts = stroke.points;
      if (pts.length < 2) continue;
      final path = Path()..moveTo(map(pts.first).dx, map(pts.first).dy);
      for (int i = 1; i < pts.length; i++) {
        final m = map(pts[i]);
        path.lineTo(m.dx, m.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(InkPreviewPainter oldDelegate) =>
      oldDelegate.ink != ink;
}