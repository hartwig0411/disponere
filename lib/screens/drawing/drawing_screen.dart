import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../models/ink_data.dart';
import '../../services/claude_service.dart';
import '../../utils/ink_renderer.dart';
import '../../utils/tag_parser.dart';
import '../../widgets/ink_painter.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../settings/claude_settings_screen.dart';

import '../../theme/app_colors.dart';

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

  /// Die Rolle scrollt vertikal; der Controller treibt das Autoscroll beim
  /// Schreiben ins untere Band.
  final ScrollController _scrollController = ScrollController();

  /// Aktuelle Groesse des sichtbaren Zeichenfensters (Viewport), aus dem
  /// LayoutBuilder. Bezugsgroesse fuers Wachsen, Folgen und Breiten-Fit.
  Size _viewport = Size.zero;

  /// Volle Laenge der Rolle (Inhaltshoehe). Waechst nach unten mit und ist die
  /// gespeicherte Hoehe des Eintrags. 0 = vor dem ersten Layout.
  double _rollHeight = 0;

  /// Tiefster bisher geschriebene Punkt (Inhalts-Y). Bestimmt zusammen mit dem
  /// Puffer die Wunschhoehe der Rolle.
  double _lowestY = 0;

  /// Puffer leerer Rolle unter der tiefsten Tinte (Anteil einer Viewport-Hoehe)
  /// — Platz zum Weiterschreiben und Garant, dass das Autoscroll-Ziel stets
  /// innerhalb der Scrollstrecke liegt.
  static const double _bottomPadFactor = 0.5;

  /// Beim Schreiben gehaltene Hoehe der Schreibzeile ueber der Unterkante
  /// (Anteil einer Viewport-Hoehe): die Rolle folgt, sobald der Stift tiefer
  /// als dieses Band kommt.
  static const double _followBandFactor = 0.28;

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
        _fitLoadedInkToWidth(Size(ink.width, ink.height));
      });
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Passt geladene Striche an die aktuelle **Breite** an (uniform skaliert,
  /// linksbuendig, oben beginnend) und setzt die Rollenlaenge entsprechend.
  ///
  /// Weg A: Die Rolle fittet beim Laden nur noch auf die Breite — nicht mehr in
  /// einen bildschirmgrossen Kasten. Ein langer Eintrag oeffnet damit in voller
  /// Laenge und wird durch Scrollen weitergeschrieben, statt gestaucht zu
  /// werden. Gleiche Breite -> Faktor 1, keine Verzerrung.
  void _fitLoadedInkToWidth(Size from) {
    if (from.width <= 0) return;
    final vw = _viewport.width;
    if (vw <= 0) return;
    final scale = vw / from.width;
    setState(() {
      if ((scale - 1.0).abs() >= 0.001) {
        for (final stroke in _strokes) {
          for (int i = 0; i < stroke.length; i++) {
            stroke[i] = Offset(stroke[i].dx * scale, stroke[i].dy * scale);
          }
        }
      }
      _lowestY = _computeLowestY();
      if (_rollHeight < _desiredRollHeight) _rollHeight = _desiredRollHeight;
    });
  }

  /// Tiefster Y-Wert ueber alle Striche (Inhalts-Koordinaten); 0 bei leer.
  double _computeLowestY() {
    double low = 0;
    for (final stroke in _strokes) {
      for (final p in stroke) {
        if (p.dy > low) low = p.dy;
      }
    }
    return low;
  }

  /// Wunschhoehe der Rolle: tiefste Tinte plus Puffer, mindestens eine
  /// Viewport-Hoehe.
  double get _desiredRollHeight {
    final vh = _viewport.height;
    final needed = _lowestY + vh * _bottomPadFactor;
    return needed > vh ? needed : vh;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    if (_erasing) {
      _eraseAt(event.localPosition);
      return;
    }
    final p = event.localPosition; // Inhalts-Koordinate (Listener in der Rolle)
    setState(() {
      _strokes.add([p]);
      _growForPoint(p);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return;
    if (_erasing) {
      _eraseAt(event.localPosition);
      return;
    }
    if (_strokes.isEmpty) return;
    final p = event.localPosition; // Inhalts-Koordinate
    setState(() {
      _strokes.last.add(p);
      _growForPoint(p);
    });
    _followPen(p.dy);
  }

  /// Merkt sich den tiefsten Punkt und laesst die Rolle bei Bedarf nach unten
  /// mitwachsen. Aufruf innerhalb von setState.
  void _growForPoint(Offset p) {
    if (p.dy > _lowestY) _lowestY = p.dy;
    final desired = _desiredRollHeight;
    if (desired > _rollHeight) _rollHeight = desired;
  }

  /// Autoscroll: kommt die Schreibzeile tiefer als das untere Band, rollt die
  /// Flaeche mit, sodass die Zeile auf komfortabler Hoehe bleibt („das Papier
  /// rollt unter dem Stift hoch"). jumpTo statt animateTo — 1:1 folgend, ohne
  /// Nachlauf; das Ziel liegt dank Puffer stets innerhalb der Scrollstrecke.
  void _followPen(double penContentY) {
    if (!_scrollController.hasClients) return;
    final vh = _viewport.height;
    if (vh <= 0) return;
    final band = vh * _followBandFactor;
    final penViewportY = penContentY - _scrollController.offset;
    if (penViewportY > vh - band) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final target = (penContentY - (vh - band)).clamp(0.0, maxExtent);
      if ((target - _scrollController.offset).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    }
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
        backgroundColor: AppColors.paper,
        title: const Text(
          'Erkannter Text',
          style: TextStyle(color: AppColors.text, fontSize: 16),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: AppColors.iconInactive,
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
              style: TextStyle(color: AppColors.iconInactive),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
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
        backgroundColor: AppColors.paper,
        title: const Text(
          'Kein API-Schlüssel',
          style: TextStyle(color: AppColors.text, fontSize: 16),
        ),
        content: const Text(
          'Für die Auswertung braucht Disponere deinen Anthropic-Schlüssel.',
          style: TextStyle(color: AppColors.iconInactive),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Später',
              style: TextStyle(color: AppColors.iconInactive),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
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
        backgroundColor: AppColors.text,
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
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        // ExpansionTile zieht seine Trennlinien aus dem Theme; hier stören sie.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _inkTextExpanded,
          key: ValueKey(_inkTextAt),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          iconColor: AppColors.iconInactive,
          collapsedIconColor: AppColors.iconInactive,
          title: const Text(
            'ERKANNTER TEXT',
            style: TextStyle(
              color: AppColors.iconInactive,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          subtitle: at != null
              ? Text(
                  'Ausgewertet am ${_formatStamp(at)}',
                  style: const TextStyle(color: AppColors.placeholder, fontSize: 11),
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
                    color: AppColors.text,
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
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: const Text(
          'Tinte',
          style: TextStyle(color: AppColors.iconInactive, fontSize: 16),
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
                      color: AppColors.accent,
                    ),
                  )
                : Icon(
                    Icons.auto_awesome,
                    color: alreadyTranscribed
                        ? AppColors.accent
                        : AppColors.iconInactive,
                  ),
            tooltip: alreadyTranscribed
                ? 'Erneut auswerten'
                : 'Handschrift auswerten',
            onPressed: _transcribing ? null : _transcribe,
          ),
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              color: _erasing ? AppColors.accent : AppColors.iconInactive,
            ),
            tooltip: _erasing ? 'Radierer aktiv' : 'Radieren',
            onPressed: () => setState(() => _erasing = !_erasing),
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: AppColors.iconInactive),
            tooltip: 'Letzten Strich zurück',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: AppColors.iconInactive),
            tooltip: 'Alles löschen',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.accent),
            tooltip: 'Übernehmen',
            onPressed: _strokes.isEmpty ? null : _confirm,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewport = Size(constraints.maxWidth, constraints.maxHeight);
                // Rollenhoehe nach dem ersten Layout (bzw. nach dem Laden)
                // nachziehen — nach dem Frame, nie synchron im build.
                if (_rollHeight < _desiredRollHeight) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (_rollHeight < _desiredRollHeight) {
                      setState(() => _rollHeight = _desiredRollHeight);
                    }
                  });
                }
                final height = _rollHeight < _viewport.height
                    ? _viewport.height
                    : _rollHeight;
                return ScrollConfiguration(
                  // Stift zeichnet, Finger scrollt: der Stylus ist als
                  // Scroll-Geraet ausgeschlossen, damit die Rolle nicht wegrollt,
                  // waehrend der M-Pencil schreibt (dieselbe Trennung wie die
                  // bestehende Palm-Rejection).
                  behavior: const _StylusExcludedScrollBehavior(),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      child: SizedBox(
                        key: _canvasKey,
                        width: _viewport.width,
                        height: height,
                        child: CustomPaint(
                          painter: InkLivePainter(_strokes),
                          size: Size(_viewport.width, height),
                        ),
                      ),
                    ),
                  ),
                );
              },
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

/// Scroll-Verhalten der Tinten-Rolle: der Stift (`stylus`) ist als
/// Scroll-Geraet ausgeschlossen — er ist zum Zeichnen reserviert. Finger und
/// Maus/Trackpad scrollen wie gewohnt. So rollt die Flaeche nicht weg, waehrend
/// der M-Pencil schreibt; das Autoscroll uebernimmt das Nachfuehren.
class _StylusExcludedScrollBehavior extends MaterialScrollBehavior {
  const _StylusExcludedScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
