import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../models/ink_data.dart';
import '../../services/claude_service.dart';
import '../../utils/ink_renderer.dart';
import '../../utils/tag_parser.dart';
import '../../widgets/ink_painter.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../settings/claude_settings_screen.dart';

/// Rückgabe des Tinten-Editors: die Striche (mit Canvas-Größe) + Tags.
class InkResult {
  final InkData ink;
  final List<String> tags;
  const InkResult(this.ink, this.tags);
}

/// Tinten-Modus: handschriftliche Eingabe als Strichdaten (Vektoren).
/// Keine OCR/Umwandlung — die Handschrift bleibt erhalten und der Eintrag
/// ist editier- und weiterschreibbar.
///
/// Mit [initialInk] werden vorhandene Striche zum Weiterschreiben geladen.
///
/// **Auswertung durch Claude (Session 24):** Ist [onInkTextAccepted] gesetzt,
/// erscheint in der Kopfzeile ein Auswerten-Symbol. Der Editor rendert die
/// Striche zu einem Bild, holt den erkannten Text und zeigt ihn als Vorschau;
/// erst „Übernehmen" reicht ihn über den Callback an den Aufrufer weiter.
/// Der Editor selbst schreibt nichts in die Datenbank — Persistenz liegt beim
/// Aufrufer, wie beim Aufgaben-Sheet.
class DrawingScreen extends StatefulWidget {
  final InkData? initialInk;
  final List<String> initialTags;
  final List<String> knownTags;

  /// Bereits erkannter Text zu diesem Eintrag, falls schon ausgewertet.
  final String? initialInkText;

  /// Zeitpunkt dieser Auswertung.
  final DateTime? initialInkTextAt;

  /// Übernimmt den erkannten Text und gibt den Zeitstempel zurück, unter dem
  /// er gespeichert wurde. `null` = Auswertung hier nicht möglich (neuer,
  /// noch nicht gespeicherter Eintrag).
  final Future<DateTime> Function(String text)? onInkTextAccepted;

  const DrawingScreen({
    super.key,
    this.initialInk,
    this.initialTags = const [],
    this.knownTags = const [],
    this.initialInkText,
    this.initialInkTextAt,
    this.onInkTextAccepted,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _canvasKey = GlobalKey();
  late final TextEditingController _tagController;
  final ClaudeService _claude = ClaudeService();

  /// Radierer-Modus: Stift löscht ganze Striche, statt zu zeichnen.
  bool _erasing = false;

  /// Läuft gerade eine Auswertung? Sperrt das Symbol gegen Doppelauslösung.
  bool _transcribing = false;

  String? _inkText;
  DateTime? _inkTextAt;

  /// Ist der erkannte Text unten aufgeklappt? Nach einer frischen Auswertung
  /// ja, beim Öffnen eines alten Eintrags nein — dort soll die Handschrift
  /// den Platz haben.
  bool _inkTextExpanded = false;

  static const double _eraseThreshold = 18.0;

  @override
  void initState() {
    super.initState();
    _tagController =
        TextEditingController(text: formatTags(widget.initialTags));
    _inkText = widget.initialInkText;
    _inkTextAt = widget.initialInkTextAt;
    final ink = widget.initialInk;
    if (ink != null) {
      for (final s in ink.strokes) {
        _strokes.add(List<Offset>.from(s.points));
      }
      // Nach dem ersten Layout an die aktuelle Canvas-Größe anpassen — z.B.
      // wenn das Gerät zwischen Erstellen und Bearbeiten gedreht wurde.
      // Gleiche Größe → No-op (kein Eingriff in den Normalfall).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitLoadedInkToCanvas(Size(ink.width, ink.height));
      });
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  /// Rechnet die geladenen Striche von der gespeicherten Größe [from] auf die
  /// aktuelle Canvas-Größe um (uniform skaliert, zentriert — keine Verzerrung
  /// der Handschrift).
  void _fitLoadedInkToCanvas(Size from) {
    if (from.width <= 0 || from.height <= 0) return;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final to = box?.size;
    if (to == null || to.isEmpty) return;
    if ((to.width - from.width).abs() < 1 &&
        (to.height - from.height).abs() < 1) {
      return; // gleiche Größe → nichts zu tun
    }
    final scale = (to.width / from.width) < (to.height / from.height)
        ? to.width / from.width
        : to.height / from.height;
    final dx = (to.width - from.width * scale) / 2;
    final dy = (to.height - from.height * scale) / 2;
    setState(() {
      for (final stroke in _strokes) {
        for (int i = 0; i < stroke.length; i++) {
          stroke[i] =
              Offset(stroke[i].dx * scale + dx, stroke[i].dy * scale + dy);
        }
      }
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    if (_erasing) {
      _eraseAt(event.localPosition);
      return;
    }
    setState(() => _strokes.add([event.localPosition]));
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    if (_erasing) {
      _eraseAt(event.localPosition);
      return;
    }
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(event.localPosition));
  }

  /// Löscht alle Striche, die nah genug an [p] liegen (ganzer Strich).
  void _eraseAt(Offset p) {
    bool removed = false;
    _strokes.removeWhere((stroke) {
      final hit = _strokeHit(stroke, p);
      if (hit) removed = true;
      return hit;
    });
    if (removed) setState(() {});
  }

  bool _strokeHit(List<Offset> stroke, Offset p) {
    if (stroke.isEmpty) return false;
    if (stroke.length == 1) {
      return (stroke.first - p).distance <= _eraseThreshold;
    }
    for (int i = 0; i < stroke.length - 1; i++) {
      if (_distToSegment(p, stroke[i], stroke[i + 1]) <= _eraseThreshold) {
        return true;
      }
    }
    return false;
  }

  /// Kürzeste Distanz von Punkt [p] zur Strecke [a]–[b].
  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    double t =
        ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() => setState(() => _strokes.clear());

  /// Baut aus dem aktuellen Editor-Zustand ein [InkData].
  InkData _currentInk() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(0, 0);
    return InkData(
      strokes: _strokes.map((s) => InkStroke(List<Offset>.from(s))).toList(),
      width: size.width,
      height: size.height,
    );
  }

  void _confirm() {
    if (_strokes.isEmpty) return;
    Navigator.pop(
      context,
      InkResult(_currentInk(), parseTags(_tagController.text)),
    );
  }

  // ---------------------------------------------------------------------------
  // Auswertung durch Claude
  // ---------------------------------------------------------------------------

  /// Rendert die **aktuell sichtbaren** Striche und schickt sie zur
  /// Transkription.
  ///
  /// Bewusst der aktuelle Stand und nicht der gespeicherte: Ausgewertet wird,
  /// was der Nutzer vor sich sieht. Wer nach dem Weiterschreiben auswertet und
  /// den Editor danach mit „Zurück" verlässt, behält den erkannten Text zu
  /// Strichen, die er verworfen hat — ein Randfall, der ein erneutes
  /// Auswerten kostet und sonst nichts.
  Future<void> _transcribe() async {
    final accept = widget.onInkTextAccepted;
    if (accept == null) {
      _snack(
        'Diesen Eintrag zuerst mit dem Haken übernehmen — danach lässt er '
        'sich auswerten.',
      );
      return;
    }
    if (_strokes.isEmpty) {
      _snack('Nichts zu erkennen — der Bereich ist leer.');
      return;
    }
    if (!await _claude.hasKey()) {
      if (!mounted) return;
      await _showNoKeyDialog();
      return;
    }

    setState(() => _transcribing = true);
    String text;
    try {
      final base64Png = await InkRenderer.toBase64Png(_currentInk());
      text = await _claude.transcribeInk(base64Png);
    } on ClaudeException catch (e) {
      if (!mounted) return;
      setState(() => _transcribing = false);
      if (e.kind == ClaudeErrorKind.network) {
        _snack(e.message);
      } else {
        await _showErrorDialog(e);
      }
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _transcribing = false);
      _snack(e.toString());
      return;
    }
    if (!mounted) return;
    setState(() => _transcribing = false);

    final accepted = await _showTranscriptPreview(text);
    if (accepted != true) return; // Verwerfen → es wird nichts geschrieben

    final at = await accept(text);
    if (!mounted) return;
    setState(() {
      _inkText = text;
      _inkTextAt = at;
      _inkTextExpanded = true;
    });
    _snack('Text übernommen.');
  }

  /// Vorschau des erkannten Textes. Erst „Übernehmen" schreibt etwas.
  Future<bool?> _showTranscriptPreview(String text) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Erkannter Text',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Verwerfen',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoKeyDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Kein API-Schlüssel',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'Für die Auswertung braucht Disponere deinen Anthropic-Schlüssel.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Später',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
            ),
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

