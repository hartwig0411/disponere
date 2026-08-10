import 'package:flutter/services.dart';

/// Empfaengt via Android `ACTION_SEND` (Text/URL) geteilte Inhalte ueber einen
/// nativen MethodChannel (`disponere/share`) — bewusst **ohne** das Plugin
/// `receive_sharing_intent`: dieselbe Werkzeuglinie wie FreeScript-PlatformView
/// und AppAuth, robuster auf HMS (Disponere macht Natives ohnehin selbst).
///
/// Zwei Wege, entsprechend der beiden nativen Eintrittspunkte:
///  - **Kaltstart** (App war zu, Start ueber den Teilen-Dialog): der Text liegt
///    schon in `getIntent()`, wird nativ gepuffert und hier ueber
///    [getInitialSharedText] **genau einmal** abgeholt (ein bloßer App-Wechsel
///    liefert ihn nicht erneut).
///  - **Laufzeit** (App laeuft, `onNewIntent`): der native Code ruft
///    `onSharedText` zurueck; [onText] wird ausgeloest.
class ShareReceiver {
  static const MethodChannel _channel = MethodChannel('disponere/share');

  /// Wird bei einem **Laufzeit**-Share (App bereits offen) mit dem geteilten
  /// Text aufgerufen. Vom Aufrufer gesetzt (siehe JournalScreen).
  void Function(String text)? onText;

  /// Beginnt, Laufzeit-Shares entgegenzunehmen. Idempotent.
  void start() {
    _channel.setMethodCallHandler(_handle);
  }

  /// Loest den Handler wieder (z.B. beim Dispose des JournalScreen).
  void stop() {
    _channel.setMethodCallHandler(null);
  }

  Future<dynamic> _handle(MethodCall call) async {
    if (call.method == 'onSharedText') {
      final text = call.arguments as String?;
      if (text != null && text.trim().isNotEmpty) {
        onText?.call(text);
      }
    }
    return null;
  }

  /// Holt einen etwaigen **Kaltstart**-Share ab. Gibt `null` zurueck, wenn die
  /// App normal (nicht ueber den Teilen-Dialog) gestartet wurde. Der native
  /// Puffer wird bei diesem Aufruf geleert — der Text kommt also nur einmal.
  Future<String?> getInitialSharedText() async {
    final text = await _channel.invokeMethod<String?>('getInitialSharedText');
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }
}
