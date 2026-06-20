/// Zentrales Tag-Register.
///
/// Führt Schreibvarianten desselben Tags case-insensitiv zusammen
/// (z.B. "ValSys" und "valsys" → eine kanonische Schreibweise) und ist
/// die Grundlage für spätere Funktionen wie Autocomplete / "Meintest du …?".
///
/// Das Register ist abgeleitet: Es wird aus den vorhandenen Einträgen
/// aufgebaut (siehe [rebuildFrom]) und beim Anlegen/Bearbeiten inkrementell
/// ergänzt. Keine eigene Persistenz nötig — die Einträge speichern bereits
/// die kanonische Schreibweise.
class TagRegistry {
  /// normalisierter Schlüssel (lowercase) → kanonische Anzeige-Schreibweise
  final Map<String, String> _canonical = {};

  /// Registriert eine Schreibweise und gibt die kanonische zurück.
  /// Ist der Tag (case-insensitiv) bereits bekannt, gewinnt die zuerst
  /// registrierte Schreibweise.
  String canonicalize(String tag) {
    final key = tag.toLowerCase();
    return _canonical.putIfAbsent(key, () => tag);
  }

  /// Wie [canonicalize] für eine Liste — dedupliziert zusätzlich
  /// case-insensitiv unter Beibehaltung der Reihenfolge.
  List<String> canonicalizeAll(Iterable<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in tags) {
      final canonical = canonicalize(tag);
      if (seen.add(canonical.toLowerCase())) {
        result.add(canonical);
      }
    }
    return result;
  }

  /// Baut das Register neu auf (z.B. nach dem Laden der Einträge).
  /// Die Tag-Listen sollten chronologisch (ältester zuerst) kommen, damit
  /// die ursprüngliche Schreibweise gewinnt.
  void rebuildFrom(Iterable<List<String>> entryTagLists) {
    _canonical.clear();
    for (final tags in entryTagLists) {
      for (final tag in tags) {
        canonicalize(tag);
      }
    }
  }

  /// Alle bekannten Tags in kanonischer Schreibweise, alphabetisch.
  /// (Hook fürs spätere Autocomplete.)
  List<String> get allTags {
    final list = _canonical.values.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}