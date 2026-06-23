import 'dart:ui';

/// Ein einzelner Strich: eine Folge von Punkten im Canvas-Koordinatensystem.
///
/// Tinte wird als Vektor (Punktfolge) gespeichert, nicht als plattes PNG.
/// Dadurch bleibt ein Tinten-Eintrag editier- und weiterschreibbar
/// (siehe Session 10: „Editierbarkeit" ist 🟡 Core).
class InkStroke {
  final List<Offset> points;
  const InkStroke(this.points);

  /// Kompakt als flache Doubles `[x0, y0, x1, y1, …]` (1 Nachkommastelle).
  List<double> toJson() {
    final flat = <double>[];
    for (final p in points) {
      flat.add(_round(p.dx));
      flat.add(_round(p.dy));
    }
    return flat;
  }

  factory InkStroke.fromJson(List<dynamic> flat) {
    final pts = <Offset>[];
    for (int i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset(
        (flat[i] as num).toDouble(),
        (flat[i + 1] as num).toDouble(),
      ));
    }
    return InkStroke(pts);
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;
}

/// Tinten-Körper eines Eintrags: alle Striche plus die Canvas-Größe,
/// in der sie aufgenommen wurden.
///
/// Die Größe ([width]/[height]) wird mitgespeichert, damit die Striche
/// später maßstabsgerecht in einen anders großen Bereich gerendert werden
/// können (z.B. die kleine Vorschau auf der Journal-Karte).
class InkData {
  final List<InkStroke> strokes;
  final double width;
  final double height;

  const InkData({
    required this.strokes,
    required this.width,
    required this.height,
  });

  bool get isEmpty => strokes.isEmpty;
  bool get isNotEmpty => strokes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'w': _round(width),
        'h': _round(height),
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory InkData.fromJson(Map<String, dynamic> map) {
    return InkData(
      width: (map['w'] as num).toDouble(),
      height: (map['h'] as num).toDouble(),
      strokes: (map['strokes'] as List)
          .map((s) => InkStroke.fromJson(s as List))
          .toList(),
    );
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;
}