import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

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

  void _confirm() {
    // Platzhalter — wird in der nächsten Session durch OCR ersetzt
    Navigator.pop(context, '[Handschrift-Eintrag]');
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
            onPressed: () => setState(() => _strokes.clear()),
          ),
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
        child: CustomPaint(
          painter: _DrawingPainter(_strokes),
          child: Container(),
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