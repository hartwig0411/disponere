# Disponere – Fortschritt

---

## Session 1 — 01. Juni 2026

### Erledigt
- Flutter-Projekt `disponere` angelegt (`E:\disponere`, Plattform: Android)
- Ordnerstruktur: `lib/models`, `lib/screens/journal`, `lib/widgets`
- `JournalEntry` Datenmodell (`lib/models/journal_entry.dart`)
- `JournalScreen` mit Eintrags-Karten und Tag-Chips (`lib/screens/journal/journal_screen.dart`)
- `main.dart` angepasst — App startet direkt mit JournalScreen
- App erfolgreich auf dem MatePad (MRDI-W09) deployt und getestet
- GitHub-Repository: vorhanden, noch nicht verbunden

### Offene Punkte
- Handschrifterkennung: Huawei ML Kit vs. Tesseract — noch nicht getestet
- Claude-Integration: Umfang für v1.0 noch offen
- Google Calendar API: Zugänge noch nicht eingerichtet

---

## Session 2 — 03. Juni 2026

### Erledigt
- Git global konfiguriert (user.name, user.email)
- GitHub-Repository `disponere` angelegt (Public): https://github.com/hartwig0411/disponere
- Flutter `.gitignore` eingerichtet
- Branch auf `main` umbenannt
- Ersten Commit gepusht — 65 Objekte, Projekt vollständig auf GitHub

### Offene Punkte
- Handschrifterkennung: Huawei ML Kit vs. Tesseract — noch nicht getestet
- Claude-Integration: Umfang für v1.0 noch offen
- Google Calendar API: Zugänge noch nicht eingerichtet

---

## Session 3 — 05. Juni 2026

### Erledigt
- Eingabe-Funktion gebaut: neuen Eintrag per Tastatur erstellen
- FloatingActionButton öffnet Bottom Sheet mit Textfeld, Tag-Feld und Speichern-Button
- Neuer Eintrag erscheint oben in der Liste mit aktuellem Zeitstempel
- Persistenz eingebaut: Einträge überleben App-Neustart (`shared_preferences`)
- Zwei-Laufwerke-Problem (E:\Projekt vs. C:\Pub-Cache) gelöst: `GRADLE_USER_HOME` und `PUB_CACHE` auf E:\ gesetzt
- Start-Script `run.ps1` angelegt — setzt Umgebungsvariablen und startet die App
- Auf MatePad getestet und bestätigt ✅
- Commits gepusht

### Lektion
- Projekt auf E:\, Pub-Cache standardmäßig auf C:\ → Kotlin-Daemon-Konflikt. Lösung: beide Umgebungsvariablen auf E:\ zeigen lassen, als `run.ps1` festgehalten.

---

## Session 4 — 06. Juni 2026

### Erledigt
- OCR-Engine entschieden: **Huawei ML Kit** (nativ auf HMS, beste Qualität für deutsche Handschrift)
- Huawei Developer Account angelegt (Individual, Steffen Harder) — Identitätsverifizierung läuft (1-2 Werktage)
- Canvas-Grundlage gebaut: `lib/screens/drawing/drawing_screen.dart`
  - Zeichenfläche mit CustomPainter
  - Stift-Eingabe mit GestureDetector (Striche werden aufgezeichnet)
  - Löschen-Button (X oben rechts)
  - Dunkles Farbschema passend zum Journal
- Auf MatePad getestet und bestätigt ✅ — M-Pencil funktioniert, Striche flüssig
- Commit gepusht: `bcc3234`

### Lektion
- **Palm Rejection fehlt noch** — Flutter's GestureDetector unterscheidet nicht zwischen Finger und Stift. Jede Berührung erzeugt einen Strich. Fix: Umstellen auf `Listener` mit `PointerEvent`, nur `stylus`-Events durchlassen.

---

## Session 5 — 10. Juni 2026

### Erledigt
- **Palm Rejection implementiert** — `GestureDetector` durch `Listener` + `PointerDeviceKind.stylus` ersetzt. Finger und Handballen erzeugen keine Striche mehr. Auf MatePad getestet und bestätigt ✅
- **DrawingScreen in Journal-Flow integriert** — Stift-Icon im "Neuer Eintrag"-Sheet öffnet DrawingScreen. Nach Bestätigung (Häkchen) landet der Eintrag im Journal. Platzhalter `[Handschrift-Eintrag]` bis OCR fertig ist.
- **DrawingScreen gibt Ergebnis zurück** — `Navigator.pop(context, result)` übergibt Text an JournalScreen, `_addEntry()` als eigene Methode ausgelagert.
- **Huawei Developer Account verifiziert** ✅
- **AppGallery Connect Projekt `disponere` angelegt** — Project ID: 101653523864310053
- **App registriert** — Package: `com.steffen.disponere`, Platform: Android, Sprache: Deutsch
- **`agconnect-services.json` heruntergeladen** und nach `android/app/` kopiert
- **HMS AGConnect SDK eingebunden** — `android/build.gradle.kts` und `android/app/build.gradle.kts` angepasst, Maven-Repository und AGConnect-Plugin ergänzt
- **`huawei_ml_text: ^3.4.0+300`** in `pubspec.yaml` eingetragen, `flutter pub get` erfolgreich
- Alle Änderungen committed und gepusht

### Lektion
- Flutter-Projekt verwendet `.kts`-Gradle-Dateien (Kotlin DSL) — Huawei-Dokumentation zeigt Groovy-Syntax. Übersetzung notwendig: `maven { url '...' }` → `maven { url = uri("...") }`, `classpath '...'` → `classpath("...")`
- AGConnect-Plugin benötigt `com.android.tools.build:gradle` explizit im `buildscript` — fehlt dieser Eintrag, schlägt der Build mit `is no set in the build.gradle file` fehl.

---

## Session 6 — 13. Juni 2026

### Erledigt
- **OCR vollständig in `drawing_screen.dart` integriert** — Platzhalter `[Handschrift-Eintrag]` durch echten ML Kit Aufruf ersetzt
  - Canvas wird via `RepaintBoundary` + `GlobalKey` als PNG gerendert
  - PNG wird in temporäre Datei geschrieben (`path_provider`)
  - `MLTextAnalyzer.asyncAnalyseFrame()` mit `MLTextAnalyzerSetting.local(language: 'de')` aufgerufen
  - Ergebnis wird via `Navigator.pop` an JournalScreen übergeben
  - Ladeindikator (CircularProgressIndicator) während OCR läuft
  - Fallback: `[Handschrift nicht erkannt]` wenn `stringValue` leer
- **`path_provider: ^2.1.4`** zu `pubspec.yaml` hinzugefügt
- **`android.uniquePackageNames=false`** in `android/gradle.properties` gesetzt (Namespace-Konflikt der Huawei OCR-Modelle)
- **`compileSdkVersion 34`** in pub-cache `huawei_ml_text` `build.gradle` gesetzt (war 31, zu alt für AndroidX-Abhängigkeiten)
- App baut erfolgreich und läuft auf MatePad ✅
- OCR-Aufruf funktioniert technisch — gibt aktuell `[Handschrift nicht erkannt]` zurück
- Commit gepusht: `63a7780`

### Lektion
- `huawei_ml_text` pub-cache Version ist `3.13.0+300` (nicht `3.4.0+300` wie in pubspec angegeben) — API hat sich geändert: `MLTextAnalyzerSetting.create()` → `MLTextAnalyzerSetting.local()`, `analyzeFrame()` → `asyncAnalyseFrame()`, `close()` → `destroy()`
- Huawei OCR-Modelle (`ocr-latin`, `ocr-jk`, `ocr-cn`, `ocr-base`) teilen intern denselben Namespace `com.huawei.hms.mlkit.ocr` — AGP 8.x schlägt fehl. Fix: `android.uniquePackageNames=false` in `gradle.properties`
- `huawei_ml_text` `build.gradle` im pub-cache hat `compileSdkVersion 31` — zu alt für moderne AndroidX-Abhängigkeiten. Manuell auf 34 erhöht. **Achtung: nach `flutter pub get` muss diese Änderung wiederholt werden.**
- Huawei ML Kit lädt OCR-Modelle beim ersten Start herunter — erste Erkennung schlägt daher fehl. Ab dem zweiten Start sollte OCR funktionieren.

