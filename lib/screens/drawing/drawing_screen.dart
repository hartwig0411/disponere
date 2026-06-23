import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../models/ink_data.dart';
import '../../utils/tag_parser.dart';
import '../../widgets/ink_painter.dart';
import '../../widgets/tag_autocomplete_field.dart';

/// Rückgabe des Tinten-Editors: die Striche (mit Canvas-Größe) + Tags.
class InkResult {
  final InkData ink;
  final List<String> tags;
  const InkResult(this.ink, this.tags);
}

/// Tinten-Modus: handschriftliche Eingabe als Strichdaten (Vektoren).
/// Keine OCR/Umwandlung — die Handschrift bleibt erhalten und der Eintrag
/// ist editier- und weiterschreibbar.
///
/// Mit [initialInk] werden vorhandene Striche zum Weiterschreiben geladen.
class DrawingScreen extends StatefulWidget {
  final InkData? initialInk;
  final List<String> initialTags;
  final List<String> knownTags;

  const DrawingScreen({
    super.key,
    this.initialInk,
    this.initialTags = const [],
    this.knownTags = const [],
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _canvasKey = GlobalKey();
  late final TextEditingController _tagController;

  /// Radierer-Modus: Stift löscht ganze Striche, statt zu zeichnen.
  bool _erasing = false;

  static const double _eraseThreshold = 18.0;

  @override
  void initState() {
    super.initState();
    _tagController =
        TextEditingController(text: formatTags(widget.initialTags));
    final ink = widget.initialInk;
    if (ink != null) {
      for (final s in ink.strokes) {
        _strokes.add(List<Offset>.from(s.points));
      }
      // Nach dem ersten Layout an die aktuelle Canvas-Größe anpassen — z.B.
      // wenn das Gerät zwischen Erstellen und Bearbeiten gedreht wurde.
      // Gleiche Größe → No-op (kein Eingriff in den Normalfall).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitLoadedInkToCanvas(Size(ink.width, ink.height));
      });
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  /// Rechnet die geladenen Striche von der gespeicherten Größe [from] auf die
  /// aktuelle Canvas-Größe um (uniform skaliert, zentriert — keine Verzerrung
  /// der Handschrift).
  void _fitLoadedInkToCanvas(Size from) {
    if (from.width <= 0 || from.height <= 0) return;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final to = box?.size;
    if (to == null || to.isEmpty) return;
    if ((to.width - from.width).abs() < 1 &&
        (to.height - from.height).abs() < 1) {
      return; // gleiche Größe → nichts zu tun
    }
    final scale = (to.width / from.width) < (to.height / from.height)
        ? to.width / from.width
        : to.height / from.height;
    final dx = (to.width - from.width * scale) / 2;
    final dy = (to.height - from.height * scale) / 2;
    setState(() {
      for (final stroke in _strokes) {
        for (int i = 0; i < stroke.length; i++) {
          stroke[i] =
              Offset(stroke[i].dx * scale + dx, stroke[i].dy * scale + dy);
        }
      }
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    if (_erasing) {
      _eraseAt(event.localPosition);
      return;
    }
    setState(() => _strokes.add([event.localPosition]));
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    if (_erasing) {
      _eraseAt(event.localPosition);
      return;
    }
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(event.localPosition));
  }

  /// Löscht alle Striche, die nah genug an [p] liegen (ganzer Strich).
  void _eraseAt(Offset p) {
    bool removed = false;
    _strokes.removeWhere((stroke) {
      final hit = _strokeHit(stroke, p);
      if (hit) removed = true;
      return hit;
    });
    if (removed) setState(() {});
  }

  bool _strokeHit(List<Offset> stroke, Offset p) {
    if (stroke.isEmpty) return false;
    if (stroke.length == 1) {
      return (stroke.first - p).distance <= _eraseThreshold;
    }
    for (int i = 0; i < stroke.length - 1; i++) {
      if (_distToSegment(p, stroke[i], stroke[i + 1]) <= _eraseThreshold) {
        return true;
      }
    }
    return false;
  }

  /// Kürzeste Distanz von Punkt [p] zur Strecke [a]–[b].
  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    double t =
        ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() => setState(() => _strokes.clear());

  void _confirm() {
    if (_strokes.isEmpty) return;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(0, 0);

    final ink = InkData(
      strokes: _strokes.map((s) => InkStroke(List<Offset>.from(s))).toList(),
      width: size.width,
      height: size.height,
    );
    Navigator.pop(context, InkResult(ink, parseTags(_tagController.text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Tinte',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              color: _erasing ? const Color(0xFF4A90D9) : Colors.white,
            ),
            tooltip: _erasing ? 'Radierer aktiv' : 'Radieren',
            onPressed: () => setState(() => _erasing = !_erasing),
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            tooltip: 'Letzten Strich zurück',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            tooltip: 'Alles löschen',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF4A90D9)),
            tooltip: 'Übernehmen',
            onPressed: _strokes.isEmpty ? null : _confirm,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              child: RepaintBoundary(
                key: _canvasKey,
                child: CustomPaint(
                  painter: InkLivePainter(_strokes),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TagAutocompleteField(
              controller: _tagController,
              knownTags: widget.knownTags,
            ),
          ),
        ],
      ),
    );
  }
}