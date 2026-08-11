import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../data/journal_repository.dart';
import '../../models/attachment.dart';
import '../../models/journal_entry.dart';
import '../../models/daily_info.dart';
import '../../models/task.dart';
import '../../models/ink_data.dart';
import '../../models/calendar_event.dart';
import '../../models/calendar_source.dart';
import '../../services/attachment_store.dart';
import '../../services/share_receiver.dart';
import '../../services/share_service.dart';
import '../../screens/text/native_text_entry_screen.dart';
import '../../screens/drawing/drawing_screen.dart';
import '../../utils/tag_parser.dart';
import '../../utils/tag_registry.dart';
import '../../widgets/tag_autocomplete_field.dart';
import '../../widgets/task_sheet.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/tags/tag_management_screen.dart';
import '../../screens/tasks/task_overview_screen.dart';
import '../../screens/settings/calendar_settings_screen.dart';
import '../../screens/settings/claude_settings_screen.dart';
import '../../screens/review/week_review_screen.dart';
import 'widgets/date_header.dart';
import 'widgets/daily_info.dart';
import 'widgets/entry_card.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/today_panel.dart';
import 'widgets/today_due_tasks.dart';
import 'widgets/past_day.dart';

// Farben leben ab dem hellen Theme zentral in AppColors
// (lib/theme/app_colors.dart). Die frueheren provisorischen Akzente
// (Bernstein/Gruen/Violett) sind mit der Design-Entscheidung entfallen: ein
// ruhiges, grau getoentes Tagesinfo-Band, gedaempft-blaue Aufgaben-Kaestchen
// und ein blaues Kalender-Icon tragen jetzt alles ueber das eine Akzentblau.

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  /// Schluessel fuer das Oeffnen des Heute-Panels (endDrawer) aus der AppBar.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Kalendertag (`yyyy-MM-dd`), auf dem die Heute-Daten (_todayInfos/
  /// _todayTasks/_todayEvents und der Datumskopf) aktuell stehen. Wechselt der
  /// echte Tag ueber Mitternacht oder kehrt die App aus dem Hintergrund zurueck,
  /// werden die Heute-Daten neu geladen und dieser Schluessel nachgezogen
  /// (siehe [_refreshToday]). Frueher hingen diese Listen vom Vortag nach, weil
  /// sie nur in [initState] geladen wurden.
  String _shownDay = _dayKey(DateTime.now());

  final List<JournalEntry> _entries = [];

  /// Tagesinfos, die den **heutigen** Tag betreffen (oben im Journal).
  final List<DailyInfo> _todayInfos = [];

  /// Aufgaben, die **heute** im Journal erscheinen (fällig, überfällig oder
  /// ohne Day). Erledigte fallen heraus.
  final List<Task> _todayTasks = [];

  /// **Alle** Aufgaben — Grundlage für Tag-Register, Nutzungszähler und das
  /// Durchschreiben beim Tag-Umbenennen (nicht nur die heute sichtbaren).
  final List<Task> _allTasks = [];

  /// Kalender-Quellen — für das Tag-Register (damit auch ein nur an einem
  /// Kalender hängender Tag im Autocomplete auftaucht) und für die Frage,
  /// ob die TERMINE-Sektion überhaupt angezeigt wird.
  final List<CalendarSource> _calendarSources = [];

  /// Gespiegelte Kalendertermine, die den **heutigen** Tag berühren.
  final List<CalendarEvent> _todayEvents = [];

  /// Rohdaten der **vergangenen** Tage (Design 4b). Aufgaben mit Fälligkeit in
  /// der Vergangenheit (offen UND erledigt), Termine und Tagesinfos, die die
  /// Vergangenheit berühren. Die vergangenen **Einträge** kommen aus [_entries]
  /// (bereits vollständig geladen, in-place gepflegt) — deshalb hier nicht
  /// gespiegelt. Aus diesen Listen baut [build] pro Tag die Tagesgeschichte.
  final List<Task> _pastTasks = [];
  final List<CalendarEvent> _pastEvents = [];
  final List<DailyInfo> _pastInfos = [];

  final TagRegistry _tagRegistry = TagRegistry();
  final JournalRepository _repo = JournalRepository();
  final AttachmentStore _attachmentStore = AttachmentStore();
  final ImagePicker _imagePicker = ImagePicker();
  final ShareReceiver _shareReceiver = ShareReceiver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Empfang geteilter Inhalte (ACTION_SEND, Feature 2). Laufzeit-Shares
    // oeffnen direkt das Eintrags-Sheet; ein Kaltstart-Share wird nach dem
    // ersten Frame einmalig abgeholt und ebenso ins Sheet gereicht.
    _shareReceiver.onText = _handleSharedText;
    _shareReceiver.start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final shared = await _shareReceiver.getInitialSharedText();
      if (shared != null && mounted) {
        _openEntrySheet(initialContent: shared);
      }
    });
    _init();
  }

  @override
  void dispose() {
    _shareReceiver.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ein zur Laufzeit (App bereits offen) via ACTION_SEND geteilter Text:
  /// oeffnet das bestehende Eintrags-Sheet, vorbefuellt mit dem Inhalt. Tags
  /// ergaenzt der Nutzer; Speichern laeuft den gewoehnlichen Weg
  /// (_saveEntryFromSheet -> _addEntry) -> der Eintrag landet als ganz
  /// normaler Eintrag im heutigen Journal.
  void _handleSharedText(String text) {
    if (!mounted) return;
    _openEntrySheet(initialContent: text);
  }

  /// Beim App-Resume die Heute-Daten neu laden — sonst haengen Tagesinfo,
  /// Termine und Aufgaben des Vortags nach. Deckt auch den Mitternachtswechsel
  /// ab, wenn die App im Hintergrund lag. (Den Fall, dass die App im Vordergrund
  /// ueber Mitternacht offen bleibt, faengt zusaetzlich die Datumswaechter-
  /// Pruefung in [build] ab.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshToday();
    }
  }

  /// Startsequenz: Einmal-Migration aus shared_preferences (falls nötig),
  /// dann Einträge aus SQLite laden und das Tag-Register aufbauen.
  Future<void> _init() async {
    await _repo.migrateFromPrefsIfNeeded();
    final loaded = await _repo.loadAll();
    final infos = await _repo.dailyInfosForDay(DateTime.now());
    final surfaced = await _repo.surfacedTasksForDay(DateTime.now());
    final allTasks = await _repo.loadAllTasks();
    final calendarSources = await _repo.loadCalendarSources();
    final events = await _repo.calendarEventsForDay(_dayKey(DateTime.now()));
    if (!mounted) return;
    setState(() {
      _shownDay = _dayKey(DateTime.now());
      _entries
        ..clear()
        ..addAll(loaded);
      _todayEvents
        ..clear()
        ..addAll(events);
      _todayInfos
        ..clear()
        ..addAll(infos);
      _todayTasks
        ..clear()
        ..addAll(surfaced);
      _allTasks
        ..clear()
        ..addAll(allTasks);
      _calendarSources
        ..clear()
        ..addAll(calendarSources);
    });
    _rebuildTagRegistry();
    await _reloadPastAgenda();
  }

  /// Lädt Aufgaben, Termine und Tagesinfos der **Vergangenheit** neu (Design
  /// 4b). Grundlage der Tages-Gruppierung im Journal. Bewusst eine breite
  /// Zeitspanne (ab einem festen Boden bis gestern) — so wird jeder vergangene
  /// Tag erfasst, egal welcher Inhaltstyp ihn trägt; die Datenmenge eines
  /// Einzelnutzers macht das billig. Wird nach jeder relevanten Mutation
  /// aufgerufen, damit „Abhaken streicht alle Vorkommen" über den Neuaufbau
  /// aus dem Repository trägt (kein Widget-Cache, Design 4b).
  Future<void> _reloadPastAgenda() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final floor = DateTime(2000, 1, 1);
    final tasks = await _repo.tasksInRange(floor, yesterday);
    final events = await _repo.calendarEventsInRange(floor, yesterday);
    final infos = await _repo.dailyInfosInRange(floor, yesterday);
    if (!mounted) return;
    setState(() {
      _pastTasks
        ..clear()
        ..addAll(tasks);
      _pastEvents
        ..clear()
        ..addAll(events);
      _pastInfos
        ..clear()
        ..addAll(infos);
    });
  }

  /// Baut das Tag-Register aus **Einträgen, Aufgaben und Kalender-Quellen** auf.
  /// Einträge zuerst (chronologisch, ältester zuerst → erste Schreibweise
  /// gewinnt), danach Aufgaben und Kalender-Tags — so definieren Einträge die
  /// kanonische Schreibweise und die übrigen übernehmen sie. Damit erscheinen
  /// auch reine Aufgaben- oder Kalender-Tags im Autocomplete und in der
  /// Tag-Verwaltung.
  void _rebuildTagRegistry() {
    final lists = <List<String>>[
      ..._entries.reversed.map((e) => e.tags),
      ..._allTasks.map((t) => t.tags),
      ..._calendarSources.map((c) => c.tags),
    ];
    _tagRegistry.rebuildFrom(lists);
  }

  /// Lädt die heute betroffenen Tagesinfos neu (nach jeder Mutation, damit
  /// z.B. eine Info mit Zukunftsdatum korrekt *nicht* heute erscheint).
  Future<void> _reloadTodayInfos() async {
    final infos = await _repo.dailyInfosForDay(DateTime.now());
    if (!mounted) return;
    setState(() {
      _todayInfos
        ..clear()
        ..addAll(infos);
    });
    await _reloadPastAgenda();
  }

  /// Lädt die Aufgaben neu (nach jeder Mutation): die heute sichtbaren *und*
  /// alle (für Zähler/Register). Baut anschließend das Tag-Register neu auf,
  /// damit ein neuer, nur in einer Aufgabe verwendeter Tag sofort im
  /// Autocomplete und in der Tag-Verwaltung auftaucht.
  Future<void> _reloadTasks() async {
    final surfaced = await _repo.surfacedTasksForDay(DateTime.now());
    final allTasks = await _repo.loadAllTasks();
    if (!mounted) return;
    setState(() {
      _todayTasks
        ..clear()
        ..addAll(surfaced);
      _allTasks
        ..clear()
        ..addAll(allTasks);
    });
    _rebuildTagRegistry();
    await _reloadPastAgenda();
  }

  /// Lädt die Kalender-Quellen neu (nach Rückkehr aus den Kalender-
  /// Einstellungen) und baut das Tag-Register neu auf — so landen frisch
  /// zugeordnete Kalender-Tags im Autocomplete.
  Future<void> _reloadCalendarSources() async {
    final sources = await _repo.loadCalendarSources();
    // Auch die Termine neu holen: In den Kalender-Einstellungen kann eben
    // synchronisiert oder ein Kalender ab-/zugeschaltet worden sein.
    final events = await _repo.calendarEventsForDay(_dayKey(DateTime.now()));
    if (!mounted) return;
    setState(() {
      _calendarSources
        ..clear()
        ..addAll(sources);
      _todayEvents
        ..clear()
        ..addAll(events);
    });
    _rebuildTagRegistry();
    await _reloadPastAgenda();
  }

  /// Laedt die **Heute-Daten** (Tagesinfo, Aufgaben, Termine) neu und zieht den
  /// [_shownDay] nach. Aufgerufen bei App-Resume und beim Mitternachtswechsel.
  /// Bewusst ohne `_entries`/Register-Neuaufbau: der Schreibstrom aendert sich
  /// durch einen Datumssprung nicht, nur die heute auftauchenden Elemente.
  Future<void> _refreshToday() async {
    final now = DateTime.now();
    final infos = await _repo.dailyInfosForDay(now);
    final surfaced = await _repo.surfacedTasksForDay(now);
    final events = await _repo.calendarEventsForDay(_dayKey(now));
    if (!mounted) return;
    setState(() {
      _shownDay = _dayKey(now);
      _todayInfos
        ..clear()
        ..addAll(infos);
      _todayTasks
        ..clear()
        ..addAll(surfaced);
      _todayEvents
        ..clear()
        ..addAll(events);
    });
    await _reloadPastAgenda();
  }

  /// Kalendertag als `yyyy-MM-dd` — dasselbe Format, in dem `calendar_events`
  /// die Tage ablegt.
  static String _dayKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$m-$d';
  }

  /// Öffnet das Text-Eingabe-Sheet.
  /// [existing] == null -> Neuer (Text-)Eintrag.
  /// [existing] != null -> Bestehenden Text-Eintrag bearbeiten.
  /// [initialContent] befuellt bei einem **neuen** Eintrag das Textfeld vor —
  /// so dient dasselbe Sheet als Landeblatt fuer geteilte Inhalte (Feature 2).
  /// Bei [existing] != null bleibt es wirkungslos (der Bestand gewinnt).
  void _openEntrySheet({JournalEntry? existing, String? initialContent}) {
    final isEditing = existing != null;
    final contentController =
        TextEditingController(text: existing?.content ?? initialContent ?? '');
    final tagController = TextEditingController(
        text: existing != null ? formatTags(existing.tags) : '');

    // Bild-Zustand des Sheets (Session A). Außerhalb des Builders, damit er
    // über StatefulBuilder-Neuaufbauten hinweg bestehen bleibt.
    //  - [pickedImage]    ein frisch gewähltes, noch **nicht** importiertes Bild
    //                     (Import erst beim Speichern — bricht der Nutzer ab,
    //                     entsteht keine verwaiste Datei).
    //  - [removeExisting] der Nutzer hat das bestehende Bild entfernt.
    XFile? pickedImage;
    bool removeExisting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final showPicked = pickedImage != null;
            final showExisting = !showPicked &&
                existing != null &&
                existing.hasImage &&
                !removeExisting;
            final hasPreview = showPicked || showExisting;
            final previewPath = showPicked
                ? pickedImage!.path
                : (showExisting ? existing!.attachments.first.filePath : null);

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Eintrag bearbeiten' : 'Neuer Eintrag',
                    style: const TextStyle(
                      color: AppColors.iconInactive,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: contentController,
                          autofocus: true,
                          maxLines: 4,
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Was ist gerade wichtig?',
                            hintStyle:
                                const TextStyle(color: AppColors.placeholder),
                            filled: true,
                            fillColor: AppColors.fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      // Stift-Eingabe nur beim Neuanlegen: das native Feld kann
                      // (noch) nicht vorbefuellt werden -> Bearbeiten via Tastatur.
                      if (!isEditing) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.accent),
                          tooltip: 'Mit Stift schreiben (Text)',
                          onPressed: () async {
                            Navigator.pop(context);
                            final result =
                                await Navigator.push<NativeTextResult>(
                              this.context,
                              MaterialPageRoute(
                                builder: (_) => NativeTextEntryScreen(
                                    knownTags: _tagRegistry.allTags),
                              ),
                            );
                            if (result != null && result.text.isNotEmpty) {
                              _addEntry(result.text, result.tags);
                            }
                          },
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.brush, color: AppColors.accent),
                          tooltip: 'Mit Stift zeichnen (Tinte)',
                          onPressed: () {
                            Navigator.pop(context);
                            _openInkEditorNew();
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bild-Anhang (Session A): Vorschau mit Entfernen-Knopf oder,
                  // wenn kein Bild dranhängt, ein Knopf zum Hinzufügen.
                  if (hasPreview && previewPath != null)
                    Stack(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 160),
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Image.file(
                            File(previewPath),
                            fit: BoxFit.cover,
                            cacheWidth: 1080,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 100,
                              alignment: Alignment.center,
                              color: AppColors.fieldFill,
                              child: const Text(
                                'Bild nicht gefunden',
                                style: TextStyle(color: AppColors.placeholder),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setSheetState(() {
                                if (showPicked) {
                                  pickedImage = null;
                                } else {
                                  removeExisting = true;
                                }
                              }),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickImage(context);
                          if (picked != null) {
                            setSheetState(() {
                              pickedImage = picked;
                              removeExisting = false;
                            });
                          }
                        },
                        icon: const Icon(Icons.image_outlined,
                            color: AppColors.accent, size: 20),
                        label: const Text('Bild hinzufügen',
                            style: TextStyle(color: AppColors.accent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TagAutocompleteField(
                    controller: tagController,
                    knownTags: _tagRegistry.allTags,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Loeschen nur beim Bearbeiten. Ohne Rueckfrage — bewusst,
                      // damit sich Test-Eintraege zuegig von Hand wegraeumen
                      // lassen (gleicher Schnitt wie im Aufgaben-Sheet).
                      if (isEditing)
                        IconButton(
                          tooltip: 'Loeschen',
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteEntry(existing.id);
                          },
                        ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _saveEntryFromSheet(
                            context: context,
                            existing: existing,
                            content: contentController.text.trim(),
                            tagText: tagController.text,
                            pickedImage: pickedImage,
                            removeExisting: removeExisting,
                          ),
                          child: const Text(
                            'Speichern',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Öffnet einen kleinen Auswahldialog (Galerie / Kamera) und liefert das
  /// gewählte Bild als [XFile] — oder `null`, wenn abgebrochen wurde.
  ///
  /// `maxWidth` + `imageQuality` verkleinern/komprimieren schon beim Auswählen:
  /// ein Journal braucht keine 12-Megapixel-Originale, und kleinere Dateien
  /// halten den App-privaten Speicher schlank.
  Future<XFile?> _pickImage(BuildContext sheetContext) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: sheetContext,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.photo_library_outlined, color: AppColors.accent),
                title: const Text('Galerie',
                    style: TextStyle(color: AppColors.text)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.accent),
                title: const Text('Kamera',
                    style: TextStyle(color: AppColors.text)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return null;
    try {
      return await _imagePicker.pickImage(
        source: source,
        maxWidth: 2560,
        imageQuality: 88,
      );
    } catch (_) {
      // z.B. verweigerte Kamera-Berechtigung: still abbrechen, kein Absturz.
      return null;
    }
  }

  /// Wertet den Speichern-Knopf des Eintrags-Sheets aus: löst den Bild-Anhang
  /// auf (neu importieren / behalten / entfernen), schreibt den Eintrag und
  /// räumt verdrängte Bilddateien weg. Async, weil der Import Bytes kopiert.
  Future<void> _saveEntryFromSheet({
    required BuildContext context,
    required JournalEntry? existing,
    required String content,
    required String tagText,
    required XFile? pickedImage,
    required bool removeExisting,
  }) async {
    final keepingExisting = existing != null &&
        existing.hasImage &&
        !removeExisting &&
        pickedImage == null;
    final willHaveImage = pickedImage != null || keepingExisting;

    // Nichts zu speichern: weder Text noch Bild.
    if (content.isEmpty && !willHaveImage) return;

    final navigator = Navigator.of(context);
    final entryId =
        existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final tags = parseTags(tagText);

    final orphaned = <String>[];
    List<Attachment> attachments;

    if (pickedImage != null) {
      // Neues Bild importieren; ein vorhandenes wird dadurch verdrängt.
      final imported = await _attachmentStore.importImage(
        entryId: entryId,
        sourcePath: pickedImage.path,
        mimeType: pickedImage.mimeType,
      );
      attachments = [imported];
      if (existing != null) {
        for (final a in existing.attachments) {
          orphaned.add(a.filePath);
          if (a.thumbPath != null) orphaned.add(a.thumbPath!);
        }
      }
    } else if (keepingExisting) {
      attachments = existing!.attachments;
    } else {
      attachments = const [];
      if (existing != null && removeExisting) {
        for (final a in existing.attachments) {
          orphaned.add(a.filePath);
          if (a.thumbPath != null) orphaned.add(a.thumbPath!);
        }
      }
    }

    if (existing != null) {
      _updateEntry(entryId, content, tags, attachments: attachments);
    } else {
      _addEntry(content, tags, id: entryId, attachments: attachments);
    }

    if (orphaned.isNotEmpty) {
      await _attachmentStore.deleteFiles(orphaned);
    }
    navigator.pop();
  }

  /// Tinten-Editor für einen neuen Tinten-Eintrag.
  ///
  /// **Ohne** Auswertungs-Callback: Ein Eintrag, den es noch nicht gibt, hat
  /// keine id, an der ein erkannter Text hängen könnte. Erst übernehmen, dann
  /// auswerten.
  Future<void> _openInkEditorNew() async {
    final result = await Navigator.push<InkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingScreen(knownTags: _tagRegistry.allTags),
      ),
    );
    if (result != null && result.ink.isNotEmpty) {
      _addInkEntry(result.ink, result.tags);
    }
  }

  /// Tinten-Editor für einen bestehenden Tinten-Eintrag (Striche zurückladen,
  /// weiterschreiben/korrigieren).
  ///
  /// Reicht einen bereits erkannten Text mit hinein und nimmt über
  /// [_saveInkText] einen neuen entgegen. Die Persistenz bleibt hier beim
  /// Aufrufer — derselbe Schnitt wie beim Aufgaben-Sheet.
  Future<void> _openInkEditorEdit(JournalEntry entry) async {
    final result = await Navigator.push<InkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingScreen(
          initialInk: entry.ink,
          initialTags: entry.tags,
          knownTags: _tagRegistry.allTags,
          initialInkText: entry.inkText,
          initialInkTextAt: entry.inkTextAt,
          onInkTextAccepted: (text) => _saveInkText(entry.id, text),
        ),
      ),
    );
    if (result != null && result.ink.isNotEmpty) {
      _updateInkEntry(entry.id, result.ink, result.tags);
    }
  }

  /// Übernimmt den von Claude erkannten Text zu einem Tinten-Eintrag.
  ///
  /// Schreibt gezielt die beiden Spalten (Schema v6) und zieht den Eintrag in
  /// der Liste nach, damit ein anschließendes Speichern aus dem Editor die
  /// frische Auswertung nicht mit einem veralteten Objekt überschreibt.
  Future<DateTime> _saveInkText(String id, String text) async {
    final at = await _repo.setInkText(id, text);
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1 && mounted) {
      setState(() {
        _entries[index] =
            _entries[index].copyWith(inkText: text, inkTextAt: at);
      });
    }
    return at;
  }

  void _addEntry(
    String content,
    List<String> tags, {
    String? id,
    List<Attachment> attachments = const [],
  }) {
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final entry = JournalEntry(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: content,
      tags: canonicalTags,
      attachments: attachments,
    );
    setState(() {
      _entries.insert(0, entry);
    });
    _repo.upsert(entry);
  }

  void _addInkEntry(InkData ink, List<String> tags) {
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: '',
      tags: canonicalTags,
      ink: ink,
    );
    setState(() {
      _entries.insert(0, entry);
    });
    _repo.upsert(entry);
  }

  void _updateEntry(
    String id,
    String content,
    List<String> tags, {
    List<Attachment>? attachments,
  }) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    // attachments == null lässt die bestehenden Anhänge unangetastet
    // (copyWith-Semantik); das Sheet übergibt stets eine konkrete Liste.
    final updated = _entries[index].copyWith(
      content: content,
      tags: canonicalTags,
      attachments: attachments,
    );
    setState(() {
      _entries[index] = updated;
    });
    _repo.upsert(updated);
  }

  /// Loescht einen Eintrag (getippt wie Tinte) aus Liste und Datenbank.
  /// entry_tags **und** attachments folgen per ON DELETE CASCADE; die
  /// Bild-Dateien der verwaisten Anhänge räumt der AttachmentStore weg
  /// (die Datenbank kennt das Dateisystem nicht).
  void _deleteEntry(String id) {
    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
    _repo.delete(id).then((orphaned) {
      if (orphaned.isNotEmpty) {
        _attachmentStore.deleteFiles(orphaned);
      }
    });
  }

  /// Langes Druecken auf einen Eintrag -> kurze Rueckfrage, dann loeschen.
  /// Der eine Weg fuer beide Arten: getippte Eintraege oeffnen zwar ein Sheet
  /// mit Loeschen-Knopf, Tinten-Eintraege dagegen den Zeichnen-Editor (noch
  /// ohne Loeschen). Das lange Druecken deckt daher beide ab.
  Future<void> _confirmDeleteEntry(JournalEntry entry) async {
    final preview = entry.isInk
        ? 'Tinten-Eintrag'
        : (entry.content.trim().split('\n').first);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eintrag loeschen?'),
        content: Text(
          preview.isEmpty ? 'Diesen Eintrag loeschen?' : '"$preview"',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );
    if (ok == true) _deleteEntry(entry.id);
  }

  /// Langes Druecken auf einen Eintrag oeffnet ein kleines Aktions-Blatt:
  /// Teilen oder Loeschen. Frueher fuehrte das lange Druecken direkt zur
  /// Lösch-Rueckfrage; mit Feature 3 teilen sich beide Aktionen eine Geste
  /// (eine Geste, ein Menue — kein zusaetzliches Icon auf der Karte). Der
  /// Lösch-Pfad dahinter (die Rueckfrage) ist unveraendert.
  void _showEntryActions(JournalEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.share_outlined, color: AppColors.accent),
                title: const Text('Teilen',
                    style: TextStyle(color: AppColors.text)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareEntry(entry);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Loeschen',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteEntry(entry);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Gibt den Eintrag ueber den nativen Teilen-Dialog nach aussen (Feature 3).
  /// Was hinausgeht, entscheidet [ShareService] nach Eintragsart. Erwartbare
  /// Fehler (nichts zu teilen, Tinte nicht renderbar) landen als kurzer
  /// Hinweis, nicht als Absturz.
  Future<void> _shareEntry(JournalEntry entry) async {
    try {
      await ShareService.shareEntry(entry);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _updateInkEntry(String id, InkData ink, List<String> tags) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final canonicalTags = _tagRegistry.canonicalizeAll(tags);
    final updated = _entries[index].copyWith(
      ink: ink,
      tags: canonicalTags,
    );
    setState(() {
      _entries[index] = updated;
    });
    _repo.upsert(updated);
  }

  // ---------------------------------------------------------------------------
  // Daily Info (Session 15)
  // ---------------------------------------------------------------------------

  /// Öffnet das Daily-Info-Sheet.
  /// [existing] == null -> Neue Tagesinfo (Start = heute).
  /// [existing] != null -> Bestehende Tagesinfo bearbeiten (mit Löschen).
  void _openDailyInfoSheet({DailyInfo? existing}) {
    final isEditing = existing != null;
    final textController = TextEditingController(text: existing?.text ?? '');
    DateTime startDate =
        DailyInfo.dayOnly(existing?.startDate ?? DateTime.now());
    DateTime? endDate = existing?.endDate != null
        ? DailyInfo.dayOnly(existing!.endDate!)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<DateTime?> pickDate(DateTime initial) {
              return showDatePicker(
                context: sheetContext,
                initialDate: initial,
                firstDate: DateTime(DateTime.now().year - 5),
                lastDate: DateTime(DateTime.now().year + 5),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.dailyInfoText, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Tagesinfo bearbeiten' : 'Neue Tagesinfo',
                        style: const TextStyle(
                          color: AppColors.iconInactive,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Was ist an diesem Tag bei Menschen im Umfeld?',
                      hintStyle: const TextStyle(color: AppColors.placeholder),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Startdatum
                  DateRow(
                    label: endDate == null ? 'Datum' : 'Von',
                    value: _formatDate(startDate),
                    onTap: () async {
                      final picked = await pickDate(startDate);
                      if (picked != null) {
                        setSheetState(() {
                          startDate = DailyInfo.dayOnly(picked);
                          if (endDate != null && endDate!.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Zeitspanne-Umschalter + optionales Enddatum
                  if (endDate == null)
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() => endDate = startDate);
                      },
                      icon: const Icon(Icons.date_range,
                          size: 18, color: AppColors.accent),
                      label: const Text(
                        'Zeitspanne (bis-Datum)',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DateRow(
                            label: 'Bis',
                            value: _formatDate(endDate!),
                            onTap: () async {
                              final picked = await pickDate(endDate!);
                              if (picked != null) {
                                final d = DailyInfo.dayOnly(picked);
                                setSheetState(() {
                                  endDate =
                                      d.isBefore(startDate) ? startDate : d;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Zeitspanne entfernen',
                          icon: const Icon(Icons.close,
                              color: AppColors.iconInactive),
                          onPressed: () {
                            setSheetState(() => endDate = null);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (existing != null)
                        IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _deleteDailyInfo(existing.id);
                          },
                        ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            if (existing != null) {
                              _updateDailyInfo(
                                  existing.id, text, startDate, endDate);
                            } else {
                              _addDailyInfo(text, startDate, endDate);
                            }
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'Speichern',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addDailyInfo(
      String text, DateTime startDate, DateTime? endDate) async {
    final info = DailyInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      startDate: startDate,
      endDate: endDate,
    );
    await _repo.upsertDailyInfo(info);
    await _reloadTodayInfos();
  }

  Future<void> _updateDailyInfo(
      String id, String text, DateTime startDate, DateTime? endDate) async {
    final info = DailyInfo(
      id: id,
      text: text,
      startDate: startDate,
      endDate: endDate,
    );
    await _repo.upsertDailyInfo(info);
    await _reloadTodayInfos();
  }

  Future<void> _deleteDailyInfo(String id) async {
    await _repo.deleteDailyInfo(id);
    await _reloadTodayInfos();
  }

  // ---------------------------------------------------------------------------
  // Aufgaben (Session 16)
  // ---------------------------------------------------------------------------

  /// Öffnet das Aufgaben-Sheet.
  /// [existing] == null → Neue Aufgabe (ohne Day/Uhrzeit).
  /// [existing] != null → Bestehende Aufgabe bearbeiten (mit Löschen).
  /// Öffnet das wiederverwendbare Aufgaben-Sheet (Journal-Variante).
  /// Persistenz und Neuladen liegen hier: nach Speichern/Löschen wird die
  /// heutige Liste (und alle Aufgaben fürs Register) neu geladen.
  void _openTaskSheet({Task? existing}) {
    showTaskSheet(
      context: context,
      tagRegistry: _tagRegistry,
      existing: existing,
      onSave: (task) async {
        await _repo.upsertTask(task);
        await _reloadTasks();
      },
      onDelete: _deleteTask,
    );
  }

  /// Öffnet die Aufgaben-Übersicht (alle Aufgaben, sortierbar, erledigte
  /// eingeklappt). Beim Zurückkehren wird neu geladen, da dort abgehakt,
  /// bearbeitet oder gelöscht worden sein kann.
  Future<void> _openTaskOverview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskOverviewScreen(
          repo: _repo,
          tagRegistry: _tagRegistry,
        ),
      ),
    );
    await _reloadTasks();
  }

  /// Hakt eine Aufgabe **im Heute-Panel** ab bzw. wieder auf. Anders als ein
  /// Neuladen aus dem Repository (das nur offene Aufgaben liefert) wird der
  /// Eintrag hier an Ort und Stelle aktualisiert — so bleibt die eben erledigte
  /// Aufgabe im offenen Panel durchgestrichen sichtbar, statt sofort zu
  /// verschwinden. Beim naechsten frischen Aufbau (Panel erneut oeffnen,
  /// Resume, Tageswechsel) faellt eine erledigte Aufgabe dann heraus. Das
  /// Register/die Zaehler (`_allTasks`) werden im Hintergrund nachgezogen.
  Future<void> _togglePanelTask(Task task) async {
    final updated = task.copyWith(done: !task.done);
    await _repo.upsertTask(updated);
    if (!mounted) return;
    setState(() {
      final i = _todayTasks.indexWhere((t) => t.id == updated.id);
      if (i != -1) _todayTasks[i] = updated;
    });
    final allTasks = await _repo.loadAllTasks();
    if (!mounted) return;
    setState(() {
      _allTasks
        ..clear()
        ..addAll(allTasks);
    });
    _rebuildTagRegistry();
    await _reloadPastAgenda();
  }

  Future<void> _deleteTask(String id) async {
    await _repo.deleteTask(id);
    await _reloadTasks();
  }

  /// Nutzungszähler je Tag (Schlüssel = kleingeschrieben). Pro Eintrag zählt
  /// ein Tag höchstens einmal.
  Map<String, int> _tagUsage() {
    final usage = <String, int>{};
    for (final e in _entries) {
      final seen = <String>{};
      for (final t in e.tags) {
        final k = t.toLowerCase();
        if (seen.add(k)) {
          usage[k] = (usage[k] ?? 0) + 1;
        }
      }
    }
    return usage;
  }

  /// Nutzungszähler je Tag über **Aufgaben** (analog [_tagUsage]). Getrennt
  /// gehalten, damit die Tag-Verwaltung Einträge und Aufgaben ausweisen kann.
  Map<String, int> _taskUsage() {
    final usage = <String, int>{};
    for (final task in _allTasks) {
      final seen = <String>{};
      for (final t in task.tags) {
        final k = t.toLowerCase();
        if (seen.add(k)) {
          usage[k] = (usage[k] ?? 0) + 1;
        }
      }
    }
    return usage;
  }

  void _openTagManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagManagementScreen(
          tags: _tagRegistry.allTags,
          usage: _tagUsage(),
          taskUsage: _taskUsage(),
          onRename: _renameTag,
        ),
      ),
    );
  }

  /// Benennt einen Tag in allen Einträgen **und Aufgaben** um (case-insensitiv
  /// erkannt). Trifft die Zielschreibweise einen bestehenden Tag, werden beide
  /// zusammengeführt. Nach dem Umschreiben wird das Register neu aufgebaut und
  /// nur die tatsächlich geänderten Einträge/Aufgaben werden persistiert.
  void _renameTag(String from, String to) {
    final fromKey = from.toLowerCase();
    final cleanTo = to.trim();
    if (cleanTo.isEmpty || cleanTo == from) return;
    final toKey = cleanTo.toLowerCase();

    // Bildet eine Tag-Liste auf die neue Schreibweise ab (Merge-Duplikate
    // fallen weg). Gibt null zurück, wenn sich nichts geändert hat.
    List<String>? remap(List<String> tags) {
      final newTags = <String>[];
      final seen = <String>{};
      var changed = false;
      for (final t in tags) {
        final k = t.toLowerCase();
        final mapped = (k == fromKey || k == toKey) ? cleanTo : t;
        if (mapped != t) changed = true;
        if (seen.add(mapped.toLowerCase())) {
          newTags.add(mapped);
        } else {
          changed = true; // Duplikat (Merge) entfernt
        }
      }
      return changed ? newTags : null;
    }

    final changedEntries = <JournalEntry>[];
    final changedTasks = <Task>[];
    setState(() {
      for (int i = 0; i < _entries.length; i++) {
        final newTags = remap(_entries[i].tags);
        if (newTags != null) {
          final updated = _entries[i].copyWith(tags: newTags);
          _entries[i] = updated;
          changedEntries.add(updated);
        }
      }
      for (int i = 0; i < _allTasks.length; i++) {
        final newTags = remap(_allTasks[i].tags);
        if (newTags != null) {
          final updated = _allTasks[i].copyWith(tags: newTags);
          _allTasks[i] = updated;
          changedTasks.add(updated);
          // Heute sichtbare Kopie derselben Aufgabe mitziehen.
          final si = _todayTasks.indexWhere((x) => x.id == updated.id);
          if (si != -1) _todayTasks[si] = updated;
        }
      }
    });
    // Register neu aufbauen (Einträge + Aufgaben; nach dem Umschreiben ist die
    // neue Schreibweise überall identisch).
    _rebuildTagRegistry();
    if (changedEntries.isNotEmpty) {
      _repo.upsertAll(changedEntries);
    }
    for (final t in changedTasks) {
      _repo.upsertTask(t);
    }
  }

  /// Öffnet die Kalender-Einstellungen und zieht danach Quellen **und**
  /// Termine nach — dort kann synchronisiert oder umgeschaltet worden sein.
  Future<void> _openCalendarSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarSettingsScreen(tagRegistry: _tagRegistry),
      ),
    );
    await _reloadCalendarSources();
  }

  /// Öffnet die Suche und öffnet anschließend den angetippten Eintrag.
  ///
  /// Der Such-Screen liefert nur die Id zurück; geöffnet wird hier — mit
  /// genau den Wegen, die auch das Antippen einer Karte im Journal nimmt.
  /// Damit bleibt die Persistenz an einer Stelle und die Suche ein reiner
  /// Lese-Screen.
  ///
  /// **Bewusst kein Scrollen zur Karte:** Das Journal ist ein
  /// `ListView.builder` mit unterschiedlich hohen Einträgen — eine Position
  /// außerhalb des Sichtbereichs lässt sich darin nicht verlässlich
  /// ansteuern, ohne ein zusätzliches Paket einzuführen. Den Eintrag zu
  /// öffnen ist ohnehin das, was nach einem Treffer gewollt ist: lesen,
  /// gegebenenfalls ergänzen.
  Future<void> _openSearch() async {
    final entryId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (entryId == null || !mounted) return;

    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    final entry = _entries[index];
    if (entry.isInk) {
      await _openInkEditorEdit(entry);
    } else {
      _openEntrySheet(existing: entry);
    }
  }

  /// Öffnet die Claude-Einstellungen (API-Schlüssel). Kein Nachladen nötig —
  /// dort wird nichts verändert, was das Journal anzeigt.
  Future<void> _openClaudeSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClaudeSettingsScreen()),
    );
  }

  /// Öffnet die Wochenauswertung und legt bei „Übernehmen" den Eintrag an.
  ///
  /// Der Screen gibt nur den Text zurück; geschrieben wird hier — über
  /// denselben [_addEntry], den auch das Eintrags-Sheet nimmt. Damit bleibt
  /// die Persistenz an einer Stelle (wie beim Such-Screen), und die
  /// Auswertung landet als ganz gewöhnlicher Eintrag von heute im Journal.
  Future<void> _openWeekReview() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const WeekReviewScreen()),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    _addEntry(text, const ['Wochenauswertung']);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Datumswaechter: Bleibt die App ueber Mitternacht im Vordergrund offen,
    // springt der Datumskopf (frisches now() je build), die Heute-Listen aber
    // nicht. Faellt der Tag ab, nach dem aktuellen Frame die Heute-Daten neu
    // laden. Idempotent: _refreshToday zieht _shownDay nach, danach greift der
    // Waechter nicht mehr.
    if (_dayKey(today) != _shownDay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshToday();
      });
    }
    // Badge am Panel-Umschalter: heutige Termine + offene Aufgaben. Erledigte
    // (im offenen Panel durchgestrichen liegengebliebene) zaehlen nicht mit.
    final openTaskCount = _todayTasks.where((t) => !t.done).length;
    final agendaCount = _todayEvents.length + openTaskCount;

    // Heute vs. Vergangenheit trennen. Heute (Design 4a) bleibt freie
    // Schreibflaeche: Datumskopf, Tagesinfo, eigene Eintraege (Termine und
    // Aufgaben liegen im Heute-Panel). Vergangene Tage (Design 4b) werden je
    // Tag nach `#Tag` gruppiert und stehen darunter, neu nach alt.
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final todayEntries =
        _entries.where((e) => !e.timestamp.isBefore(todayMidnight)).toList();
    final pastEntries =
        _entries.where((e) => e.timestamp.isBefore(todayMidnight)).toList();
    final pastDays = PastDay.buildTimeline(
      pastEntries: pastEntries,
      pastTasks: _pastTasks,
      pastEvents: _pastEvents,
      pastInfos: _pastInfos,
      today: todayMidnight,
    );

    // Heute faellige, offene Aufgaben fuer den Heute-Block (v6.1, §2): die
    // EINZIGE zugelassene Ergaenzung der freien Schreibflaeche. Streng
    // gefiltert auf Faelligkeitstag == heute; ueberfaellige und Aufgaben ohne
    // Datum bleiben draussen (nur im Heute-Panel). `!done` sorgt dafuer, dass
    // eine eben abgehakte Aufgabe durch `_togglePanelTask` SOFORT aus dem Block
    // faellt (die Karte bleibt derweil im Panel durchgestrichen sichtbar).
    final todayDueTasks = _todayTasks.where((t) {
      final due = t.dueDay;
      if (due == null || t.done) return false;
      return Task.dayOnly(due) == todayMidnight;
    }).toList();

    // Eine flache Widget-Liste fuer die ListView. Die Widget-Objekte sind
    // billige Konfiguration; die teuren Element-/Render-Baeume baut der
    // ListView.builder weiterhin traege beim Scrollen (kein eager Aufbau).
    final rows = <Widget>[
      DateHeader(weekday: _weekdayName(today), date: _formatDate(today)),
      DailyInfoSection(
        infos: _todayInfos,
        onAdd: () => _openDailyInfoSheet(),
        onTapInfo: (info) => _openDailyInfoSheet(existing: info),
      ),
      // Direkt unter dem Tagesinfo-Band, ueber den eigenen Eintraegen: was
      // heute zaehlt, steht zusammen oben; die Schreibflaeche flieszt darunter.
      // Rendert sich selbst nur, wenn etwas offen und heute faellig ist.
      TodayDueTasks(
        tasks: todayDueTasks,
        onToggleTask: _togglePanelTask,
        onOpenTask: (task) => _openTaskSheet(existing: task),
      ),
      if (todayEntries.isEmpty)
        // Eindeutige Keys, damit Flutter beim Wechsel von der Einladung zur
        // ersten EntryCard (gleiche Listenposition) das Element NICHT recycelt
        // und keinen InkWell-Highlight uebertraegt (Bug 4: grauer Hintergrund
        // beim allerersten Eintrag).
        EmptyEntryInvitation(
            key: const ValueKey('today-empty-invitation'),
            onTap: () => _openEntrySheet())
      else
        for (final entry in todayEntries)
          EntryCard(
            key: ValueKey(entry.id),
            entry: entry,
            onTap: () {
              if (entry.isInk) {
                _openInkEditorEdit(entry);
              } else {
                _openEntrySheet(existing: entry);
              }
            },
            onLongPress: () => _showEntryActions(entry),
          ),
      for (final pd in pastDays)
        PastDayView(
          pastDay: pd,
          onTapEntry: (entry) {
            if (entry.isInk) {
              _openInkEditorEdit(entry);
            } else {
              _openEntrySheet(existing: entry);
            }
          },
          onLongPressEntry: (entry) => _showEntryActions(entry),
          onToggleTask: _togglePanelTask,
          onTapInfo: (info) => _openDailyInfoSheet(existing: info),
        ),
    ];
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Oben links: Menue mit den selteneren Aktionen (Tags, Kalender,
        // Wochenauswertung). Design 8.
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: AppColors.iconInactive),
          tooltip: 'Menue',
          color: AppColors.paper,
          onSelected: (value) {
            switch (value) {
              case 'tags':
                _openTagManagement();
                break;
              case 'calendar':
                _openCalendarSettings();
                break;
              case 'week':
                _openWeekReview();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'tags',
              child: Row(children: [
                Icon(Icons.sell_outlined,
                    size: 18, color: AppColors.iconActive),
                SizedBox(width: 12),
                Text('Tags verwalten',
                    style: TextStyle(color: AppColors.iconActive)),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'calendar',
              child: Row(children: [
                Icon(Icons.event_outlined,
                    size: 18, color: AppColors.iconActive),
                SizedBox(width: 12),
                Text('Google Calendar',
                    style: TextStyle(color: AppColors.iconActive)),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'week',
              child: Row(children: [
                Icon(Icons.date_range,
                    size: 18, color: AppColors.iconActive),
                SizedBox(width: 12),
                Text('Wochenauswertung',
                    style: TextStyle(color: AppColors.iconActive)),
              ]),
            ),
          ],
        ),
        // Oben rechts: Funkel-Symbol (Claude) und der Sidebar-Umschalter, der
        // das Heute-Panel oeffnet und das Agenda-Badge traegt (Design 5/9).
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined,
                color: AppColors.accent),
            tooltip: 'Claude',
            onPressed: _openClaudeSettings,
          ),
          PanelToggleButton(
            count: agendaCount,
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Heute oben (Design 4a), darunter die vergangenen Tage nach `#Tag`
      // gruppiert (Design 4b). Termine und Aufgaben von heute stehen bewusst
      // NICHT in der Spalte, sondern im Heute-Panel (endDrawer, Design 4a/5) —
      // der Schreibraum bleibt frei.
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: rows.length,
        itemBuilder: (context, index) => rows[index],
      ),
      // Heute-Panel: Overlay von rechts (beide Lagen, ein Layout-Pfad), haelt
      // die Journalspalte frei und zeigt Termine + Aufgaben von heute. Standard
      // geschlossen; Rechtswisch oder der Umschalter oben rechts oeffnet es.
      endDrawer: TodayPanel(
        events: _todayEvents,
        tasks: _todayTasks,
        today: today,
        day: _dayKey(today),
        calendarEnabled: _calendarSources.any((c) => c.enabled),
        onToggleTask: _togglePanelTask,
        onAddTask: () => _openTaskSheet(),
      ),
      bottomNavigationBar: BottomBar(
        onJournal: () {},
        onSearch: _openSearch,
        onTasks: _openTaskOverview,
        onNewEntry: () => _openEntrySheet(),
      ),
    );
  }

  String _weekdayName(DateTime date) {
    const names = [
      'MONTAG',
      'DIENSTAG',
      'MITTWOCH',
      'DONNERSTAG',
      'FREITAG',
      'SAMSTAG',
      'SONNTAG',
    ];
    return names[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}