  /// Fehler mit Statuscode und API-Meldung — nicht verschlucken. Bei einem
  /// abgelehnten Schlüssel führt der Dialog direkt in die Einstellungen.
  Future<void> _showErrorDialog(ClaudeException e) {
    final toSettings =
        e.kind == ClaudeErrorKind.auth || e.kind == ClaudeErrorKind.noKey;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
              ),
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFF16213E),
      ),
    );
  }

  static String _formatStamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}, '
        '${two(d.hour)}:${two(d.minute)} Uhr';
  }

  /// Der erkannte Text unter der Handschrift — eingeklappt, damit er den
  /// Zeichenbereich nicht wegnimmt.
  Widget _buildInkTextPanel() {
    final text = _inkText;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final at = _inkTextAt;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        // ExpansionTile zieht seine Trennlinien aus dem Theme; hier stören sie.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _inkTextExpanded,
          key: ValueKey(_inkTextAt),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          iconColor: Colors.white38,
          collapsedIconColor: Colors.white38,
          title: const Text(
            'ERKANNTER TEXT',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          subtitle: at != null
              ? Text(
                  'Ausgewertet am ${_formatStamp(at)}',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                )
              : null,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alreadyTranscribed = _inkText != null && _inkText!.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Tinte',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          // Nur im Editor eines **bestehenden** Eintrags. Ein neuer Eintrag hat
          // noch keine id, an der ein erkannter Text haengen koennte — ein
          // Knopf, der da ist und nein sagt, ist schlechter als kein Knopf.
          if (widget.onInkTextAccepted != null)
          IconButton(
            icon: _transcribing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4A90D9),
                    ),
                  )
                : Icon(
                    Icons.auto_awesome,
                    color: alreadyTranscribed
                        ? const Color(0xFF4A90D9)
                        : Colors.white,
                  ),
            tooltip: alreadyTranscribed
                ? 'Erneut auswerten'
                : 'Handschrift auswerten',
            onPressed: _transcribing ? null : _transcribe,
          ),
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              color: _erasing ? const Color(0xFF4A90D9) : Colors.white,
            ),
            tooltip: _erasing ? 'Radierer aktiv' : 'Radieren',
            onPressed: () => setState(() => _erasing = !_erasing),
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            tooltip: 'Letzten Strich zurück',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            tooltip: 'Alles löschen',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF4A90D9)),
            tooltip: 'Übernehmen',
            onPressed: _strokes.isEmpty ? null : _confirm,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              child: RepaintBoundary(
                key: _canvasKey,
                child: CustomPaint(
                  painter: InkLivePainter(_strokes),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          _buildInkTextPanel(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TagAutocompleteField(
              controller: _tagController,
              knownTags: widget.knownTags,
            ),
          ),
        ],
      ),
    );
  }
}
