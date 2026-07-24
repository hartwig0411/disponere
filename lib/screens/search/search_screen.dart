import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/journal_repository.dart';
import '../../models/search_hit.dart';

/// Volltextsuche über die Journal-Einträge (Architektur §9).
///
/// Bewusst schmal gehalten: Suchfeld, Trefferliste, Tippen öffnet den
/// Eintrag. Kein Ranking, keine Tag-Filter, keine Hervorhebung des Begriffs
/// im Text. Aufgaben, Tagesinfos und Termine bleiben in v1.0 außen vor.
///
/// **Rückgabewert:** die Id des angetippten Eintrags via `Navigator.pop`.
/// Der Screen öffnet den Eintrag **nicht selbst** — Persistenz und
/// Editor-Aufruf liegen beim Journal, derselbe Schnitt wie beim
/// Aufgaben-Sheet und beim Tinten-Editor. Dieser Screen liest nur.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// Ab wie vielen Zeichen gesucht wird. Ein einzelner Buchstabe träfe
  /// nahezu jeden Eintrag und wäre keine Antwort, sondern eine Liste.
  /// Umkehrbar — reine Abwägung.
  static const _minQueryLength = 2;

  /// Wartezeit nach dem letzten Tastendruck, bevor gesucht wird. Verhindert
  /// eine Abfrage je Buchstabe, ohne sich beim Tippen träge anzufühlen.
  static const _debounce = Duration(milliseconds: 250);

  final JournalRepository _repo = JournalRepository();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _timer;
  List<SearchHit> _hits = const <SearchHit>[];
  bool _searching = false;

  /// Der Begriff, zu dem [_hits] gehört. Nur damit die Leermeldung den
  /// tatsächlich gesuchten Begriff nennt und nicht den halb getippten.
  String _shownQuery = '';

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _timer?.cancel();
    final query = value.trim();

    if (query.length < _minQueryLength) {
      setState(() {
        _hits = const <SearchHit>[];
        _shownQuery = '';
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _timer = Timer(_debounce, () => _run(query));
  }

  Future<void> _run(String query) async {
    final hits = await _repo.searchEntries(query);
    if (!mounted) return;
    // Zwischenzeitlich weitergetippt? Dann gehört dieses Ergebnis zu einem
    // Begriff, der nicht mehr im Feld steht — verwerfen.
    if (_controller.text.trim() != query) return;
    setState(() {
      _hits = hits;
      _shownQuery = query;
      _searching = false;
    });
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    setState(() {
      _hits = const <SearchHit>[];
      _shownQuery = '';
      _searching = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          style: const TextStyle(color: Colors.white, fontSize: 17),
          cursorColor: const Color(0xFF4A90D9),
          decoration: const InputDecoration(
            hintText: 'Einträge durchsuchen',
            hintStyle: TextStyle(color: Colors.white24, fontSize: 17),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              tooltip: 'Leeren',
              onPressed: _clear,
            ),
        ],
      ),
      body: _buildBody(query),
    );
  }

  Widget _buildBody(String query) {
    if (query.length < _minQueryLength) {
      return const _SearchHint(
        icon: Icons.search,
        text: 'Volltext über Einträge und erkannte Tinte.\n'
            'Mindestens zwei Zeichen.',
      );
    }
    // Reihenfolge mit Absicht: Liegt bereits ein Ergebnis vor, bleibt es
    // während der nächsten Abfrage stehen. Sonst flackerte bei jedem
    // Buchstaben eine Ladeanzeige durch die Liste.
    if (_hits.isEmpty) {
      if (_searching) {
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF4A90D9),
            ),
          ),
        );
      }
      return _SearchHint(
        icon: Icons.search_off,
        text: 'Keine Treffer für „$_shownQuery".',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            _hits.length == 1 ? '1 Treffer' : '${_hits.length} Treffer',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: _hits.length,
            itemBuilder: (context, index) {
              final hit = _hits[index];
              return _HitCard(
                hit: hit,
                onTap: () => Navigator.pop(context, hit.entryId),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Leerzustand — Einstiegshinweis und „keine Treffer" teilen sich die Form.
class _SearchHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SearchHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  final SearchHit hit;
  final VoidCallback onTap;
  const _HitCard({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatStamp(hit.timestamp),
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (hit.isInk) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.brush, size: 12, color: Colors.white24),
                    ],
                    const Spacer(),
                    // Ein Treffer in der Maschinenerkennung wird als solcher
                    // ausgewiesen. Wer nicht weiß, dass der Fund aus einer
                    // Erkennung stammt, hält ihn für seinen eigenen Wortlaut.
                    if (hit.fromInkText)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'erkannter Text',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hit.snippet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `24.07.2026 · 05:14` — Datum ausgeschrieben, weil ein Treffer aus dem
  /// Zusammenhang gerissen ist und die Uhrzeit allein nichts einordnet.
  static String _formatStamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} · '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
