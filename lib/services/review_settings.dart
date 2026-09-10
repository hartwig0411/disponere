import 'package:shared_preferences/shared_preferences.dart';

/// Persistente Einstellungen der Wochenauswertung.
///
/// Aktuell nur die globale Ausschlussliste für das Feld „Nicht Auswerten"
/// (E-02): eine einzelne, nicht-geheime, app-weite Liste von Tags, die aus der
/// Auswertung fallen. Bewusst in `shared_preferences` und nicht im SQLite-
/// Schema abgelegt — kein Schema-Eingriff, die Ablage ist reversibel. Die
/// eigentlichen Daten (Einträge, Aufgaben, Termine) liegen unverändert in
/// SQLite; hier lebt allein die Filter-Einstellung.
class ReviewSettings {
  static const String _excludedTagsKey = 'week_review_excluded_tags';

  /// Die global ausgeschlossenen Tags (kanonische Schreibweise, ohne '#').
  /// Leere Liste, wenn noch nichts gesetzt wurde.
  Future<List<String>> excludedTags() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_excludedTagsKey) ?? const [];
  }

  /// Schreibt die Ausschlussliste zurück. Eine leere Liste entfernt den
  /// Schlüssel wieder — so bleibt „nichts ausgeschlossen" der saubere
  /// Ausgangszustand.
  Future<void> setExcludedTags(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    if (tags.isEmpty) {
      await prefs.remove(_excludedTagsKey);
    } else {
      await prefs.setStringList(_excludedTagsKey, tags);
    }
  }
}
