import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Canvas als Bild rendern
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Canvas konnte nicht gerendert werden');

      // 2. PNG in temporäre Datei schreiben
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ocr_input.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // 3. Huawei ML Kit Text Recognition aufrufen
      final analyzer = MLTextAnalyzer();
      final setting = MLTextAnalyzerSetting.local(
        path: file.path,
        language: 'de',
      );
      final MLText result = await analyzer.asyncAnalyseFrame(setting);
      await analyzer.destroy();

      // 4. Erkannten Text extrahieren
      final recognizedText = result.stringValue ?? '';
      final text = recognizedText.trim().isEmpty
          ? '[Handschrift nicht erkannt]'
          : recognizedText.trim();

      if (mounted) Navigator.pop(context, text);
    } catch (e) {
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