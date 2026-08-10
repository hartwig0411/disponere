import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/journal_entry.dart';
import '../utils/ink_renderer.dart';

/// Kein teilbarer Inhalt gefunden — ein leerer Text-Eintrag ohne Bild und ohne
/// Tinte. Die Oberfläche fängt das ab und zeigt einen kurzen Hinweis, statt
/// einen leeren Teilen-Dialog zu öffnen.
class NothingToShareException implements Exception {
  const NothingToShareException();

  @override
  String toString() => 'Dieser Eintrag hat nichts zum Teilen.';
}

/// Gibt einen Journal-Eintrag über Androids nativen Teilen-Dialog nach außen
/// (Feature 3, Session C). Der Gegenpart zum Empfang (Feature 2): dort kommt
/// Fremdes herein, hier geht Eigenes hinaus.
///
/// Was geteilt wird, richtet sich nach der Eintragsart:
/// - **Text** → der Text selbst.
/// - **Tinte** → ein frisch gerendertes PNG (schwarz auf weiß, über
///   [InkRenderer] — dieselbe Darstellung, die auch die Erkennung sieht).
///   Liegt bereits erkannter Text vor ([JournalEntry.inkText]), geht er als
///   Begleittext mit.
/// - **Bild** → die Anhang-Datei(en); vorhandener Eintragstext kommt als
///   Begleittext mit.
///
/// Bewusst **kein** natives MethodChannel wie beim Empfang: Das Senden ist ein
/// einmaliger `ACTION_SEND`-Aufruf ohne Lebenszyklus — `share_plus` genügt und
/// bringt seinen eigenen FileProvider mit (kein Manifest-Eintrag nötig, kein
/// GMS). Der Empfang dagegen hängt am Activity-Lebenszyklus und blieb deshalb
/// nativ.
class ShareService {
  /// Rendert das Tinten-PNG in ein Temp-Verzeichnis. Fester Name je Eintrag:
  /// eine erneute Teilung überschreibt, statt Dateien anzuhäufen; das
  /// Temp-Verzeichnis räumt das System ohnehin selbst.
  static Future<File> _renderInkToTemp(JournalEntry entry) async {
    final bytes = await InkRenderer.toPngBytes(entry.ink!);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/disponere_share_${entry.id}.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Teilt [entry] nach außen.
  ///
  /// Wirft [NothingToShareException], wenn nichts zu teilen ist, oder
  /// [InkRenderException], wenn das Tinten-Bild nicht erzeugt werden kann —
  /// beides fängt die aufrufende Oberfläche als kurzen Hinweis ab. Ein
  /// abgebrochener Teilen-Dialog wirft nichts (share_plus liefert nur einen
  /// „verworfen"-Status zurück).
  static Future<void> shareEntry(JournalEntry entry) async {
    final files = <XFile>[];
    final textParts = <String>[];

    if (entry.isInk) {
      final png = await _renderInkToTemp(entry);
      files.add(XFile(png.path, mimeType: 'image/png'));
      if (entry.hasInkText) textParts.add(entry.inkText!.trim());
    } else if (entry.content.trim().isNotEmpty) {
      textParts.add(entry.content.trim());
    }

    // Bild-Anhänge (können neben Text stehen). Nur tatsächlich vorhandene
    // Dateien — ein verwaister Pfad soll den Teilen-Dialog nicht mit einer
    // toten Datei füttern.
    for (final att in entry.attachments) {
      if (await File(att.filePath).exists()) {
        files.add(XFile(att.filePath, mimeType: att.mimeType));
      }
    }

    final text = textParts.join('\n\n');

    if (files.isNotEmpty) {
      await Share.shareXFiles(files, text: text.isEmpty ? null : text);
    } else if (text.isNotEmpty) {
      await Share.share(text);
    } else {
      throw const NothingToShareException();
    }
  }
}
