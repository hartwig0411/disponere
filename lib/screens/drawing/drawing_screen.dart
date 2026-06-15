import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:huawei_ml_text/huawei_ml_text.dart';
import 'package:path_provider/path_provider.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;
  DrawingPoint(this.offset, this.paint);
}

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<List<DrawingPoint>> _strokes = [];
  List<DrawingPoint> _currentStroke = [];
  final GlobalKey _canvasKey = GlobalKey();
  bool _isProcessing = false;

  Paint get _paint => Paint()
    ..color = Colors.white
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    setState(() {
      _currentStroke = [DrawingPoint(event.localPosition, _paint)];
      _strokes.add(_currentStroke);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    setState(() {
      _currentStroke.add(DrawingPoint(event.localPosition, _paint));
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    setState(() => _currentStroke = []);
  }

  /// Rendert ein eigenes OCR-Bild: schwarze Striche auf weißem Grund.
  /// Unabhängig von der dunklen Anzeige.
  Future<Uint8List> _renderForOcr(Size size) async {
    const double scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);

    // weißer Hintergrund
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // schwarze Striche
    final inkPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i].offset, stroke[i + 1].offset, inkPaint);
      }
    }

    final picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      (size.width * scale).round(),
      (size.height * scale).round(),
    );
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('OCR-Bild konnte nicht gerendert werden');
    }
    return byteData.buffer.asUint8List();
  }

  /// TEMPORÄR — Entscheidungs-Experiment:
  /// Rendert Maschinentext schwarz auf weiß und schickt ihn durch dieselbe
  /// OCR-Pipeline. Erkennt ML Kit das → Engine ok, Handschrift ist die Grenze.
  Future<void> _testPrintedText() async {
    setState(() => _isProcessing = true);
    try {
      const double scale = 2.0;
      const Size size = Size(600, 200);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white,
      );
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Hallo Welt',
          style: TextStyle(
            color: Colors.black,
            fontSize: 64,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, const Offset(40, 60));

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (size.width * scale).round(),
        (size.height * scale).round(),
      );
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      debugPrint('[OCR-TEST] PNG-Bytes: ${pngBytes.length}');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ocr_test_printed.png');
      await file.writeAsBytes(pngBytes);

      final analyzer = MLTextAnalyzer();
      final setting = MLTextAnalyzerSetting.local(
        path: file.path,
        language: 'de',
      );
      final result = await analyzer.asyncAnalyseFrame(setting);
      await analyzer.destroy();

      debugPrint('[OCR-TEST] stringValue: "${result.stringValue}"');

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR-TEST: "${result.stringValue}"')),
        );
      }
    } catch (e, stack) {
      debugPrint('[OCR-TEST] FEHLER: $e');
      debugPrint('[OCR-TEST] Stack: $stack');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR-TEST fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Größe des angezeigten Canvas ermitteln
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final Size size = boundary.size;
      debugPrint('[OCR] Canvas-Größe: $size, Striche: ${_strokes.length}, '
          'Punkte gesamt: ${_strokes.fold<int>(0, (s, e) => s + e.length)}');

      // 2. Eigenes OCR-Bild rendern (schwarz auf weiß) und speichern
      final Uint8List pngBytes = await _renderForOcr(size);
      debugPrint('[OCR] PNG-Bytes: ${pngBytes.length}');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ocr_input.png');
      await file.writeAsBytes(pngBytes);
      debugPrint('[OCR] Datei: ${file.path}, '
          'existiert: ${await file.exists()}, '
          'Größe: ${await file.length()} Bytes');

      // 3. Huawei ML Kit Text Recognition aufrufen
      final analyzer = MLTextAnalyzer();
      final setting = MLTextAnalyzerSetting.local(
        path: file.path,
        language: 'de',
      );
      final MLText result = await analyzer.asyncAnalyseFrame(setting);
      await analyzer.destroy();

      debugPrint('[OCR] stringValue: "${result.stringValue}"');

      // 4. Erkannten Text extrahieren
      final recognizedText = result.stringValue ?? '';
      final text = recognizedText.trim().isEmpty
          ? '[Handschrift nicht erkannt]'
          : recognizedText.trim();
      debugPrint('[OCR] Ergebnis an Journal: "$text"');

      if (mounted) Navigator.pop(context, text);
    } catch (e, stack) {
      debugPrint('[OCR] FEHLER: $e');
      debugPrint('[OCR] Stack: $stack');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Handschrift', style: TextStyle(color: Colors.white)),
        actions: [
          // TEMPORÄR — Entscheidungs-Experiment (Maschinentext durch OCR)
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.orangeAccent),
            tooltip: 'OCR-Test (Maschinentext)',
            onPressed: _isProcessing ? null : _testPrintedText,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: _isProcessing
                ? null
                : () => setState(() => _strokes.clear()),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF4A90D9),
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF4A90D9)),
              onPressed: _strokes.isEmpty ? null : _confirm,
            ),
        ],
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: RepaintBoundary(
          key: _canvasKey,
          child: CustomPaint(
            painter: _DrawingPainter(_strokes),
            child: Container(),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<List<DrawingPoint>> strokes;
  _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i].offset, stroke[i + 1].offset, stroke[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}