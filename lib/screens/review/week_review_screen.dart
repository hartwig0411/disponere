import 'package:flutter/material.dart';

import '../../data/journal_repository.dart';
import '../../services/claude_service.dart';
import '../../services/review_settings.dart';
import '../../services/week_context.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../settings/claude_settings_screen.dart';

import '../../theme/app_colors.dart';

const Color _kBg = AppColors.paper;
const Color _kCard = AppColors.fieldFill;
const Color _kAccent = AppColors.accent;
const Color _kError = AppColors.danger;

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
  final ReviewSettings _settings = ReviewSettings();

  /// Das beim Öffnen vorgeschlagene Fenster. Bleibt stehen — es ist zugleich
  /// die Obergrenze fürs Vorwärtsblättern.
  late final WeekWindow _suggested;

  late WeekWindow _window;

  String? _context;
  bool _loadingContext = true;

  String? _result;
  bool _running = false;

  bool _contextExpanded = false;

  /// E-02 „Nicht Auswerten": die global ausgeschlossenen Tags (kanonisch, ohne
  /// '#') und das Eingabefeld dazu. Die Liste ist eine app-weite Einstellung,
  /// beim Öffnen vorbefüllt und beim „Übernehmen" zurückgeschrieben.
  final TextEditingController _excludeController = TextEditingController();
  final TagRegistry _tagRegistry = TagRegistry();
  List<String> _knownTags = const [];
  List<String> _excludedTags = const [];

  @override
  void initState() {
    super.initState();
    _suggested = WeekWindow.suggested(DateTime.now());
    _window = _suggested;
    _excludeController.addListener(_onExcludeChanged);
    _init();
  }

  @override
  void dispose() {
    _excludeController.removeListener(_onExcludeChanged);
    _excludeController.dispose();
    super.dispose();
  }

  void _onExcludeChanged() => setState(() {});

  /// Lädt die gespeicherte Ausschlussliste und die bekannten Tags, füllt das
  /// Feld vor und baut dann den ersten Kontext.
  Future<void> _init() async {
    final excluded = await _settings.excludedTags();
    if (!mounted) return;
    setState(() {
      _excludedTags = excluded;
      _excludeController.text = formatTags(excluded);
    });
    await _loadKnownTags();
    await _loadContext();
  }

  /// Sammelt die bekannten Tags fürs Autocomplete aus Aufgaben, Kalender-
  /// Zuordnungen und den Einträgen des aktuellen Fensters.
  Future<void> _loadKnownTags() async {
    final tasks = await _repo.loadAllTasks();
    final sources = await _repo.loadCalendarSources();
    final entries = await _repo.entriesInRange(_window.monday, _window.lastDay);
    _tagRegistry.rebuildFrom([
      ...entries.reversed.map((e) => e.tags),
      ...tasks.map((t) => t.tags),
      ...sources.map((c) => c.tags),
    ]);
    if (!mounted) return;
    setState(() => _knownTags = _tagRegistry.allTags);
  }

  /// Übernimmt die im Feld getippten Tags als globale Ausschlussliste: parsen,
  /// kanonisieren, speichern und den Kontext neu bauen, damit Vorschau und
  /// Payload den Filter sofort widerspiegeln.
  Future<void> _applyExcluded() async {
    final parsed =
        _tagRegistry.canonicalizeAll(parseTags(_excludeController.text));
    setState(() {
      _excludedTags = parsed;
      _excludeController.text = formatTags(parsed);
      _knownTags = _tagRegistry.allTags;
    });
    await _settings.setExcludedTags(parsed);
    await _loadContext();
  }

  /// Weicht das Feld von der gespeicherten Liste ab? (Reihenfolge und Groß-/
  /// Kleinschreibung egal.) Steuert, ob „Übernehmen" aktiv ist.
  bool get _excludeDirty {
    final a =
        parseTags(_excludeController.text).map((t) => t.toLowerCase()).toSet();
    final b = _excludedTags.map((t) => t.toLowerCase()).toSet();
    return a.length != b.length || !a.containsAll(b);
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
    final text = await WeekContext.build(
      _repo,
      window,
      excludedTags: _excludedTags.map((t) => t.toLowerCase()).toSet(),
    );
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
      SnackBar(content: Text(message), backgroundColor: AppColors.text),
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
        backgroundColor: AppColors.paper,
        title: const Text(
          'Auswertung fehlgeschlagen',
          style: TextStyle(color: AppColors.text, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Text(
            '${e.message}\n\nEs wurde nichts gespeichert.',
            style: const TextStyle(color: AppColors.iconInactive, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Schließen',
              style: TextStyle(color: AppColors.iconInactive),
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
        iconTheme: const IconThemeData(color: AppColors.iconInactive),
        title: const Text(
          'WOCHENAUSWERTUNG',
          style: TextStyle(
            color: AppColors.iconInactive,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: AppColors.hairline),
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
            color: AppColors.iconInactive,
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
                    color: AppColors.text,
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
                      color: AppColors.iconInactive,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: forward ? AppColors.iconInactive : AppColors.hairline,
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
          _buildExcludeSection(),
          const SizedBox(height: 16),
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
  /// E-02 „Nicht Auswerten": Tags, die aus der Auswertung fallen sollen.
  /// Vorbefüllt mit der gespeicherten Liste; „Übernehmen" schreibt zurück und
  /// baut den Kontext neu, sodass die Vorschau den Filter sofort zeigt.
  Widget _buildExcludeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nicht auswerten',
          style: TextStyle(
            color: AppColors.iconInactive,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Diese Tags fließen nicht in die Auswertung. Ein Eintrag, Termin oder '
          'eine Aufgabe fällt nur heraus, wenn alle seine Tags hier stehen.',
          style: TextStyle(
            color: AppColors.weekday,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        TagAutocompleteField(
          controller: _excludeController,
          knownTags: _knownTags,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: _kAccent),
            onPressed: _excludeDirty ? _applyExcluded : null,
            child: const Text('Übernehmen'),
          ),
        ),
      ],
    );
  }

  Widget _buildContextExpander(String text) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        // Die Trennlinien der ExpansionTile passen nicht zum hellen Kasten.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Neuer Schlüssel je Woche: Beim Blättern wird die Kachel neu
          // gebaut und klappt zu, statt den Kontext der vorigen Woche
          // aufgeklappt stehen zu lassen.
          key: ValueKey(_window.monday),
          initiallyExpanded: _contextExpanded,
          onExpansionChanged: (v) => _contextExpanded = v,
          iconColor: AppColors.iconInactive,
          collapsedIconColor: AppColors.iconInactive,
          title: const Text(
            'Kontext anzeigen',
            style: TextStyle(color: AppColors.iconInactive, fontSize: 14),
          ),
          subtitle: Text(
            '${text.length} Zeichen',
            style: const TextStyle(color: AppColors.weekday, fontSize: 11),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SelectableText(
              text,
              style: const TextStyle(
                color: AppColors.iconInactive,
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
                style: TextStyle(color: AppColors.iconInactive),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Das kann bis zu zwei Minuten dauern.',
            style: TextStyle(color: AppColors.weekday, fontSize: 12),
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
          color: AppColors.text,
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
        border: Border(top: BorderSide(color: AppColors.hairline)),
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
