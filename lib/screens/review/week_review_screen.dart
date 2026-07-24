import 'package:flutter/material.dart';

import '../../data/journal_repository.dart';
import '../../services/claude_service.dart';
import '../../services/week_context.dart';
import '../settings/claude_settings_screen.dart';

const Color _kBg = Color(0xFF1A1A2E);
const Color _kCard = Color(0xFF16213E);
const Color _kAccent = Color(0xFF4A90D9);
const Color _kError = Color(0xFFD96A6A);

/// Wochenauswertung durch Claude (Architektur §8).
///
/// Der Screen wählt das Fenster, stellt den Kontext zusammen, schickt ihn und
/// zeigt das Ergebnis. Geschrieben wird hier **nichts**: Bei „Ins Journal
/// übernehmen" gibt er den Text via `Navigator.pop` zurück, und das Journal
/// legt den Eintrag an — derselbe Schnitt wie beim Such-Screen und beim
/// Aufgaben-Sheet. Persistenz bleibt an einer Stelle.
class WeekReviewScreen extends StatefulWidget {
  const WeekReviewScreen({super.key});

  @override
  State<WeekReviewScreen> createState() => _WeekReviewScreenState();
}

class _WeekReviewScreenState extends State<WeekReviewScreen> {
  final JournalRepository _repo = JournalRepository();
  final ClaudeService _claude = ClaudeService();

  /// Das beim Öffnen vorgeschlagene Fenster. Bleibt stehen — es ist zugleich
  /// die Obergrenze fürs Vorwärtsblättern.
  late final WeekWindow _suggested;

  late WeekWindow _window;

  String? _context;
  bool _loadingContext = true;

  String? _result;
  bool _running = false;

  bool _contextExpanded = false;

  @override
  void initState() {
    super.initState();
    _suggested = WeekWindow.suggested(DateTime.now());
    _window = _suggested;
    _loadContext();
  }

  /// Stellt den Kontext des aktuellen Fensters zusammen.
  ///
  /// Ein vorhandenes Ergebnis fällt dabei weg: Es gehörte zur vorigen Woche,
  /// und ein Text, der zur Überschrift darüber nicht passt, ist schlimmer als
  /// gar keiner.
  Future<void> _loadContext() async {
    final window = _window;
    setState(() {
      _loadingContext = true;
      _context = null;
      _result = null;
      _contextExpanded = false;
    });
    final text = await WeekContext.build(_repo, window);
    if (!mounted) return;
    // Zwischenzeitlich weitergeblättert? Dann gehört dieser Kontext zu einer
    // Woche, die nicht mehr im Kopf steht.
    if (_window.monday != window.monday) return;
    setState(() {
      _context = text;
      _loadingContext = false;
    });
  }

  void _shift(int weeks) {
    final next = _window.shiftedWithin(weeks, _suggested);
    if (next.monday == _window.monday) return;
    setState(() => _window = next);
    _loadContext();
  }

  Future<void> _run() async {
    final payload = _context;
    if (payload == null || _running) return;

    if (!await _claude.hasKey()) {
      if (!mounted) return;
      await _showErrorDialog(const ClaudeException(
        ClaudeErrorKind.noKey,
        'Kein API-Schlüssel hinterlegt.',
      ));
      return;
    }

    setState(() => _running = true);
    String text;
    try {
      text = await _claude.reviewWeek(payload);
    } on ClaudeException catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      if (e.kind == ClaudeErrorKind.network) {
        _snack(e.message);
      } else {
        await _showErrorDialog(e);
      }
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      _snack(e.toString());
      return;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = text;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _kCard),
    );
  }

  /// Fehler mit Statuscode und API-Meldung — nicht verschlucken. Bei fehlendem
  /// oder abgelehntem Schlüssel führt der Dialog direkt in die Einstellungen.
  Future<void> _showErrorDialog(ClaudeException e) {
    final toSettings =
        e.kind == ClaudeErrorKind.auth || e.kind == ClaudeErrorKind.noKey;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text(
          'Auswertung fehlgeschlagen',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Text(
            '${e.message}\n\nEs wurde nichts gespeichert.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Schließen',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          if (toSettings)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClaudeSettingsScreen(),
                  ),
                );
              },
              child: const Text('Einstellungen'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        iconTheme: const IconThemeData(color: Colors.white54),
        title: const Text(
          'WOCHENAUSWERTUNG',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: _buildBody()),
          if (_result != null) _buildResultActions(),
        ],
      ),
    );
  }

  /// Wochenwahl: zwei Pfeile und das Fenster im Klartext. Vorwärts ist beim
  /// vorgeschlagenen Fenster gedeckelt — es gibt nichts auszuwerten, was noch
  /// nicht stattgefunden hat.
  Widget _buildHeader() {
    final forward = _window.canGoForward(_suggested);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: Colors.white70,
            tooltip: 'Eine Woche zurück',
            onPressed: () => _shift(-1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _window.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
                if (_window.isPartial)
                  Text(
                    'läuft noch — bis einschließlich '
                    '${WeekWindow.formatFull(_window.lastDay)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: forward ? Colors.white70 : Colors.white12,
            tooltip: forward ? 'Eine Woche vor' : 'Aktuellste Woche',
            onPressed: forward ? () => _shift(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingContext) {
      return const Center(
        child: CircularProgressIndicator(color: _kAccent),
      );
    }
    final contextText = _context ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContextExpander(contextText),
          const SizedBox(height: 20),
          if (_result == null) _buildRunSection(),
          if (_result != null) _buildResult(_result!),
        ],
      ),
    );
  }

  /// Der zusammengestellte Kontext im Rohtext, eingeklappt.
  ///
  /// Nicht nur ein Blick hinter die Kulissen: Solange kein API-Zugang
  /// besteht, ist das die einzige Möglichkeit zu prüfen, ob die Woche
  /// vollständig und richtig eingesammelt wurde. Auch beim späteren Feilen am
  /// Prompt ist es das erste, was man sehen will.
  Widget _buildContextExpander(String text) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        // Die Trennlinien der ExpansionTile passen nicht zum dunklen Kasten.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Neuer Schlüssel je Woche: Beim Blättern wird die Kachel neu
          // gebaut und klappt zu, statt den Kontext der vorigen Woche
          // aufgeklappt stehen zu lassen.
          key: ValueKey(_window.monday),
          initiallyExpanded: _contextExpanded,
          onExpansionChanged: (v) => _contextExpanded = v,
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white38,
          title: const Text(
            'Kontext anzeigen',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          subtitle: Text(
            '${text.length} Zeichen',
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SelectableText(
              text,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunSection() {
    if (_running) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kAccent,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Claude liest die Woche …',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Das kann bis zu zwei Minuten dauern.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _kAccent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        onPressed: _run,
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Text('Auswerten'),
      ),
    );
  }

  Widget _buildResult(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _kAccent, width: 3)),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }

  /// Übernehmen oder verwerfen. Erst „Übernehmen" schreibt etwas — und auch
  /// das nicht hier, sondern im Journal.
  Widget _buildResultActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _kError),
            onPressed: () => setState(() => _result = null),
            child: const Text('Verwerfen'),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () => Navigator.pop(context, _result),
            child: const Text('Ins Journal übernehmen'),
          ),
        ],
      ),
    );
  }
}
