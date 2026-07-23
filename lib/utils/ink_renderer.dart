import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/ink_data.dart';

/// Fehler beim Aufbereiten der Tinte fürs Bild — in Klartext für die UI.
class InkRenderException implements Exception {
  final String message;
  const InkRenderException(this.message);

  @override
  String toString() => message;
}

/// Rendert [InkData] offscreen zu einem PNG und liefert es base64-kodiert.
///
/// Bewusst **kein** Widget und **keine** `RepaintBoundary`: Ein Eintrag soll
/// auswertbar sein, ohne dass sein Editor sichtbar im Baum hängt
/// (Architektur §6).
///
/// **Schwarz auf Weiß, unabhängig vom App-Theme.** Der Renderer erzeugt eine
/// eigene Darstellung *für die Erkennung*, keinen Bildschirmabzug der Anzeige.
/// Ein späterer Theme-Wechsel ändert an der Erkennung damit nichts.
class InkRenderer {
  /// Lange Kante des Bildes. Größere Bilder werden serverseitig ohnehin
  /// heruntergerechnet — man zahlte für Pixel, die niemand ansieht.
  static const double maxEdge = 1568.0;

  /// Untergrenze der langen Kante. Eine einzelne kurze Zeile ergäbe sonst ein
  /// Briefmarken-PNG, auf dem auch ein Mensch nichts mehr entziffert.
  static const double minEdge = 768.0;

  /// Strichbreite des Editors (`InkLivePainter`), Ausgangswert vor der
  /// Skalierung.
  static const double editorStrokeWidth = 3.0;

  /// Untergrenze der Strichbreite. Zu dünne Striche nach dem Verkleinern sind
  /// der eigentliche Erkennungskiller — deutlich eher als eine zu geringe
  /// Auflösung (Architektur §6).
  static const double minStrokeWidth = 2.0;

  /// Weißer Rand um die Schrift, anteilig an der langen Kante des Inhalts.
  static const double marginFactor = 0.04;
  static const double minMargin = 16.0;

  /// [InkData] → PNG → base64. Das ist die Form, in der das Bild im
  /// Request-Body steht.
  static Future<String> toBase64Png(InkData ink) async {
    final bytes = await toPngBytes(ink);
    return base64Encode(bytes);
  }

  /// [InkData] → PNG-Bytes.
  ///
  /// Zugeschnitten auf die **tatsächlich beschriebene Fläche** statt auf den
  /// vollen Zeichenbereich: Wer fünf Zeilen an den oberen Rand schreibt,
  /// bekäme sonst ein Bild, das zur Hälfte aus leerem Weiß besteht — die
  /// Schrift selbst hätte nur einen Bruchteil der Auflösung. Der Zuschnitt
  /// kostet nichts und verbessert beides: Erkennung und Token-Preis.
  static Future<Uint8List> toPngBytes(InkData ink) async {
    if (ink.isEmpty) {
      throw const InkRenderException('Dieser Eintrag enthält keine Striche.');
    }

    // 1. Umschließendes Rechteck aller Punkte bestimmen.
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
    if (!minX.isFinite || !minY.isFinite) {
      throw const InkRenderException('Dieser Eintrag enthält keine Striche.');
    }

    // 2. Rand dazu. Eine einzelne waagerechte Linie hat Höhe 0 — deshalb
    //    wird die Ausdehnung nach unten auf 1 begrenzt.
    final contentW = (maxX - minX).clamp(1.0, double.infinity);
    final contentH = (maxY - minY).clamp(1.0, double.infinity);
    final longContent = contentW > contentH ? contentW : contentH;
    final margin = (longContent * marginFactor) < minMargin
        ? minMargin
        : longContent * marginFactor;

    final boxW = contentW + 2 * margin;
    final boxH = contentH + 2 * margin;

    // 3. Skalierung. Nur verkleinern, wenn zu groß; nur vergrößern, wenn das
    //    Bild sonst unter die Lesbarkeitsgrenze fiele.
    final longEdge = boxW > boxH ? boxW : boxH;
    double scale = 1.0;
    if (longEdge > maxEdge) {
      scale = maxEdge / longEdge;
    } else if (longEdge < minEdge) {
      scale = minEdge / longEdge;
    }

    final outW = (boxW * scale).round().clamp(1, maxEdge.round());
    final outH = (boxH * scale).round().clamp(1, maxEdge.round());

    final strokeWidth = editorStrokeWidth * scale < minStrokeWidth
        ? minStrokeWidth
        : editorStrokeWidth * scale;

    // 4. Zeichnen. Koordinaten werden direkt umgerechnet statt über eine
    //    Canvas-Transformation — die Reihenfolge von scale/translate ist eine
    //    klassische Fehlerquelle, und hier ist sie schlicht nicht nötig.
    Offset map(Offset p) => Offset(
          (p.dx - minX + margin) * scale,
          (p.dy - minY + margin) * scale,
        );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final linePaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = const Color(0xFF000000);

    for (final stroke in ink.strokes) {
      final pts = stroke.points;
      if (pts.isEmpty) continue;
      if (pts.length == 1) {
        // Einzelpunkt: als Punkt zeichnen, damit ein i-Tüpfelchen nicht
        // verschwindet.
        canvas.drawCircle(map(pts.first), strokeWidth / 2, dotPaint);
        continue;
      }
      final start = map(pts.first);
      final path = Path()..moveTo(start.dx, start.dy);
      for (int i = 1; i < pts.length; i++) {
        final m = map(pts[i]);
        path.lineTo(m.dx, m.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(outW, outH);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const InkRenderException('Bild konnte nicht erzeugt werden.');
      }
      return data.buffer.asUint8List();
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }
}
