import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

class NativeTextTestScreen extends StatelessWidget {
  const NativeTextTestScreen({super.key});

  static const String _viewType = 'disponere/native-text';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FreeScript-Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mit dem M-Pencil in das Feld unten schreiben.\n'
              'Wandelt FreeScript die Handschrift in getippten Text um?',
            ),
            const SizedBox(height: 16),
            // Feste Höhe ist Pflicht, sonst rendert die PlatformView leer.
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: defaultTargetPlatform == TargetPlatform.android
                  ? _buildNativeField()
                  : const Center(child: Text('Nur auf Android')),
            ),
          ],
        ),
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