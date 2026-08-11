import 'package:flutter/services.dart';

/// Ein via Android `ACTION_SEND` mit `image/*` empfangenes Bild. Die native
/// Seite (MainActivity) hat den `content://`-URI bereits in eine app-private
/// Temp-Datei kopiert; [path] zeigt dorthin — genau wie ein von image_picker
/// geliefertes [XFile]. [caption] ist eine etwaige Bildunterschrift aus
/// `EXTRA_TEXT`/`EXTRA_SUBJECT` (sonst null).
class SharedImage {
  const SharedImage({required this.path, this.mimeType, this.caption});

  final String path;
  final String? mimeType;
  final String? caption;
}

/// Empfaengt via Android `ACTION_SEND` geteilte Inhalte ueber einen nativen
/// MethodChannel (`disponere/share`) — bewusst **ohne** das Plugin
/// `receive_sharing_intent`: dieselbe Werkzeuglinie wie FreeScript-PlatformView
/// und AppAuth, robuster auf HMS (Disponere macht Natives ohnehin selbst).
///
/// Zwei Inhaltsarten (Text, Bild), jeweils mit zwei Wegen entsprechend der
/// beiden nativen Eintrittspunkte:
///  - **Kaltstart** (App war zu, Start ueber den Teilen-Dialog): der Inhalt
///    liegt schon in `getIntent()`, wird nativ gepuffert und hier ueber
///    [getInitialSharedText] bzw. [getInitialSharedImage] **genau einmal**
///    abgeholt (ein bloßer App-Wechsel liefert ihn nicht erneut).
///  - **Laufzeit** (App laeuft, `onNewIntent`): der native Code ruft
///    `onSharedText` bzw. `onSharedImage` zurueck; [onText] bzw. [onImage] wird
///    ausgeloest.
class ShareReceiver {
  static const MethodChannel _channel = MethodChannel('disponere/share');

  /// Wird bei einem **Laufzeit**-Text-Share (App bereits offen) mit dem
  /// geteilten Text aufgerufen. Vom Aufrufer gesetzt (siehe JournalScreen).
  void Function(String text)? onText;

  /// Wird bei einem **Laufzeit**-Bild-Share (App bereits offen) mit dem
  /// empfangenen Bild aufgerufen. Vom Aufrufer gesetzt (siehe JournalScreen).
  void Function(SharedImage image)? onImage;

  /// Beginnt, Laufzeit-Shares entgegenzunehmen. Idempotent.
  void start() {
    _channel.setMethodCallHandler(_handle);
  }

  /// Loest den Handler wieder (z.B. beim Dispose des JournalScreen).
  void stop() {
    _channel.setMethodCallHandler(null);
  }

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'onSharedText':
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          onText?.call(text);
        }
        break;
      case 'onSharedImage':
        final image = _parseImage(call.arguments);
        if (image != null) {
          onImage?.call(image);
        }
        break;
    }
    return null;
  }

  /// Holt einen etwaigen **Kaltstart**-Text-Share ab. Gibt `null` zurueck, wenn
  /// die App normal (nicht ueber den Teilen-Dialog) gestartet wurde. Der native
  /// Puffer wird bei diesem Aufruf geleert — der Text kommt also nur einmal.
  Future<String?> getInitialSharedText() async {
    final text = await _channel.invokeMethod<String?>('getInitialSharedText');
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }

  /// Holt ein etwaiges **Kaltstart**-Bild ab. Gibt `null` zurueck, wenn die App
  /// nicht ueber einen Bild-Teilen-Dialog gestartet wurde. Der native Puffer
  /// wird bei diesem Aufruf geleert — das Bild kommt also nur einmal.
  Future<SharedImage?> getInitialSharedImage() async {
    final raw = await _channel.invokeMethod<dynamic>('getInitialSharedImage');
    return _parseImage(raw);
  }

  /// Wandelt die vom nativen Kanal gelieferte Map in ein [SharedImage]. Robust
  /// gegen null und fehlenden/leeren Pfad -> null.
  SharedImage? _parseImage(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final path = map['path'] as String?;
    if (path == null || path.isEmpty) return null;
    final mime = map['mime'] as String?;
    final caption = map['caption'] as String?;
    return SharedImage(
      path: path,
      mimeType: (mime != null && mime.isNotEmpty) ? mime : null,
      caption: (caption != null && caption.trim().isNotEmpty) ? caption : null,
    );
  }
}
