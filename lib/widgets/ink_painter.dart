import 'package:flutter/material.dart';
import '../models/ink_data.dart';
import '../theme/app_colors.dart';

/// Live-Painter für den Tinten-Editor.
/// Zeichnet die Striche 1:1 im Canvas-Koordinatensystem.
class InkLivePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  InkLivePainter(
    this.strokes, {
    this.color = AppColors.ink,
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
///
/// Skaliert nicht die volle Aufnahme-Leinwand, sondern die **Bounding-Box der
/// tatsächlichen Striche** — uniform und zentriert — in den verfügbaren Platz.
/// Sonst füllt eine kurze Notiz auf großer Fläche nur einen Bruchteil der
/// Kachel und wirkt winzig. Dieselbe Zuschnitt-Idee nutzt [InkRenderer] fürs
/// Erkennungsbild (`ink_renderer.dart`).
class InkPreviewPainter extends CustomPainter {
  final InkData ink;
  final Color color;
  final double strokeWidth;

  InkPreviewPainter(
    this.ink, {
    this.color = AppColors.ink,
    this.strokeWidth = 2.0,
  });

  /// Kleiner Rand in Kachel-Pixeln, damit die Schrift nicht an der Kante klebt.
  static const double _padding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (ink.isEmpty) return;

    // 1. Umschließendes Rechteck aller Stroke-Punkte — die tatsächlich
    //    beschriebene Fläche, nicht die volle Aufnahme-Leinwand.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final stroke in ink.strokes) {
      for (final p in stroke.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    if (!minX.isFinite || !minY.isFinite) return;

    // 2. Eine waagerechte oder senkrechte Linie hat in einer Achse Ausdehnung
    //    0 — auf mindestens 1 begrenzen, damit die Skalierung nicht durch Null
    //    teilt.
    final contentW = (maxX - minX).clamp(1.0, double.infinity);
    final contentH = (maxY - minY).clamp(1.0, double.infinity);

    // 3. In den verfügbaren Platz (abzüglich Rand) einpassen, uniform.
    final availW = (size.width - 2 * _padding).clamp(1.0, double.infinity);
    final availH = (size.height - 2 * _padding).clamp(1.0, double.infinity);
    final scale = (availW / contentW) < (availH / contentH)
        ? availW / contentW
        : availH / contentH;

    // 4. Horizontal linksbuendig (linke Kante am Rand), vertikal zentriert.
    final dx = _padding;
    final dy = (size.height - contentH * scale) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Punkt in Kachel-Koordinaten: an den Bounding-Box-Ursprung schieben,
    // skalieren, zentriert versetzen.
    Offset map(Offset p) =>
        Offset((p.dx - minX) * scale + dx, (p.dy - minY) * scale + dy);

    for (final stroke in ink.strokes) {
      final pts = stroke.points;
      if (pts.length < 2) {
        // Einzelpunkt sichtbar halten (i-Tüpfelchen, kurzer Tipp) — sonst
        // verschwindet er, wie bisher, ganz.
        if (pts.length == 1) {
          canvas.drawCircle(map(pts.first), strokeWidth / 2, Paint()..color = color);
        }
        continue;
      }
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