---

## Session 7 — 15. Juni 2026

### Erledigt
- **OCR-Test mit Handschrift durchgeführt** — App neu gestartet (Modell-Download abgeschlossen), „Hallo" geschrieben, Haken getippt. Weiterhin `[Handschrift nicht erkannt]`.
- **Systematische Fehlereingrenzung** in drei Schritten:
  1. **Schwarz-auf-weiß-Render eingebaut** (`_renderForOcr()`) — eigenes OCR-Bild, schwarze Striche auf weißem Grund, unabhängig von der dunklen Anzeige.
  2. **`[OCR]`-Debug-Logging** — Canvas-Größe, Strichzahl, Punktzahl, PNG-Bytes, Dateipfad/-größe, roher `stringValue`.
  3. **Entscheidungs-Experiment** (`_testPrintedText()`, oranges T-Icon) — rendert **Maschinentext** („Hallo Welt") schwarz auf weiß und schickt ihn durch dieselbe OCR-Pipeline.
- **Befund:** Handschrift → leerer `stringValue`. Gedruckter Text → „Hallo Welt" sauber erkannt. → **Huawei ML Kit Text Recognition liest gedruckten Text, aber keine Handschrift.** Setup ist in Ordnung.
- **Debug-Werkzeug bewusst im Code behalten** — T-Icon + `_testPrintedText()` als dauerhaftes OCR-Testwerkzeug.
- **Durchbruch bei der Engine-Frage:** Steffen nutzt **Tintero** (Web/PWA) mit hervorragender Handschrift-zu-Text-Umwandlung. Da Tintero plattformübergreifend ist, stammt die Erkennung vom Betriebssystem → **Huaweis FreeScript**, die native System-Handschrifterkennung des MatePad.

### Strategische Erkenntnis
- **Die beste Handschrift-Engine sitzt bereits nativ auf dem Gerät: FreeScript.** On-Device, offline, Google-frei, kostenlos, systemweit.
- Mögliche Architektur-Vereinfachung: Für die normale Texteingabe braucht Disponere evtl. keine eigene OCR-Engine.

---

## Session 8 — 15. Juni 2026 (Teil II)

### Erledigt / Untersucht
- **FreeScript-Tests durchgeführt** (offene Punkte aus Session 7):
  - **Systemweit bestätigt:** Handschrift ins **Einstellungs-Suchfeld** geschrieben → FreeScript wandelt sauber in getippten Text um, inkl. Groß-/Kleinschreibung. Natives Feld, kein Browser. → On-Device, systemweit.
  - **Im Disponere-Textfeld funktioniert FreeScript NICHT** — der Stift schreibt dort nicht.
- **Ursache eingegrenzt:** Flutter zeichnet seine Textfelder selbst (aus Android-Sicht ein „custom text editor") und bekommt native Handschrift nicht automatisch. Flutters eigene Brücke ist `Scribe` / `stylusHandwritingEnabled`.
- **Geprüft:** `stylusHandwritingEnabled` ist bei `TextField` standardmäßig bereits `true` → das Flag explizit zu setzen wäre wirkungslos, war also nicht die Ursache. (Build-Runde gespart.)
- **Entscheidender Messwert** via `Scribe`-Diagnose: `isFeatureAvailable: false`, `isStylusHandwritingAvailable: false` → **Flutter sieht die Stift-Handschrift-Schnittstelle auf dem MatePad gar nicht.** FreeScript meldet sich nicht über die Standard-AOSP-Schnittstelle (`InputMethodManager`), sondern hängt direkt in native Felder (EditText/WebView) ein.
- **Nebenbefund:** ML-Kit-OCR erkannte handschriftliches „Hallo Welt" nur als „Hallo" — verschluckt Wörter. Bestätigt erneut: ML Kit nur für gedruckten Text brauchbar.
- Diagnose-Code wieder entfernt, alles committet und gepusht.

### Engine-Entscheidung (vorläufig final)
- **Handschrift-Eingabe = Huawei FreeScript**, eingebunden über ein **natives Android-`EditText`-Feld via PlatformView**.
- Flutters eingebauter Weg (`stylusHandwritingEnabled` / Scribe) ist auf diesem Gerät **nicht** nutzbar.
- ML Kit Text Recognition bleibt nur für **gedruckten** Text relevant (z.B. späterer Dokument-Import).

### Commit
- `5dc57d3` — "FreeScript-Schnittstelle getestet: Flutter-Weg ausgeschlossen (Scribe nicht verfuegbar), Plan B = natives EditText via PlatformView"

---

## Session 9 — 17. Juni 2026

### Erledigt
- **Plan B umgesetzt und bewiesen: FreeScript via natives `EditText` (PlatformView).**
  - Native Kotlin-`PlatformView` + `PlatformViewFactory` gebaut (`NativeTextView.kt`), liefert ein `EditText`
  - In `MainActivity.configureFlutterEngine` registriert (viewType `disponere/native-text`)
  - Dart-Seite über **Hybrid Composition** eingebunden (`PlatformViewLink` + `initExpensiveAndroidView`) — nötig, damit die native IME/FreeScript ins Feld schreiben kann
- **Proof-of-Concept bestätigt:** Mit M-Pencil ins native Feld geschrieben → FreeScript wandelt sauber in getippten Text um, inkl. Groß-/Kleinschreibung („Hallo Welt")
- **Offline-Test bestanden:** Im Flugmodus geschrieben → Umwandlung läuft weiter → **On-Device, offline, Google-frei bestätigt**
- **Commit (Proof):** `18d9b0e`
- **In den Journal-Flow integriert (End-to-End):**
  - `NativeTextView.kt` um `MethodChannel` (`disponere/native-text_$id`) erweitert → `getText` gibt den Feldinhalt an Dart zurück
  - `MainActivity` reicht den `BinaryMessenger` (`flutterEngine.dartExecutor.binaryMessenger`) an die Factory durch
  - Neuer Vollbild-Screen `lib/screens/text/native_text_entry_screen.dart` — natives Feld + Haken oben rechts, gibt den getippten Text via `Navigator.pop` zurück
  - Stift-Icon im „Neuer Eintrag"-Sheet öffnet jetzt diesen Screen statt des Canvas (`DrawingScreen`)
- **End-to-End auf MatePad getestet ✅** — Stift-Icon → handschriftlich „Haken landet oben" → Haken → Eintrag landet sauber im Journal
- **Commit (Integration):** `1ccaae9`

### Engine-Entscheidung (final)
- **Handschrift-Eingabe in Disponere = Huawei FreeScript**, eingebunden über ein natives `EditText` via PlatformView (Hybrid Composition).
- Der Canvas+OCR-Weg (`huawei_ml_text`) **entfällt für die normale Texteingabe.**
- `drawing_screen.dart` bleibt im Projekt — Canvas wird später noch für **Stempel-Tool** und **freies Zeichnen** gebraucht (Zugriff auf rohe Striche).

### Lektion
- Native Eingabe-Views (mit IME/Fokus) brauchen **Hybrid Composition** (`initExpensiveAndroidView`), nicht den Standard-`AndroidView` (Virtual Display) — sonst bekommt das Feld keinen Fokus/keine Eingabe.
- Text aus einer PlatformView holt man über einen **per-View-`MethodChannel`** (Name inkl. View-`id`), gespeist mit dem `BinaryMessenger` aus `flutterEngine.dartExecutor`.
- Ein natives `EditText` deckt **beide** Eingabearten ab: M-Pencil (FreeScript) **und** Tastatur — kein zweiter, getrennter Weg nötig.

### Commit
- Commit-Message (Integration): `FreeScript in Journal-Flow integriert: Stift-Eintrag via nativem EditText, Text landet im Journal`
- Commit (Integration) gepusht: `1ccaae9`

---

## Session 10 — 18. Juni 2026 (Brain-Session, kein Code)

### Charakter der Session
- **Reine Denk-/Brain-Session — kein Code, kein Commit.** Bewusste Entscheidung, dieses Format künftig regelmäßig einzuschieben, um den Kurs zu halten und Architektur-Fragen vor dem Coden zu klären.
- Ausgangspunkt war die geplante Tag-Vergabe beim Stift-Eintrag — daraus ist eine grundsätzliche Klärung des Eingabe- und Datenmodells geworden.

### Entscheidungen — Eingabe & Tags
1. **Stempel-Tool für v1.0 gestrichen.** Das Taggen läuft über ein dediziertes Tag-Feld; der Stempel (Tag aus handgeschriebenem Wort via OCR) wird damit überflüssig. Die räumliche Idee überlebt als v2-Feature (siehe unten).
2. **Zwei Eingabe-Modi pro Eintrag:**
   - **Text-Modus:** Stift via FreeScript **oder** Tastatur → gespeichert als **Text** → durchsuchbar, von Claude lesbar.
   - **Tinten-Modus:** Canvas → gespeichert als **Strichdaten** → **keine** Umwandlung, bleibt Handschrift.
   - FreeScript und Canvas bedienen je genau einen Modus. FreeScript *ist* Umwandlung-in-Text (die rohen Striche bleiben dabei nicht erhalten); der Canvas-Weg behält die Handschrift. Damit ist nichts aus Session 6–9 verloren — FreeScript wandert vom „einzigen Weg" zum „Text-Modus-Weg".
3. **Mehrfach-Tags im Tag-Feld**, getrennt per Pipe `|` (z.B. `MBS | ValSys | Vertrag`). Ein Tag = ein Wort. Leerzeichen werden getrimmt, leere Segmente ignoriert. Das Tag-Feld bleibt vorerst ein **normales Flutter-Textfeld (Tastatur)** — kein zweites natives FreeScript-Feld.

### Entscheidungen — Tinte & Claude
4. **Tinte wird als Strichdaten (Vektoren) gespeichert, nicht als plattes PNG.** Folge: Tinten-Einträge sind **editierbar und weiterschreibbar** (Striche zurück in die Canvas laden, korrigieren, radieren). Das PNG ist nur die Anzeige-/Render-Version bei Bedarf. Begründung: „Editierbarkeit" ist 🟡 Core im Anforderungsdokument; ein nicht weiterbearbeitbarer Tinten-Eintrag würde das brechen. Nebeneffekt: Strichdaten halten die Tür für bessere (strich-basierte) Erkennung offen.
5. **Claude kann Tinten-Einträge auswerten** — über die **multimodale Anthropic-Bild-API** (Handschrift-PNG als Bild mitschicken; Claude liest die Handschrift direkt). Einschränkungen ehrlich notiert: braucht Netz + API-Call (Tokens, nicht on-device), Erkennung schrift-abhängig (meist gut, nicht garantiert 100%).
6. **Lokale Volltextsuche von Tinte bleibt ungelöst.** Bräuchte eine On-Device-Handschrift-OCR, die wir nicht haben: ML Kit kann keine Handschrift, FreeScript ist reine Eingabe-Methode (nimmt kein gespeichertes Bild nachträglich). → Auswerten durch Claude: ja. Lokal durchsuchen: offen, **kein** garantiertes v2-Feature.

### Entscheidungen — Datenmodell
7. **Ein Journal, Tags als Sicht.** Es gibt nur **ein** durchgehendes Journal (Tageszeitachse). Projekte wie „Wasser"/„Wärme" sind **Tags**, keine eigenen Journale. Kein Leerstart pro Projekt, kein Neu-Verknüpfen. Die Tag-Seite ist eine **gefilterte Sicht** über das eine Journal.
8. **Ein „Tag" (Datum) ist eine Sicht/Abfrage, keine Datei.** Datei-pro-Tag (Logseq-Stil) bewusst verworfen — passt nicht zu Tinte/Strichen. Perspektivisch **lokale Datenbank** (SQLite o.ä.) statt `shared_preferences`, abfragbar nach Datum/Tag/Zeitraum (Grundlage u.a. für die Perlenkette).
9. **Platz unkritisch.** Text vernachlässigbar; Tinte als Striche ~ Größenordnung 50 KB/Seite → über zwei Jahre eher einige hundert MB im worst case, realistisch weniger. Für das MatePad trivial. Wichtig: Striche als Wahrheit speichern, PNGs nur bei Bedarf rendern (nicht dauerhaft mitschleppen).
10. **Kalender → Tag-Zuordnung, global.** Mehrere Google-Kalender (Privat, Familie, Wasser, Wärme) werden **einmal global** auf Tags abgebildet; Termine kommen **vor-getaggt** ins Journal. Kein Neu-Verknüpfen pro Projekt — neues Projekt = höchstens eine Zeile in der Zuordnung. (Noch nicht gebaut — Google-API-Zugänge stehen aus.)
11. **Backup per Export/Import.** Archiv (lokale DB + Tinten-Assets), das der Nutzer selbst ablegt (z.B. pCloud). Echtes Cloud-Sync bleibt für v1.0 bewusst draußen (laut Anforderungsdokument).

### v2-Notiz
- **Bereiche in der Handschrift markieren** und gezielt einen Zusatz-Tag nur diesem markierten Bereich zuordnen. Elegante Wiedergeburt der Stempel-Idee; passt zur ursprünglichen v1.0-Vision (Zeile/Satz/Absatz mehreren Tags zuordnen).

### Auswirkungen auf bestehende Planung
- Die für heute geplante Stift-Eintrag-Tag-Vergabe wird im Licht dieser Entscheidungen umgesetzt: Tag-Feld + Mehrfach-Tags per Pipe.
- `drawing_screen.dart` wird jetzt der **Tinten-Modus** (Striche speichern statt OCR) — nicht mehr Canvas+OCR.
- ML-Kit-Pfad (`huawei_ml_text`) nur noch für gedruckten Text (Dokument-Import) relevant.
- **Anforderungsdokument muss nachgezogen werden:** Engine „Huawei ML Kit" → „FreeScript via natives EditText/PlatformView", plus die hier getroffenen Entscheidungen (Stempel raus, zwei Modi, Mehrfach-Tags, ein-Journal-Tags-als-Sicht, Kalender→Tag, Backup).

### Nächste Session
1. **Tag-Feld + Mehrfach-Tags (Pipe `|`)** im Stift-/Text-Eintrag umsetzen — die ursprünglich für heute geplante Lücke. Stift-Screen gibt Text **+ Tags** zurück; `_addEntry()` übernimmt die Tags.
2. **Tinten-Modus konkretisieren:** Strichdaten serialisieren (JSON), `JournalEntry`-Modell um einen Tinten-Körper erweitern, Striche laden/weiterschreiben.
3. **Anforderungsdokument aktualisieren** (Engine-Entscheidung + Session-10-Festlegungen).
4. Perspektivisch: Migration `shared_preferences` → lokale DB einplanen (noch kein Blocker).
5. Weiter Richtung v1.0: Google Calendar (Kalender→Tag-Zuordnung), Claude-API.

### Offene Punkte
- `JournalEntry`-Modell muss einen **Tinten-Körper (Strichdaten)** unterstützen — Modelländerung steht aus.
- Lokale Handschrift-Volltextsuche ungelöst (keine On-Device-Engine).
- Migration auf lokale DB am Horizont (Skalierung Tinten-Einträge).
- Test-Screen `native_text_test_screen.dart` noch im Projekt (bewusst, als PoC-Referenz).
- ML Kit Text Recognition nur noch für **gedruckten** Text relevant (späterer Dokument-Import).
- Claude-Integration: Umfang für v1.0 noch offen.
- Google Calendar API: Zugänge noch nicht eingerichtet.

### Commit
- **Keine Code-Änderung diese Session (reine Brain-Session) → kein Commit.**

---

## Session 11 — 19. Juni 2026

### Erledigt
- **Mehrfach-Tags pro Eintrag umgesetzt** — die für Session 10 geplante Lücke (Nächste-Session-Punkt 1). Tastatur- und Stift-Pfad nutzen jetzt **denselben** Tag-Parser.
- **Neue Util `lib/utils/tag_parser.dart`** mit `parseTags(String)` — trennt Tags, trimmt, ignoriert leere Segmente; ein einzelner Tag ohne Trennzeichen wird ebenfalls akzeptiert.
- **Stift-Screen erweitert** (`lib/screens/text/native_text_entry_screen.dart`):
  - Eigenes **Tag-Feld (Tastatur)** unter dem nativen Feld ergänzt
  - Rückgabe geändert: statt `String` jetzt **`NativeTextResult` (Text + Tags)** via `Navigator.pop`
- **„Neuer Eintrag"-Sheet** (`lib/screens/journal/journal_screen.dart`):
  - Tastatur-Pfad: `_addEntry(content, parseTags(tagController.text))`
  - Stift-Pfad: `Navigator.push<NativeTextResult>` → `_addEntry(result.text, result.tags)`
  - `_addEntry(String, List<String>)` unverändert (nahm bereits eine Tag-Liste)
- **End-to-End auf MatePad getestet ✅** — sowohl Tastatur- als auch Stift-Eintrag erzeugen drei saubere Tag-Chips (`#MBS`, `#ValSys`, `#Vertrag`).
- **Trenner-Entscheidung:** zuerst Pipe `|`, dann auf **`#` gewechselt**. Begründung: Pipe ist auf der Tablet-Tastatur schlecht erreichbar (weit hinten) und per Stift unzuverlässig erkannt (`|` wurde zu `$1`/`I`). `prefixText '# '` aus beiden Tag-Feldern entfernt (sonst doppeltes `#`, da `#` jetzt die Eingabe selbst ist), Hint auf `#`-Format umgestellt.

### Lektion
- **Stift-Tagging geht (noch) nicht.** Das Tag-Feld ist ein normales Flutter-`TextField` → FreeScript schreibt da nicht hinein (gleiches Verhalten wie Session 8). Mit dem Stift über das Tag-Feld geschriebener Text landet im fokussierten **nativen** Feld (Hauptfeld), nicht im Tag-Feld. → Tags daher per Tastatur; Pen-Tagging bleibt v-next.
- **Handgeschriebene Sonderzeichen sind unzuverlässig.** FreeScript erkennt ein gemaltes `|` schlecht — Trennzeichen sollten tastaturfreundlich **und** stift-robust sein.

### Diskussion — für später erfasst (Cluster „Tag-Register + Autocomplete + Eintrag editieren")
1. **Trenner `#` vs. Leerzeichen:** Da Tag = ein Wort, würde Space als Feld-Trenner genügen. `#` wurde **vorerst behalten**, aber die Entscheidung ist bewusst offen. Erkenntnis: Feld-Trenner und Inline-Marker sind getrennte Belange — ein Inline-`#word` im Fließtext kann auch per **Regel** gesetzt werden („Wort = Tag → `#` davor"), unabhängig vom Feld. Revisitbar (ggf. Space im Feld).
2. **Tag-Normalisierung** (`ValSys` = `VaLSYs` → **ein** Tag): case-insensitiv zusammenführen, kanonische Schreibweise. Braucht ein zentrales **Tag-Register**, das es noch nicht gibt — Tags sind aktuell lose Strings am Eintrag.
3. **Tippfehler abfangen** (`Valsis`): entweder **„Meintest du `ValSys`?"** (Fuzzy-Autocomplete gegen das Tag-Register, 🟢 Enhancement) und/oder **nachträgliches Editieren** von Einträgen/Tags. Editierbarkeit ist 🟡 Core im Anforderungsdokument und noch **nicht gebaut** — würde Punkt 3 mit lösen.

### Nächste Session
1. **Tag-Register** als zentrale Tag-Liste einführen — Grundlage für Normalisierung (Punkt 2) und Autocomplete/„Meintest du…?" (Punkt 3).
2. **Eintrag/Tags nachträglich editieren** (🟡 Core) — löst u.a. die Tippfehler-Korrektur und ist ohnehin Pflicht für v1.0.
3. **Tinten-Modus konkretisieren** (aus Session 10): Strichdaten serialisieren (JSON), `JournalEntry` um einen Tinten-Körper erweitern, Striche laden/weiterschreiben.
4. **Anforderungsdokument aktualisieren** (offen seit Session 10: Engine-Entscheidung + Session-10-Festlegungen + jetzt `#`-Tags/Trenner-Notiz).
5. Perspektivisch: Migration `shared_preferences` → lokale DB; weiter Richtung v1.0 mit Google Calendar (Kalender→Tag-Zuordnung) und Claude-API.

### Offene Punkte
- **Pen-Tagging** ungelöst — Tag-Feld ist Flutter-`TextField`, nimmt keine native Handschrift (FreeScript).
- **Tag-Normalisierung / kanonische Schreibweise** — braucht Tag-Register.
- **Eintrags-Editierbarkeit (🟡 Core)** noch nicht gebaut.
- Trenner-Wahl `#` bewusst vorläufig (Space im Feld als Alternative offen).
- (bestehend aus Session 10) `JournalEntry` braucht Tinten-Körper; lokale Handschrift-Volltextsuche ungelöst; DB-Migration am Horizont; Test-Screen `native_text_test_screen.dart` bleibt als PoC-Referenz; ML Kit nur für gedruckten Text; Claude-Umfang offen; Google Calendar API-Zugänge stehen aus; Anforderungsdokument-Update ausstehend.

### Commit
- `759fad5` — "Mehrfach-Tags pro Eintrag: #-getrennte Tags via Tastatur-Feld, Stift-Screen liefert Text + Tags, parseTags-Util"
- Vorgänger: `1ccaae9`

## Session 12 — 20. Juni 2026

### Charakter der Session
- Offenes Zeitfenster (früher Morgen, vor dem Aufwachen der Familie). Drei abgeschlossene, getestete Bausteine an einem Morgen — Editierbarkeit, Tag-Register, Autocomplete.
- Arbeitsweise: Claude liest den echten Stand direkt aus dem öffentlichen Repo (`759fad5`), schreibt Code dagegen statt gegen eine Beschreibung.

### Erledigt

**1. Editierbarkeit (🟡 Core) — Commit `d813e3a`**
- Karte antippen öffnet dasselbe Eingabe-Sheet, **vorbefüllt** mit Inhalt + Tags; Speichern aktualisiert den Eintrag in place.
- `_openNewEntrySheet` → `_openEntrySheet({existing})` bedient Neu **und** Bearbeiten.
- `JournalEntry.copyWith` ergänzt (Modell).
- `formatTags()` in `tag_parser.dart` als Gegenstück zu `parseTags` (Round-trip fürs Tag-Feld beim Bearbeiten).
- `_updateEntry(id, content, tags)` — ersetzt per `id` via `copyWith`, persistiert.
- `_EntryCard` um `onTap` erweitert (Material + InkWell), Tap öffnet Bearbeiten.
- **Nebenbei behoben:** Tastatur-Tag-Feld trug noch den alten `|`-Hint + verwaisten `prefixText '# '` (Doc-Code-Abweichung aus Session 11, klassischer Layer-8/„VS Code hat scheinbar gespeichert") → auf `#`-Format angeglichen.
- Getestet ✅ inkl. Persistenz über App-Neustart im Flugmodus.

**2. Tag-Register mit Normalisierung — Commit `e12a01a`**
- Neue Datei `lib/utils/tag_registry.dart` (`TagRegistry`).
- Führt Schreibvarianten **case-insensitiv** zusammen: `ValSys` = `valsys` → eine kanonische Schreibweise.
- API: `canonicalize`, `canonicalizeAll`, `rebuildFrom`, `allTags`.
- **Abgeleitet, nicht separat persistiert:** beim Laden aus den Einträgen aufgebaut (`rebuildFrom`, chronologisch → erste Schreibweise gewinnt), beim Anlegen/Bearbeiten inkrementell ergänzt. Eine Wahrheit (die Einträge), kein Sync-Problem.
- Normalisierung greift **ab jetzt**; bereits gespeicherte Misch-Einträge werden beim Laden **nicht** still umgeschrieben (bewusst nicht-destruktiv).
- Getestet ✅: `Valsys`/`valsys` → beide Chips `#ValSys`; kanonische Form stammte aus den älteren Einträgen, die beim Start ins Register gelesen wurden (`rebuildFrom` bestätigt).

**3. Tag-Autocomplete (🟢 Enhancement) — Commit `e09b513`**
- Neues **wiederverwendbares** Widget `lib/widgets/tag_autocomplete_field.dart`.
- Vorschlags-Chips unter dem Tag-Feld, bezogen auf das gerade getippte Fragment (Text nach dem letzten `#`).
- Substring-Treffer (Prefix zuerst); kein Treffer → Fuzzy **„Meintest du …?"** via Levenshtein (Distanz ≤ 2, ab 3 Zeichen).
- Tap übernimmt den kanonischen Tag und hängt `#` für den nächsten an.
- An **beiden** Eingabewegen aktiv: Eintrags-Sheet (`journal_screen.dart`) und Stift-Screen (`native_text_entry_screen.dart` bekommt `knownTags`-Parameter, gefüttert aus `_tagRegistry.allTags`).
- Getestet ✅ an beiden Wegen.

### Entscheidungen
- **Kanonische Schreibweise: case-preserving, „erste Schreibweise gewinnt".** Alles-klein wurde bewusst geprüft und **verworfen**. Begründung: Steffens Tags sind Akronyme (`MBS`, `ValSys`) und deutsche Substantive (`Vertrag`, `Wasser`, `Wärme`, `Privat`, `Familie`) — kleingeschrieben schlechter lesbar bzw. im Deutschen falsch (Substantive werden großgeschrieben). Die Sorge „welche Variante gewinnt, ist reihenfolge-abhängig" wird **nicht** über Alles-klein gelöst, sondern später über eine **Tag-Verwaltung / Umbenennen** (kanonische Schreibweise selbst festlegen), die auf dem Register aufsetzt.
- **Bearbeiten via Tastatur**, nicht Stift: das native FreeScript-Feld kann (noch) nicht vorbefüllt werden — bräuchte `setText` in `NativeTextView.kt`. Da alle Einträge als Text gespeichert sind, deckt die Tastatur das Bearbeiten vollständig ab.
- **timestamp bleibt beim Bearbeiten erhalten** — ein bearbeiteter Eintrag behält seinen Platz auf der Zeitachse (passt zum Ein-Journal-Modell aus Session 10).

### Lektion
- **Wiederverwendbares Widget zahlt sich aus:** `TagAutocompleteField` einmal gebaut, an beiden Eingabewegen ohne Logik-Duplikat eingesetzt.
- **Lange Dateien lieber ganz überschreiben** statt chirurgisch editieren — „such den Block"-Anleitungen sind fehleranfällig.
- Tippfehler beim Einfügen (`ffinal`) bestätigt erneut: nach dem Einfügen kurz bauen, der Compiler fängt's sofort.

### Offene Punkte
- **Tag-Verwaltung / Umbenennen** — der saubere Hebel gegen die reihenfolge-abhängige Kanonisierung (heute neu beschlossen, noch nicht gebaut).
- **Tinten-Modus** weiterhin offen: `JournalEntry` braucht Tinten-Körper (Strichdaten), JSON-Serialisierung, Striche laden/weiterschreiben (aus Session 10).
- **Anforderungsdokument-Update überfällig** (seit Session 10) — jetzt zusätzlich: Editierbarkeit umgesetzt, Tag-Register/Normalisierung, Autocomplete, Schreibweisen-Entscheidung.
- Autocomplete-Politur denkbar: Fokus/Tastatur nach Chip-Tap halten; Vorschläge auch bei leerem Fragment (z.B. zuletzt genutzte Tags).
- (bestehend) Pen-Tagging ungelöst (FreeScript nur im Hauptfeld); lokale Handschrift-Volltextsuche ungelöst; DB-Migration am Horizont; `native_text_test_screen.dart` bleibt als PoC-Referenz; ML Kit nur für gedruckten Text; Claude-Umfang offen; Google Calendar API-Zugänge stehen aus.

### Nächste Session
1. **Anforderungsdokument aktualisieren** (überfällig — Engine FreeScript + alle Festlegungen Session 10–12).
2. **Tinten-Modus konkretisieren** (Strichdaten serialisieren, `JournalEntry` erweitern).
3. **Tag-Verwaltung / Umbenennen** (löst die Kanonisierungs-Willkür, ergänzt Editierbarkeit).
4. Perspektivisch: Migration `shared_preferences` → lokale DB; Google Calendar (Kalender→Tag); Claude-API.

### Commits (heute)
- `d813e3a` — "Eintraege editierbar: Karte antippen oeffnet vorbefuelltes Sheet, copyWith im Modell, formatTags-Round-trip, Tastatur-Tagfeld auf #-Format angeglichen"
- `e12a01a` — "Tag-Register mit Normalisierung: Schreibvarianten case-insensitiv zusammengefuehrt (ValSys = valsys), abgeleitet aus Eintraegen, canonicalize beim Anlegen/Bearbeiten"
- `e09b513` — "Tag-Autocomplete an beiden Eingabewegen: Vorschlags-Chips und 'Meintest du' (Fuzzy) im Eintrags-Sheet und Stift-Screen, wiederverwendbares TagAutocompleteField"
- Vorgänger: `759fad5`

---

## Session 13 — 23. Juni 2026

### Charakter der Session
- Frühes Zeitfenster (vor 05:00, vor dem Aufwachen der Familie), geplante 60 Min. Ein klar umrissenes Ziel — der **Tinten-Modus** —, dazu zwei Politur-Bausteine. Alles getestet, ein sauberer Commit am Ende.
- Arbeitsweise wie gehabt: Claude liest den echten Stand direkt aus dem öffentlichen Repo (`e09b513`), schreibt Code dagegen.
- Wichtige Vorab-Erkenntnis: `drawing_screen.dart` war seit Session 9 **totes Holz** (der Journal-Flow hängt am nativen FreeScript-Screen, der Canvas war nirgends mehr verdrahtet). Er wurde jetzt als **Tinten-Editor** wiederbelebt — kein anderer Aufrufer im Weg.

### Erledigt — Tinten-Modus (🔧 → ✅), Commit `7e8f794`

**1. Datenmodell für Tinte**
- Neue Datei `lib/models/ink_data.dart` mit `InkStroke` (Punktfolge `List<Offset>`, kompakt als flache Doubles, 1 Nachkommastelle) und `InkData` (alle Striche **plus** die Canvas-Größe `width`/`height` bei der Aufnahme).
- Begründung Strichdaten statt PNG: bleibt editier-/weiterschreibbar (Session-10-Beschluss). Die mitgespeicherte Canvas-Größe ist der Hebel fürs maßstabsgerechte Rendern (Vorschau, Orientierungs-Fit).
- `JournalEntry` um optionales Feld `ink` erweitert: `ink == null` → Text-Eintrag, sonst Tinten-Eintrag. Getter `isInk`. `copyWith` nimmt `ink` mit (kann setzen/aktualisieren, nicht auf null zurücksetzen — ein Eintrag wechselt den Modus nicht).

**2. Tinten-Editor** (`lib/screens/drawing/drawing_screen.dart`, vollständig neu)
- Nimmt `initialInk`, `initialTags`, `knownTags`. Liefert `InkResult(InkData, List<String> tags)` via `Navigator.pop`.
- Striche als `List<List<Offset>>`, Palm Rejection wie gehabt (`Listener` + `PointerDeviceKind.stylus`).
- Canvas-Größe wird beim Übernehmen aus dem `RepaintBoundary`-`RenderBox` gelesen und in `InkData` gespeichert.
- Eigenes Tag-Feld (`TagAutocompleteField`) unter dem Canvas — Tinten-Einträge sind taggbar.
- **OCR/ML-Kit-Pfad aus diesem Screen entfernt** (das Entscheidungs-Experiment ist abgeschlossen; der Screen ist jetzt reiner Tinten-Modus). Paket `huawei_ml_text` bleibt in `pubspec.yaml` für späteren Dokument-Import.

**3. Geteilte Painter** (`lib/widgets/ink_painter.dart`, neu)
- `InkLivePainter` — Live-Strich im Editor (Path, 1:1).
- `InkPreviewPainter` — skaliert `InkData` **uniform & zentriert** in den Karten-Vorschauplatz (nutzt die gespeicherte Original-Größe → relative Position bleibt erhalten).

**4. Verdrahtung im Journal** (`lib/screens/journal/journal_screen.dart`)
- Persistenz: `ink` wird beim Speichern mitgeschrieben (nur wenn vorhanden) und beim Laden geparst. **Rückwärtskompatibel** — alte Einträge ohne `ink`-Key laden als Text.
- „Neuer Eintrag"-Sheet: zusätzliches **Pinsel-Icon** (🖌️ `Icons.brush`) neben dem FreeScript-Stift → öffnet den Tinten-Editor. `_addInkEntry`.
- Karte **antippen**: Tinten-Eintrag → Tinten-Editor mit zurückgeladenen Strichen + Tags (`_openInkEditorEdit` → `_updateInkEntry`); Text-Eintrag → wie gehabt das Text-Sheet.
- `_EntryCard`: Tinten-Eintrag zeigt **Strich-Vorschau** (fixe Höhe 140, `InkPreviewPainter`) statt Text, plus kleines Pinsel-Icon am Zeitstempel. Tags unverändert darunter.

### Erledigt — Politur (im selben Commit)

**5. Strich-Radierer**
- Toggle-Button (🧹 `Icons.cleaning_services`, blau wenn aktiv) in der Editor-Leiste. Aktiv → Stift löscht **ganze** Striche per Distanz-Treffer (Punkt-zu-Segment, Schwelle 18 px). Teil-Radieren (Striche zerschneiden) bewusst draußen.

**6. Orientierungs-Fit beim Laden**
- Beim Öffnen eines Tinten-Eintrags werden die Striche per Post-Frame-Callback von der **gespeicherten** Canvas-Größe auf die **aktuelle** umgerechnet (uniform, zentriert — keine Verzerrung der Handschrift). Gleiche Größe → No-op (keine Regression im Normalfall). Greift bei Geräte-Drehung zwischen Erstellen und Bearbeiten.

### Getestet auf MatePad (MRDI-W09) ✅
- Tinten-Eintrag anlegen → Vorschau auf der Karte (Pinsel-Icon, Tag #MBS).
- Karte antippen → Striche zurück → weiterschreiben **und** zeichnen (Skizze ergänzt), Undo genutzt → Vorschau aktualisiert.
- Radierer: ganzer Strich verschwindet beim Drüberfahren.
- Orientierungs-Fit: gedrehter Eintrag wird eingepasst statt abgeschnitten.
- Text-Modus (Tastatur + FreeScript) unverändert; alte Einträge laden weiter.

### Erledigt — Tag-Verwaltung / Umbenennen (🟢 → ✅), Commit `62f7a3e`
- Seit Session 12 vorgemerkt: der saubere Hebel gegen die **reihenfolge-abhängige Kanonisierung** (kanonische Schreibweise selbst festlegen, statt „wer zuerst kam gewinnt").
- Neue Datei `lib/screens/tags/tag_management_screen.dart` (`TagManagementScreen`).
  - Listet alle bekannten Tags (aus `_tagRegistry.allTags`) mit **Nutzungszähler** je Tag (pro Eintrag max. einmal gezählt).
  - Tag antippen → Umbenennen-Dialog (vorbefüllt). Eingabe wird gesäubert (führendes `#` weg, getrimmt, erstes Wort).
  - Hält eine **Anzeige-Kopie** der Tags/Zähler aktuell, das eigentliche Umschreiben passiert im JournalScreen via `onRename`-Callback.
- `journal_screen.dart`:
  - **Tag-Icon** (`Icons.sell_outlined`) in der Titelleiste → öffnet die Verwaltung.
  - `_tagUsage()` — Zähler je Tag (Schlüssel kleingeschrieben).
  - `_renameTag(from, to)` — schreibt die neue Schreibweise **case-insensitiv durch alle Einträge** (Text- **und** Tinten-Einträge, da Tags am Eintrag modusunabhängig liegen). Trifft das Ziel einen bestehenden Tag → **Merge** (Duplikat pro Eintrag fällt weg). Danach Register-Rebuild + persistieren.
- **Löschen bewusst draußen** (eigener kleiner Folgebaustein).

### Getestet auf MatePad (MRDI-W09) ✅
- Bestand war bereits **einheitlich** (Normalisierung aus Session 12 hält) → kein „kaputter" Casing-Fall vorhanden.
- **Round-Trip** (reversibel): `#MBS` → `MBS-Test` → alle MBS-Einträge springen um, Zähler stimmt → zurück auf `MBS`. Beweist das Durchschreiben über alle Einträge.
- **Merge**: Wegwerf-Eintrag mit `#Muell` → `Muell` → `MBS` umbenannt → faltet zusammen, Eintrag trägt danach `#MBS`, Zähler addiert.
- App-Neustart → Umbenennungen bleiben.

### Lektion
- **Datei-Vertauscher früh sichtbar machen:** Beim Einfügen war einmal der Inhalt von `ink_painter.dart` in `drawing_screen.dart` gelandet. Der Compiler zeigte es sofort eindeutig (`InkPreviewPainter aus beiden importiert`, Import-Zeile am falschen Pfad, `DrawingScreen`/`InkResult` nicht gefunden). → Nach dem Einfügen kurz bauen; charakteristische erste Zeilen als Schnellcheck.
- **Geteilter Painter zahlt sich aus:** ein `InkPreviewPainter` für die Karte, ein `InkLivePainter` für den Editor — eine Datei, kein Duplikat.
- **Tote-Code-Wiederbelebung:** Vor dem Bauen prüfen, ob die Zieldatei überhaupt noch verdrahtet ist — `drawing_screen.dart` war es nicht, das vereinfachte die Umstellung (kein Aufrufer zu migrieren).

### Offene Punkte
- **Tag löschen** (aus allen Einträgen entfernen) — kleiner Folgebaustein zur Tag-Verwaltung, bewusst noch nicht gebaut.
- **Radierer-Politur denkbar:** Undo erfasst aktuell nur gezeichnete Striche, nicht das Radieren (kein Erase-Undo-Stack). Teil-Radieren offen.
- **Tinten-Auswertung durch Claude** (multimodale Bild-API) noch nicht angebunden — das Datenmodell (Striche → PNG bei Bedarf) ist dafür jetzt vorbereitet.
- (bestehend) lokale Handschrift-Volltextsuche von Tinte ungelöst; Migration `shared_preferences` → SQLite am Horizont; `native_text_test_screen.dart` bleibt als PoC-Referenz; ML Kit nur für gedruckten Text; Pen-Tagging ungelöst (FreeScript nur im Hauptfeld); Google Calendar API-Zugänge stehen aus; Claude-Umfang für v1.0 offen.

### Nächste Session
1. Perspektivisch: Migration `shared_preferences` → SQLite (Basis u.a. für Perlenkette).
2. Richtung v1.0: Google Calendar (Kalender→Tag), Claude-API (inkl. Tinten-Auswertung über die multimodale Bild-API).
3. Kleinkram: Tag löschen, Radierer-Undo, Autocomplete-Politur.

### Anforderungsdokument
- `disponere_anforderungen_v3_0.md`: **Tinten-Modus** 🔧 → ✅ (Canvas + Serialisierung vorhanden), **Tag-Verwaltung / Umbenennen** ⏳ → ✅. Beim nächsten Doc-Durchgang nachziehen.

### Commits (heute)
- `7e8f794` — "Tinten-Modus: Strichdaten als Vektoren serialisiert (InkData), drawing_screen als Tinten-Editor mit Karten-Vorschau, Editieren/Weiterschreiben, Strich-Radierer und Orientierungs-Fit beim Laden"
- `62f7a3e` — "Tag-Verwaltung: Tags umbenennen mit Durchschreiben ueber alle Eintraege, case-insensitiver Merge, Nutzungszaehler, erreichbar ueber Tag-Icon in der Titelleiste"
- Vorgänger: `e09b513`

---


## Session 14 — 06. Juli 2026

### Charakter der Session
- Nach langer Pause. Ein großer Teil der Zeit ging bewusst in **Prozess-Hygiene vor dem Code**: Beim Repo-Read fiel eine Doc-Code-Diskrepanz aus Session 13 auf (siehe unten), die erst geschlossen wurde. Danach klares Ziel: die **SQLite-Migration** (Priorität #1).
- Grundsatz-Beschluss dieser Session: **Doku wandert ab sofort mit ins Repo** (`docs/`), damit genau diese Diskrepanz-Klasse strukturell nicht mehr entstehen kann.

### Erledigt — SQLite-Migration (Persistenz 🔴), Commit `2e59e74`

**1. Neue Persistenz-Schicht** (`lib/data/journal_repository.dart`)
- `JournalRepository`: DB öffnen (`disponere.db`), Schema anlegen, CRUD — löst `shared_preferences` als Speicher ab.
- **Normalisiertes Schema** (bewusst, statt 1:1-JSON-Port):
  - `entries` (id, timestamp *indiziert*, content, ink als JSON-Blob *nullable*).
  - `entry_tags` (entry_id, tag, **tag_key** lowercase, **ord**) mit Index auf `tag_key`, PK `(entry_id, tag_key)`, FK auf `entries` mit `ON DELETE CASCADE` (`PRAGMA foreign_keys = ON`).
- **Begründung Schema:** erfüllt die Anforderung „abfragbar nach Datum / Tag / Zeitraum" (v3.0) direkt — Datum/Zeitraum über den indizierten ISO8601-`timestamp`, Tag über JOIN auf `entry_tags.tag_key` (case-insensitiv). `ord` hält die Anzeige-Reihenfolge der Tags je Eintrag stabil.
- **Bewusst NICHT vorentschieden:** die Perlenkette-Datenmodell-Frage (eigener Tag-Index vs. Laufzeit-Abfrage über Journal + Kalender + Aufgaben). Das Schema *ermöglicht* beides.
- CRUD transaktional: `upsert` (ein Eintrag), `upsertAll` (mehrere, für Tag-Rename), `delete` (mit Cascade; noch kein UI-Aufrufer, Grundlage für späteres Eintrag-Löschen), `loadAll`.

**2. Sicherer Einmal-Import** (`migrateFromPrefsIfNeeded`)
- Übernimmt vorhandene `shared_preferences`-Einträge **einmalig** in die DB, dann Flag `migrated_to_sqlite` — verhindert Doppel-Import und ein Wiederauftauchen später gelöschter Einträge.
- Alter Prefs-Key (`entries`) bleibt als **Backup** liegen (Cleanup ist ein späterer, eigener Schritt).

**3. Journal verdrahtet** (`lib/screens/journal/journal_screen.dart`)
- `_loadEntries`/`_saveEntries` (+ `dart:convert`, `shared_preferences`) raus; stattdessen `JournalRepository _repo`.
- Startsequenz `_init()`: Migration → `loadAll` → Register-Rebuild.
- Jede Mutation macht jetzt ein **gezieltes `upsert`** statt die ganze Liste zu schreiben; Tag-Rename persistiert via `upsertAll` **nur die tatsächlich geänderten** Einträge.
- **Tag-Register unverändert:** weiter Laufzeit-Ableitung aus den Einträgen (keine eigene Persistenz). `entry_tags` ist nur die zusätzliche, abfragbare Projektion.

**4. Dependencies** (`pubspec.yaml`)
- `sqflite`, `path` ergänzt.

### Getestet auf MatePad (MRDI-W09) ✅
- Start / Migration: leere Basis → leer (korrekt).
- Text-Eintrag anlegen → Neustart → bleibt.
- Tinten-Eintrag anlegen → Neustart → Vorschau bleibt, antippen → Striche zurück, weiterschreiben → bleibt.
- Bearbeiten (Text **und** Tinte) → Neustart → Änderung bleibt.
- Tag umbenennen (`Bentley` → `Bentley-Test`) → Neustart → bleibt; zweiter, unabhängiger Tag `#MBS` daneben — korrekt getrennt.
- Merge-Fall und Tag-Reihenfolge (`ord`) als Kür verstanden, nicht formal durchgespielt (Logik unverändert aus Session 13, nur die Speicherung wechselte).

### Lektion
- **Datei-Vertauscher schlug wieder zu — und wurde wieder sofort sichtbar:** Beim Einfügen landete der Dart-Inhalt von `journal_repository.dart` in `pubspec.yaml`. Der YAML-Parser zeigte es eindeutig (`///`-Doc-Kommentar in Zeile 14, „Mapping values are not allowed / missed a colon"). Erste-Zeile-Schnellcheck (`Get-Content <datei> -First 1`) fand es in Sekunden. Bei **Mehrfach-Datei-Lieferung** ist die Kreuzungsgefahr höher — Schnellcheck lohnt dann doppelt (Soll-Erstzeilen: `name: disponere` / `import 'dart:convert';` / `import 'package:flutter/material.dart';`).
- **Doc-Code-Diskrepanz strukturell schließen:** Tag-Verwaltung (`62f7a3e`) war in Session 13 committet, aber das zugehörige Abschlussdokument nie im Projekt abgelegt — das Doc stand einen Commit hinter der Realität. Nachgetragen. Konsequenz: Doku ab sofort ins Repo, damit `git status` so etwas sofort zeigt.

### Offene Punkte
- **Alter Prefs-Key-Cleanup** (`entries` + Flag) — bewusst später, wenn die SQLite-Basis sich bewährt hat.
- **Anforderungsdokument-Update** nachziehen: Persistenz „SQLite-Migration ⏳" → ✅, außerdem **Tinten-Modus** und **Tag-Verwaltung** → ✅ (seit Session 13 vorgemerkt).
- (bestehend) Tag löschen; Radierer-Undo / Teil-Radieren; lokale Tinten-Volltextsuche ungelöst; Tinten-Auswertung durch Claude (multimodale Bild-API) noch nicht angebunden; Perlenkette-Datenmodell offen; Pen-Tagging (FreeScript nur im Hauptfeld); Google Calendar API-Zugänge stehen aus; Claude-Umfang für v1.0 offen.

### Nächste Session
1. Richtung v1.0: **Google Calendar** (Kalender→Tag-Mapping) **oder** **Claude-API** (inkl. Tinten-Auswertung über die multimodale Bild-API) — je nach Lust; beide bauen jetzt auf einer abfragbaren DB auf.
2. Bei Gelegenheit: Anforderungsdokument-Durchgang (die ✅-Nachträge oben).

### Prozess / Repo
- **Doku ins Repo übernommen:** `docs/` mit den App-Doks (Fortschritt + Anforderungen). Private Doks (`steffen_projektplan.md`, `Heimlabor_Zusammenfassung.md`) via `.gitignore` ausgeschlossen — Repo ist öffentlich.
- Zwei-Commit-Muster pro Session ab jetzt: erst Code-Commit (Hash liegt vor), dann `docs:`-Commit mit dem Fortschrittsdokument, das den Hash nennt.

### Commits (heute)
- `2e59e74` — "Persistenz auf SQLite umgestellt: normalisiertes Schema (entries + entry_tags), tag-/datum-/zeitraum-abfragbar, transaktionales upsert, einmaliger Import aus shared_preferences mit Backup-Flag"
- `docs:` — Fortschritt Session 14 + Doku ins Repo (folgt direkt im Anschluss)
- Vorgänger: `62f7a3e`

## Session 15 — 07. Juli 2026

### Charakter der Session
- 45-Minuten-Box, fokussiert. Erstes **🟡-Core-Feature** nach dem Persistenz-Fundament: **Daily Info (Tagesinfo)** als vollständiger Durchstich (Modell → Persistenz → UI → Test), damit auf dem MatePad wirklich etwas anlegbar und über mehrere Tage sichtbar ist.
- Kurze Vor-Abstimmung: **eine** Architektur-Entscheidung zur Bestätigung gestellt (eigenes Modell + eigene Tabelle), Rest innerhalb des Scopes entschieden und reversibel geflaggt.

### Erledigt — Daily Info (🟡 Core), Commit `81f35fa`

**1. Neues Modell** (`lib/models/daily_info.dart`)
- `DailyInfo`: id, text, `startDate`, `endDate?` (**null = Einzeltag**, gesetzt = Zeitspanne).
- Reine **Kalendertage** (ohne Uhrzeit): `DailyInfo.dayOnly()` normalisiert; `coversDay(day)` prüft `start ≤ tag ≤ (end ?? start)`.
- `copyWith` mit `clearEndDate`-Flag — nötig, weil `endDate: null` sonst nicht von „nicht ändern" unterscheidbar wäre (Zeitspanne → Einzeltag zurücksetzen).
- **Bewusst kein `JournalEntry`:** eigene Identität, weil Zeitspanne statt Zeitpunkt und Erscheinen auf mehreren Tagen. Von Steffen bestätigt.

**2. Repo auf Schema-v2** (`lib/data/journal_repository.dart`)
- `_dbVersion` 1 → 2; `onUpgrade` ergänzt. Migrationen **stufenweise, ohne `else`** (Sprung v1→v3 liefe alle Stufen). Bestehende DB bleibt erhalten, `daily_info` wird ergänzt — **kein Deinstallieren nötig**.
- `_createDailyInfoTable` von `onCreate` **und** `onUpgrade` geteilt → Neuinstallation und Migration teilen dasselbe Schema (verhindert Schema-Drift).
- Tabelle `daily_info` (id, text, `start_date`, `end_date` *nullable*), Index auf `start_date`.
- **Datums-Key `yyyy-MM-dd`** (lexikographisch = chronologisch → direkt in Bereichsabfragen vergleichbar).
- CRUD: `upsertDailyInfo`, `deleteDailyInfo`, `loadAllDailyInfos` (für spätere Verwaltungsansicht), **`dailyInfosForDay(day)`** — die Bereichsabfrage `start_date <= ? AND COALESCE(end_date, start_date) >= ?`. Genau die Query-Fähigkeit, für die das Schema in Session 14 normalisiert wurde.

**3. Journal-Screen** (`lib/screens/journal/journal_screen.dart`)
- **Bernstein-Bereich** (`_kDailyInfoAccent = 0xFFD9A441`) als erstes ListView-Element (`itemCount = _entries.length + 1`): zeigt die **heute** betroffenen Infos + dezenten „+"-Einstieg; leer → Hinweistext.
- Erstellen/Bearbeiten-Sheet: Textfeld, Start-Datum-Picker, **Zeitspanne-Umschalter** (bis-Datum optional, nie vor Start), Löschen (nur im Bearbeiten-Fall).
- CRUD-Handler laden `_todayInfos` nach **jeder** Mutation neu (`_reloadTodayInfos`) — robust, damit z.B. eine Info mit Zukunftsdatum korrekt *nicht* heute erscheint.
- Fix beim Bau: Guards auf `existing != null` (statt separater `isEditing`-Bool) umgestellt, damit Dart `existing` in den Closures promotet (gleiche Technik wie im bestehenden Text-Sheet).

### Design-Entscheidungen (reversibel geflaggt)
- **Eigenes Modell + eigene Tabelle** (bestätigt).
- **Keine Tags** für Daily Info — Anforderung nennt „freier Text, Datum/Zeitspanne", kein Tag-System. Bewusst weggelassen.
- **„Oben im Journal" = heute betroffene Infos**; die Repo-Query nimmt ein beliebiges Datum → zieht sich bei späterer **Tages-Navigation** automatisch mit.
- **Bernstein-Akzent** zur klaren Abgrenzung vom kühlen Blau der Einträge (und Platz für spätere Aufgaben/Termine in eigenen Farben).

### Getestet auf MatePad (MRDI-W09) ✅
- Einzeltag ohne Bereichs-Label („07.07. Erste Tagesinfo") ✓
- Zeitspanne **mit** Label („07.07. – 10.07.") erscheint korrekt am 07.07. ✓
- **Info mit morgigem Datum taucht heute NICHT auf** — der eigentliche Beweis, dass die Datums-Bereichsabfrage greift ✓
- Bearbeiten (Text ändern) → aktualisiert ✓
- Löschen (Mülleimer im Sheet) → weg ✓
- **Neustart → Persistenz bestätigt:** gelöschte Info bleibt weg, echte Infos bleiben ✓

### Klarstellung — Handschrift-Quelle (wichtig für künftige Doku)
- Die Handschrift im **Tagesinfo-Feld** stammt von der **aktiven Tastatur (Google/Gboard-Handschrift)**, weil es ein normales Flutter-`TextField` ist — **nicht** von FreeScript.
- **FreeScript bleibt exklusiv** das dedizierte native Text-Eingabefeld über die PlatformView/EditText (`native_text_entry_screen`). Die beiden nicht vermischen.

### Prozess-Lektionen
- **Anweisungsreihenfolge = Ausführungsreihenfolge:** Instruktionen strikt linear von oben nach unten abarbeitbar halten (kein Hoch-/Runter-Scrollen). Terminal-Befehle bleiben unten — aber Schritte *nach* dem Terminal (Test-/Verifikations-Checkliste nach `run.ps1`) gehören dann auch **unter** die Befehle, nicht darüber.
- **Lange Dateien als Download:** ~1.300 Zeilen verifizierten Codes diesmal via Datei-Übergabe statt Chat-Blöcken, um Copy-Paste-Fehler bei der langen `journal_screen.dart` auszuschließen. Klammerbalance + Erstzeilen-Check vorab im Container gelaufen.

### Offene Punkte
- **Theme/Farb-Entscheidung bewusst geparkt:** dunkel + Bernstein vorläufig. Hängt mit der Tinten-Darstellung (aktuell hell-auf-dunkel) zusammen und betrifft **alle Screens** → eigene kleine Design-Brain-Session wert.
- **Aufgaben** (🟡 Core) als nächstes — keine externen Deps, analog Daily Info.
- (bestehend) Alter Prefs-Key-Cleanup; Tag löschen; Radierer-Undo / Teil-Radieren; lokale Tinten-Volltextsuche; Tinten-Auswertung durch Claude (multimodale Bild-API); Perlenkette-Datenmodell; Google Calendar API-Zugänge; Claude-Umfang für v1.0.

### Nächste Session
1. **Aufgaben** (🟡 Core): jederzeit erstellbar, Datum/Uhrzeit optional, am Fälligkeitstag automatisch im Journal, klar unterscheidbar von Kalenderterminen. Baut wie Daily Info direkt auf der abfragbaren DB auf.
2. Danach: Architektur-Sessions für **Google Calendar** und **Claude-API** vor dem Coden.

### Anforderungsdokument
- `disponere_anforderungen_v3_0.md`: **Daily Info ⏳ → ✅** nachgezogen (Feature-Beschreibung + Übersichtstabelle).

### Commits (heute)
- `81f35fa` — „feat: Daily Info (Tagesinfo) mit Einzeltag und Zeitspanne, erscheint automatisch an betroffenen Tagen"
- `docs:` — Fortschritt Session 15 + Anforderungsdoc-Nachzug (folgt direkt im Anschluss)
- Vorgänger: `2e59e74`

---

*Wird nach jeder Session aktualisiert.*
