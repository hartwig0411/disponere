/// Ein an einen Journal-Eintrag angehängtes Bild (Schema v7, Session A).
///
/// Das Bild selbst liegt als Datei im **App-privaten Speicher** (siehe
/// `AttachmentStore`); in der Datenbank steht nur der Pfad. Damit bleibt die
/// `attachments`-Tabelle schlank und die Bilder tauchen nicht in der
/// Geräte-Galerie auf — ein Journal-Bild gehört ins Journal, nicht ins
/// Foto-Album.
///
/// Das Datenmodell ist bewusst **1:n** angelegt (`entryId` + `ord`), auch wenn
/// die Oberfläche vorerst nur **ein** Bild pro Eintrag zulässt. So kostet der
/// Schritt zu mehreren Bildern später keine zweite Schema-Migration.
class Attachment {
  final String id;

  /// Eintrag, zu dem der Anhang gehört. Fremdschlüssel auf `entries.id`
  /// (ON DELETE CASCADE — die Zeile verschwindet mit dem Eintrag; die Datei
  /// räumt der Aufrufer über `delete` → `AttachmentStore.deleteFiles` weg).
  final String entryId;

  /// Absoluter Pfad der Bilddatei im App-privaten Speicher.
  final String filePath;

  /// Reserviert für eine später separat gespeicherte Miniatur. Vorerst `null`
  /// — die Eintragskarte rendert die Miniatur direkt aus [filePath] über
  /// `cacheWidth`, ohne eigene Datei. Die Spalte steht bereit, falls die
  /// Miniaturerzeugung je ausgelagert werden soll (keine Migration nötig).
  final String? thumbPath;

  /// MIME-Typ, falls bekannt (z. B. `image/jpeg`). Nur informativ.
  final String? mimeType;

  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.entryId,
    required this.filePath,
    this.thumbPath,
    this.mimeType,
    required this.createdAt,
  });

  Attachment copyWith({
    String? id,
    String? entryId,
    String? filePath,
    String? thumbPath,
    String? mimeType,
    DateTime? createdAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      filePath: filePath ?? this.filePath,
      thumbPath: thumbPath ?? this.thumbPath,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
