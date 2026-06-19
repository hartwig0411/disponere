/// Wandelt einen rohen Tag-String in eine bereinigte Tag-Liste.
/// Tags werden per '#' markiert/getrennt: "#MBS #ValSys #Vertrag".
/// Leerzeichen werden getrimmt, leere Segmente ignoriert.
/// Ein einzelner Tag ohne '#' wird ebenfalls akzeptiert.
List<String> parseTags(String raw) {
  return raw
      .split('#')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}