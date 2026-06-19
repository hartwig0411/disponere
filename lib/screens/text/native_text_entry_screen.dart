import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import '../../utils/tag_parser.dart';

/// Rückgabe des Stift-Eintrag-Screens: erkannter Text + zugehörige Tags.
class NativeTextResult {
  final String text;
  final List<String> tags;
  const NativeTextResult(this.text, this.tags);
}

class NativeTextEntryScreen extends StatefulWidget {
  const NativeTextEntryScreen({super.key});

  @override
  State<NativeTextEntryScreen> createState() => _NativeTextEntryScreenState();
}

class _NativeTextEntryScreenState extends State<NativeTextEntryScreen> {
  static const String _viewType = 'disponere/native-text';
  MethodChannel? _channel;
  final TextEditingController _tagController = TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final text = await _channel?.invokeMethod<String>('getText') ?? '';
    if (!mounted) return;
    Navigator.pop(
      context,
      NativeTextResult(text.trim(), parseTags(_tagController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Stift-Eintrag',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF4A90D9)),
            tooltip: 'Übernehmen',
            onPressed: _confirm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: defaultTargetPlatform == TargetPlatform.android
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildNativeField()),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tags mit #  ·  z.B. #MBS #ValSys',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: Text('Nur auf Android')),
      ),
    );
  }

  Widget _buildNativeField() {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers:
              const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        _channel = MethodChannel('disponere/native-text_${params.id}');
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}