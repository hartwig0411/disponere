import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/attachment.dart';

/// Legt Bild-Anhänge im **App-privaten Speicher** ab und räumt sie wieder weg.
///
/// Bilder landen unter `<AppDocuments>/attachments/` — auf Android also im
/// app-privaten Bereich (`/data/data/<paket>/app_flutter/attachments/`). Das
/// bedeutet: kein Eintrag in der Geräte-Galerie, keine Storage-Berechtigung,
/// und alles wird beim Deinstallieren sauber mit entfernt.
///
/// Der Store macht **nur Datei-Arbeit**. Die Datenbank-Zeilen schreibt das
/// [JournalRepository]; die Zuordnung Datei ↔ Zeile läuft über den in der
/// zurückgegebenen [Attachment] gespeicherten Pfad.
class AttachmentStore {
  static const _subdir = 'attachments';
  static int _counter = 0;

  Directory? _dir;

  Future<Directory> _attachmentsDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// Kopiert das ausgewählte Bild in den App-privaten Speicher und liefert den
  /// fertigen [Attachment]. Das Original (temporäre Picker-Datei) bleibt
  /// unangetastet — wir arbeiten ab hier nur mit unserer eigenen Kopie.
  Future<Attachment> importImage({
    required String entryId,
    required String sourcePath,
    String? mimeType,
  }) async {
    final dir = await _attachmentsDir();
    final id = _newId();
    final ext = _extensionFor(sourcePath, mimeType);
    final destPath = p.join(dir.path, '$id$ext');
    await File(sourcePath).copy(destPath);
    return Attachment(
      id: id,
      entryId: entryId,
      filePath: destPath,
      mimeType: mimeType,
      createdAt: DateTime.now(),
    );
  }

  /// Löscht die übergebenen Dateien (Vollbild und ggf. Miniatur) — best effort.
  /// Eine bereits fehlende Datei ist kein Fehler: Ziel ist, dass hinterher
  /// nichts mehr da ist, nicht dass jede Datei genau einmal existierte.
  Future<void> deleteFiles(Iterable<String?> paths) async {
    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // Bewusst geschluckt: ein nicht löschbarer Rest darf den Ablauf
        // (Eintrag löschen, Bild ersetzen) nicht scheitern lassen.
      }
    }
  }

  /// Löscht alle Dateien eines Anhangs (Vollbild + reservierte Miniatur).
  Future<void> deleteAttachment(Attachment a) =>
      deleteFiles([a.filePath, a.thumbPath]);

  String _newId() =>
      'att_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Endung aus dem Quellpfad, sonst aus dem MIME-Typ, sonst `.img`.
  String _extensionFor(String sourcePath, String? mimeType) {
    final ext = p.extension(sourcePath).toLowerCase();
    if (ext.isNotEmpty && ext.length <= 5) return ext;
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      case 'image/gif':
        return '.gif';
    }
    return '.img';
  }
}
