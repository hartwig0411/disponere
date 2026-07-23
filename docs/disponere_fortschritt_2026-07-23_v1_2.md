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

## Session 16 — 08. Juli 2026

### Charakter der Session
- Fokussierte Box. Zweites 🟡-Core-Feature nach Daily Info: **Aufgaben (Tasks)** als vollständiger Durchstich (Modell → Persistenz mit eigenem `task_tags` → UI → Test), direkt auf der abfragbaren DB, kein externer Dienst.
- Kurze Zwischenfrage zu **Claude Code** bewusst vertagt (fokussiert bleiben). Danach eine Architektur-Empfehlung **revidiert** (Tags an Aufgaben doch rein, s.u.).
- Sprachregelung: **„Day"** meint ab jetzt einen Kalendertag (statt „Datum") zur Verwechslungsvermeidung — neues Feld heißt `dueDay`; bestehende DailyInfo-Felder (`startDate`/`endDate`) bleiben unangetastet.

### Erledigt — Aufgaben (🟡 Core), Commit `e7d7e96`

**1. Neues Modell** (`lib/models/task.dart`)
- `Task`: id, title, `dueDay?` (nur Kalendertag, null = ohne Day), `dueTime?` (`HH:mm`, nur mit Day sinnvoll), `done`, `tags`.
- Drei Zustände: kein Day / nur Day / Day+Uhrzeit. `dayOnly()`, `hasDay`, `isOverdue(today)`, `copyWith` mit `clearDueDay`/`clearDueTime` (wie DailyInfo — null-Rücksetzen von „nicht ändern" unterscheidbar).
- **Bewusst eigenes Modell:** eigener Erledigt-Zustand + optionaler Fälligkeits-Day, getrennt von Eintrag/DailyInfo.

**2. Repo auf Schema-v3** (`lib/data/journal_repository.dart`)
- `_dbVersion` 2 → 3; `_onUpgrade`-Stufe `if (oldVersion < 3)` ergänzt (stufenweise, ohne `else`; Bestand bleibt, kein Deinstallieren). `_createTaskTables` von `_onCreate` **und** `_onUpgrade` geteilt (kein Schema-Drift).
- Tabelle `tasks` (id, title, `due_day` *nullable*, `due_time` *nullable*, `done` 0/1), Index auf `due_day`. Tabelle **`task_tags`** — spiegelt `entry_tags` (lowercase `tag_key`, `ord`, FK `ON DELETE CASCADE`) → Aufgaben **nach Tag abfragbar**.
- CRUD: `upsertTask` (transaktional inkl. Tags), `deleteTask`, `loadAllTasks`, **`surfacedTasksForDay(day)`** (offen + `due_day ≤ day` **oder** ohne Day; erledigte/zukünftige raus; überfällige zuerst), **`tasksForTag(tag)`** (Fundament „alles zu einem Tag" / Perlenkette, noch kein UI-Aufrufer). `_hydrateTasks` lädt Tags in einer Abfrage nach.

**3. Journal-Screen** (`lib/screens/journal/journal_screen.dart`)
- **Grüner AUFGABEN-Bereich** (`_kTaskAccent = 0xFF5FA86A`) als zweites festes ListView-Element unter TAGESINFO (`itemCount = _entries.length + 2`).
- Erstellen/Bearbeiten-Sheet: Titel, `TagAutocompleteField`, optionaler Day-Picker, optionaler Uhrzeit-Picker (nur mit Day), Löschen (nur Bearbeiten).
- Karte: Checkbox links (hakt inline ab → Aufgabe verlässt die Liste), Karte antippen → Bearbeiten. Meta-Zeile: rotes „Überfällig · TT.MM. [· HH:mm]" bzw. Uhrzeit bzw. „Ohne Datum". `_reloadTasks` nach jeder Mutation.

### Erledigt — Aufgaben-Tags in die Tag-Verwaltung integriert (nachgezogene Restschuld, im selben feat)
- Beim „Tags ja"-Beschluss war offen geblieben, dass reine Aufgaben-Tags das Register nicht speisen. Steffen fiel es beim Test auf (`#Kur` nur an einer Aufgabe → Zähler „0 Einträge"). Jetzt sauber geschlossen:
  - **Register aus Einträgen *und* Aufgaben** aufgebaut (`_rebuildTagRegistry`, `_allTasks` gehalten). Einträge definieren die kanonische Schreibweise, Aufgaben übernehmen sie. Reine Aufgaben-Tags erscheinen jetzt in Autocomplete + Verwaltung, auch über Neustart.
  - **Nutzungszähler** weist Einträge und Aufgaben getrennt aus („N Einträge · M Aufgaben"; reiner Aufgaben-Tag → „M Aufgaben"). Neuer Parameter `taskUsage` in `TagManagementScreen`.
  - **Umbenennen zieht Aufgaben-Tags mit durch** (`_renameTag` schreibt Einträge **und** Aufgaben um, Merge inklusive) — sonst hätte der Zähler nach einem Rename gelogen.

### Design-Entscheidungen (reversibel geflaggt)
- **Tags an Aufgaben: ja** (Empfehlung revidiert). Ohne sie fehlten Aufgaben in der „alles zu einem Tag"-Ansicht — dem App-Kern. Kein Vorziehen der Perlenkette, sondern deren Fundament. Speicherung **normalisiert** (`task_tags`), nicht als JSON-Spalte.
- **Überfällige bleiben sichtbar** (rotes Label), statt am Folgetag lautlos zu verschwinden — ehrliche Lesart von „surft am Tag auf, an dem sie zählt".
- **Erledigt = raus aus der Liste** (bleibt in DB). Wieder-Aufhaken erst über die geplante Übersicht.
- **Grüner Akzent**, provisorisch (Theme weiter geparkt).

### Getestet auf MatePad (MRDI-W09) ✅
- Ohne Day → sofort da („Ohne Datum"), bleibt über Neustart.
- Day = heute (+ Uhrzeit) → erscheint, Zeit als Meta.
- **Day = morgen → erscheint heute NICHT** (Zukunftsfall, Beweis der Query).
- Day = gestern → rotes „Überfällig · 07.07. · 16:00", roter Balken.
- Abhaken → verschwindet; Karte antippen → Bearbeiten; Tag-Round-trip; Sortierung überfällig → heute → undatiert.
- Punkt 1: `#Kur` nur an Aufgabe → Verwaltung zeigt „1 Aufgabe"; Umbenennen zieht den Chip mit; Autocomplete schlägt den Tag im Eintrag vor.

### Offene Punkte / Nächste Session
- **Aufgaben-Übersicht** (von Steffen gewünscht, bewusst eigene Session): abrufbarer Screen; **offene** Aufgaben mit Sortieroption **Tag / Day** (Standard Day); **erledigte** zusammengeklappt; Checkbox + Bearbeiten direkt dort (einziger Ort zum Wieder-Aufhaken einer erledigten Aufgabe). Vorab zu klären: Einstieg (Listen-Icon in der AUFGABEN-Kopfzeile), „Sortierung Tag" flach vs. gruppiert.
- **Tag löschen** weiter offen; **Rename über Aufgaben** ist jetzt drin.
- Danach: Architektur-Sessions **Google Calendar** und **Claude-API** vor dem Coden.
- (bestehend) Prefs-Key-Cleanup; Radierer-Undo / Teil-Radieren; lokale Tinten-Volltextsuche; Tinten-Auswertung durch Claude (multimodale Bild-API); Perlenkette-Datenmodell; Pen-Tagging (FreeScript nur im Hauptfeld); Google-Calendar-Zugänge; Claude-Umfang für v1.0.

### Anforderungsdokument
- `disponere_anforderungen_v3_0.md`: **Aufgaben §6 ⏳ → ✅** und **Aufgaben-Management (Übersichtstabelle) ⏳ → ✅** (Kern erfüllt: erstellen/bearbeiten/löschen/abhaken/taggen, automatisch am fälligen Day). Die gewünschte **Übersicht** als nächster Baustein vermerkt (kein Teil des §6-Wortlauts).

### Commits (heute)
- `e7d7e96` — „feat: Aufgaben mit optionalem Faelligkeits-Day, Uhrzeit und Tags; erscheinen automatisch am faelligen Day, ueberfaellige bleiben sichtbar; Aufgaben-Tags zaehlen in der Tag-Verwaltung und werden beim Umbenennen mitgezogen"
- `docs:` — Fortschritt Session 16 + Anforderungsdoc-Nachzug (folgt direkt im Anschluss)
- Vorgänger: `81f35fa`


## Session 17 — 09. Juli 2026

### Charakter der Session
- In Session 16 bewusst vertagter, von Steffen gewünschter Baustein: die **Aufgaben-Übersicht**. Reine UI auf vorhandenen Queries (`loadAllTasks`) — kein neues Schema, kein externer Dienst.
- Zwei Vorab-Entscheidungen bestätigt: Einstieg per **Checklisten-Icon in der AUFGABEN-Kopfzeile**; „Sortierung nach Tag" **gruppiert** (nicht flach) — die „alles zu einem Tag"-Lesart, die den App-Kern trägt.
- Nebenbei (getrennt, eigener `chore:`): Template-Test `widget_test.dart` entfernt — er zeigte auf die längst entfernte Default-Counter-App `MyApp` und testete nichts Reales.

### Erledigt — Aufgaben-Übersicht (🟡 Core-Folgebaustein), Commit `274af60`

**1. Wiederverwendbares Aufgaben-Sheet** (`lib/widgets/task_sheet.dart`, neu)
- `_openTaskSheet` aus `journal_screen.dart` als top-level **`showTaskSheet(...)`** herausgelöst. Persistenz/Reload liegen bewusst **nicht** im Sheet, sondern beim Aufrufer (Callbacks `onSave`/`onDelete`) — Journal und Übersicht teilen exakt dieselbe UI, keine Drift.
- Das Sheet baut die fertige `Task` (frische id bei „neu", übernommene id + **erhaltener** `done`-Status bei „bearbeiten"; `done` wird nur über die Checkbox verändert, nie im Sheet). Tags über die geteilte `TagRegistry` kanonisiert.
- Alte `_addTask`/`_updateTask` im Journal entfallen; `_openTaskSheet` ist jetzt dünne Delegation. `_DateRow` behält nur noch den Kalender-Fall (der nach dem Auslagern ungenutzte `icon`-Parameter entfernt → Analyzer sauber).

**2. Aufgaben-Übersicht** (`lib/screens/tasks/task_overview_screen.dart`, neu)
- Eigener Screen; lädt selbst über `loadAllTasks` und aktualisiert seinen Zustand nach jeder Mutation. Das Journal lädt beim Zurückkehren ohnehin neu, muss also nicht aktiv benachrichtigt werden.
- **Umschalter** `SegmentedButton` „Nach Day" (Standard) / „Nach Tag".
- **Nach Day:** offene Aufgaben aufsteigend nach Fälligkeits-Day (überfällige damit zuerst, rot), gleicher Day nach Uhrzeit, undatierte ans Ende.
- **Nach Tag:** gruppiert — Kopf `#Tag · N`, eine Aufgabe erscheint **unter jedem** ihrer Tags; „Ohne Tag" am Ende; Köpfe alphabetisch (case-insensitiv, kanonische Schreibweise aus dem Register).
- **Erledigt · N** als eingeklappte `ExpansionTile` darunter — der **einzige** Ort zum Wieder-Aufhaken; erledigte Titel durchgestrichen und gedämpft.
- Checkbox (hakt ab/auf) und Karten-Tap (öffnet dasselbe Sheet, inkl. Löschen) direkt im Screen.

**3. Journal-Anbindung** (`lib/screens/journal/journal_screen.dart`)
- Grünes **Checklisten-Icon** in der AUFGABEN-Kopfzeile → `_openTaskOverview`; bei Rückkehr `_reloadTasks`, sodass abgehakte/bearbeitete/neue Aufgaben sich sofort in der heutigen Liste spiegeln.

### Design-Entscheidungen (reversibel geflaggt)
- **Wiederverwendung statt Duplikat:** ein Sheet, zwei Aufrufer. Kosten: minimale private Duplikate (Karten-/Chip-Darstellung) in der Übersicht — bewusst in Kauf genommen, statt den ~1500-Zeilen-Journal-Screen breit umzubauen. Spätere Konsolidierung möglich, wenn gewünscht.
- **Gruppiert statt flach** bei „Nach Tag" — Fundament der „alles zu einem Tag"-Sicht und optische Vorstufe der Perlenkette.
- **`withOpacity`** in den neuen Dateien belassen (konsistent zum repo-weiten Bestand); die Umstellung auf `withValues()` bleibt ein eigener, repo-weiter Aufräum-Schritt.

### Getestet auf MatePad (MRDI-W09) ✅
- „Nach Day": OFFEN · 4 korrekt sortiert (überfällig/heute/undatiert), Tag-Chips sichtbar.
- Abhaken → wandert in „Erledigt · N" (eingeklappt); Leerzustand „Keine offenen Aufgaben" erscheint, „Erledigt · 6" bleibt darunter.
- Wieder-Aufhaken aus „Erledigt" → Aufgabe zurück nach oben.
- Einstieg per Checklisten-Icon; Rücksprung ins Journal spiegelt die Änderungen.

### Offene Punkte / Nächste Session
- „Nach Tag"-Ansicht in der Praxis mit mehreren Tags breiter testen (Mehrfachnennung derselben Aufgabe unter je einem Tag ist gewollt).
- Danach: Architektur-Sessions **Google Calendar** und **Claude-API** vor dem Coden.
- (bestehend) `withOpacity` → `withValues()` repo-weit; Tag löschen; Prefs-Key-Cleanup; Radierer-Undo/Teil-Radieren; lokale Tinten-Volltextsuche; Tinten-Auswertung durch Claude (multimodale Bild-API); Perlenkette-Datenmodell; Pen-Tagging; optionaler Smoke-Test als Ersatz für den entfernten Template-Test.

### Anforderungsdokument
- Keine Statusänderung nötig: **Aufgaben-Management** war bereits ✅ (Session 16), die **Übersicht** dort als „nächster Baustein" vermerkt — jetzt erfüllt. §6-Wortlaut unverändert.

### Commits (heute)
- `9fa0e0f` — „chore: Template-Test widget_test.dart entfernt (testete die nicht mehr existierende Default-Counter-App)"
- `274af60` — „feat: Aufgaben-Uebersicht als eigener Screen — offene Aufgaben sortierbar nach Day (Standard) oder nach Tag (gruppiert, eine Aufgabe unter jedem Tag), erledigte eingeklappt und nur dort wieder aufhakbar; Aufgaben-Sheet als wiederverwendbares showTaskSheet ausgelagert (Journal und Uebersicht teilen dieselbe UI); Einstieg ueber Checklisten-Icon in der AUFGABEN-Kopfzeile"
- `docs:` — Fortschritt Session 17 (folgt direkt im Anschluss)
- Vorgänger: `73dc2c5`

---

## Session 18 — 11. Juli 2026

### Charakter der Session
- **Architektur-Session** (kein Code): Design der **Google Calendar-Anbindung** — eine der zwei
  verbleibenden 🟡-Core-Features für App v1.0 (die andere: Claude-API). Ergebnis ist ein eigenes
  Architektur-Dokument als Grundlage für zwei nachfolgende Coding-Sessions.
- Ausgangspunkt war die Spannung „HMS Core, **kein** Google" auf dem Gerät vs. Google-Calendar als
  Core-Anforderung. Auflösung: **google-frei bleibt das Gerät** (kein GMS, kein `google_sign_in`);
  mit Google wird über **HTTPS-REST + GMS-unabhängigen OAuth** geredet.

### Ergebnis — Architektur-Dokument
- Neu: `docs/disponere_architektur_google_calendar_v1_0.md` (Design abgeschlossen, vor Coding).

### Fünf bestätigte Architektur-Entscheidungen
1. **Auth:** AppAuth (System-Browser/Custom-Tab, Authorization Code + PKCE) primär; Device-Flow als Fallback.
2. **Scope:** read-only (`calendar.readonly`) — Datenfluss einseitig, Kalender → Journal.
3. **Datenmodell:** eigene `calendar_events`-Tabelle, ins Journal eingeblendet **wie Aufgaben**
   (Schema v4, spiegelt das Tasks-Muster mit normalisierten `event_tags`).
4. **Tags:** nur Kalender→Tag global (Termin erbt die Tags seines Kalenders); kein Per-Termin-Override in v1.0.
5. **Secrets:** Config git-ignored (+ `.example`); Refresh-Token in `flutter_secure_storage` (Keystore), nicht in SQLite.

### Durchgespielte Nutzungsfrage (Familien-/Business-Kalender)
- **Kalender-Auswahl** ist eingebaut (`calendar_sources.enabled`): pro Kalender an/aus + Tag-Mapping.
- **Ein Event „gehört" genau einem Kalender.** Es in zwei Kalendern *auftauchen* zu lassen geht per
  **Einladung** (verknüpfte Kopien, gleiche `iCalUID`) oder **„Kopieren nach…"** (eigenständige Dublette).
  - *Immer relevant* → **einladen** (zieht bei Verschiebung mit).
  - *Nur manchmal relevant* („Maria nähen" nur bei Anjas Spätschicht) → **„Kopieren nach…"** in den Hub-Kalender.
    Die **Bedingung** wertet der Nutzer aus, nicht die App.
- Konsequenz fürs Modell: **`iCalUID` wird mitgeführt** (Dedup-Reserve).

### Hub-Konto & Business-Adresse (entschieden: zurückgestellt)
- **Hub-Konto = bestehendes Google-Konto (gmail).** Proton bleibt für Business-Mail.
- Ein **Nicht-Gmail-Google-Konto** (Business-Adresse als Identität) ist gratis möglich, hat aber
  **kein Gmail-Postfach** → per **Outlook ge-mailte** Einladungen (z.B. BEW-Wärme) landen **nicht**
  automatisch im Google-Kalender (Google scannt kein fremdes Postfach). Zulauf dann nur per ICS-Abo/Handimport.
- **Google→Google**-Einladungen landen dagegen automatisch (intern durchgereicht).
- Der bezahlte „sauber automatisch"-Weg wäre **Google Workspace** für die Domain — vom Nutzer als zu teuer
  eingestuft. **Entscheidung dieser Session:** alles beim Alten, **kein Rumzaubern mit der Business-Adresse**;
  Business-Identität/Workspace **nicht Teil von v1.0**.
- IONOS (Domain-Hoster) wurde nur als Mail-Postfach betrachtet, **nicht** als Kalender-Quelle; ein IONOS-Kalender
  wäre nur als ICS-Bridge relevant (Disponere ist per Anforderung Google-Calendar-only).

### Nächste Schritte
- **Vor Coding-Session A** (außerhalb des Codes): Google-Cloud-Projekt anlegen, Calendar API aktivieren,
  OAuth-Consent-Screen (Testing, Steffen als Testnutzer), OAuth-Client. Klick-Pfade dann in der Session,
  nicht vorab.
- **Coding-Session A:** Auth (AppAuth/PKCE) + Einstellungen (Kalender listen, aktivieren + Tag-Mapping, Token sicher ablegen).
- **Coding-Session B:** Sync-Engine (`syncToken`, `singleEvents=true`) + Schema-v4-Migration + Einblendung („TERMINE"-Sektion) + „Sync jetzt".
- (bestehend) danach Architektur-Session **Claude-API**; sowie die offenen Aufräumpunkte
  (`withOpacity` → `withValues()`, Tag löschen, Smoke-Test u.a.).

### Anforderungsdokument
- Keine Statusänderung: *Google Calendar-Anbindung* bleibt 🟡 Core ⏳ (Design steht, Umsetzung folgt in Coding A/B).

### Commits (heute)
- `docs:` — Architektur Google Calendar v1.0 + Fortschritt Session 18 (dieser Commit; reine Design-Session, kein Code).
- Vorgänger: `d51f6dc`

---

## Session 19 — 15./16. Juli 2026

**Coding-Session A, Teil 1: Auth.** Die Session wurde in zwei testbare Teile
geschnitten — Teil 1 (Auth) und Teil 2 (Schema v4, Kalenderliste, Tag-Mapping).
Grund: Der Custom-Tabs-Test auf EMUI (§10 des Architekturdokuments) war das
größte Risiko und gehörte an den Anfang, nicht ans Ende.

### Erledigt
- Pakete: `flutter_appauth`, `flutter_secure_storage`, `http`
- `lib/config/google_config.dart` (Client-ID, Redirect-Schema) — **git-ignoriert**;
  `google_config.example.dart` als eingecheckte Vorlage
- `build.gradle.kts`: `appAuthRedirectScheme` als `manifestPlaceholder`
- `GoogleAuthService` (`lib/services/google_auth_service.dart`): `signIn`, `signOut`,
  `isSignedIn`, `accessToken` mit stillem Refresh. Refresh-Token im Android-Keystore,
  Access-Token nur im Speicher (Cache mit 1-Minute-Sicherheitsabstand zum Ablauf)
- `CalendarSettingsScreen` (`lib/screens/settings/calendar_settings_screen.dart`):
  Konto verbinden/trennen, Zugriff prüfen; Fehlertext als `SelectableText`
- Einstieg über neues Kalender-Symbol in der Journal-AppBar
- **Auf dem MatePad getestet und bestanden:** Login, stiller Refresh nach App-Neustart
  (= einmaliger Login belegt), Trennen und erneutes Verbinden
- Google Auth Platform → Branding: App-Name von „Dosonere" auf **„Disponere"** korrigiert

### Erkenntnis 1 — Custom URI Scheme braucht einen Schalter
Google liefert für Android-OAuth-Clients standardmäßig `Fehler 400: invalid_request`
mit dem Detail *„Custom URI scheme is not enabled for your Android client."*

**Lösung:** Google Auth Platform → Clients → Android-Client → **Erweiterte
Einstellungen** → **„Enable custom URI scheme"** einschalten, speichern, ~10 Minuten
warten. Reine Server-Seite, kein Rebuild nötig.

**Risiko:** Google beschriftet den Schalter mit „nicht empfohlen für Android-Clients",
und die Doku heißt inzwischen *„OAuth 2.0 for iOS & Desktop Apps"* — Android ist aus
dem Titel verschwunden. Der offizielle Android-Ersatz ist Googles Authorization-API
und **setzt Play Services voraus** — auf dem MatePad nicht verfügbar. Der Weg trägt
heute, kann aber wegfallen. **§3 #1 des Architekturdokuments ist entsprechend zu
relativieren.**

### Erkenntnis 2 — der Device-Flow-Fallback existiert nicht
§10 nennt den Device-Flow („OAuth 2.0 for TVs and Limited-Input Devices") als
Ausweichplan, falls Custom Tabs auf EMUI nicht funktionieren. **Das trägt nicht:**
Der Device-Flow erlaubt nur eine feste Scope-Liste — `email`, `openid`, `profile`,
`drive.appdata`, `drive.file`, `youtube`, `youtube.readonly`. **`calendar.readonly`
ist nicht dabei.**

**§10 muss ersetzt werden.** Kandidaten für einen echten Ausweichplan, falls Google
den Schalter abschafft:
- **ICS-Geheimadresse** pro Kalender (kein OAuth, kein Token; dafür Tag-Mapping
  von Hand, kein Delta-Sync, und ein RRULE-Motor nötig — der Vorteil von
  `singleEvents=true` fiele weg)
- **HTTPS-Redirect über Android App Links** mit eigener Domain (`assetlinks.json`);
  ungeprüft, welcher Client-Typ das bei Google zulässt

*Positiv:* Custom Tabs laufen auf EMUI einwandfrei — das Risiko, das §10 absichern
sollte, ist gar nicht eingetreten.

### Erkenntnis 3 — `taskAffinity=""` verhindert den Rücksprung
Nach erfolgreichem Login blieb der Browser im Vordergrund; die App kam nicht nach vorn
und meldete anschließend „User cancelled flow".

Das Logcat zeigte: `RedirectUriReceiverActivity` **lief** — die Umleitung kam also an —
aber in **Task 3045**, während die App in **Task 3044** lag. Ursache:
`android:taskAffinity=""` an `MainActivity` (aus der Flutter-Vorlage, seit dem
Initial-Commit `042686d` drin). AppAuths Activities haben die Standard-Affinität
(= Paketname); zwei verschiedene Affinitäten ergeben zwei Tasks.

**Lösung:** `android:taskAffinity=""` aus dem Manifest entfernt. Das Verhalten ist in
der `flutter_appauth`-Doku ausdrücklich beschrieben.

**Bewusste Abwägung:** `taskAffinity=""` erschwert das Kapern des Task-Stacks durch
fremde Apps. Für eine Ein-Personen-App auf einem einzelnen Gerät ist das theoretisch;
ein funktionierender Login wiegt schwerer.

### Offene Punkte (neu)
- **Zustimmungsbildschirm steht auf „Testing"** → Refresh-Token läuft nach 7 Tagen ab.
  Umstellung auf **„In production" (unverifiziert)** ist Voraussetzung dafür, dass der
  einmalige Login dauerhaft trägt. **Noch nicht entschieden.**
- **Architekturdokument nachziehen:** §3 #1 relativieren, §10 ersetzen, §12 um den
  Schalter „Enable custom URI scheme" ergänzen. → Docs-Commit von Teil 2.
- **Brave verhält sich anders als der Huawei-Browser:** Beim Brave-Versuch lief
  `RedirectUriReceiverActivity` gar nicht erst. Nach dem taskAffinity-Fix nur mit dem
  Huawei-Browser getestet. Kein Blocker, aber ungeklärt.
- **Java-8-Warnungen** beim Build (aus einer Abhängigkeit, nicht aus eigenem Code).
- **PowerShell Execution Policy** auf Vega blockiert `.\run.ps1`; Workaround
  `powershell -ExecutionPolicy Bypass -File .\run.ps1`. `adb` ist nicht im PATH.
- (bestehend) `withOpacity` → `withValues()`, `unnecessary_underscores`, Tag löschen,
  Smoke-Test.

### Nächste Schritte
- **Coding-Session A, Teil 2:** Schema v4 (`calendar_sources` + `calendar_source_tags`),
  `calendarList.list`, Kalender an/aus + Tag-Mapping. `calendar_events` folgt in
  Session B als v5.
- **Coding-Session B:** Sync-Engine (`syncToken`, `singleEvents=true`), Schema v5,
  Einblendung („TERMINE"-Sektion), „Sync jetzt".

### Anforderungsdokument
- Keine Statusänderung: *Google Calendar-Anbindung* bleibt 🟡 Core ⏳.

### Commits (heute)
- `04c98e4` — feat: Google-Konto-Anbindung mit OAuth und PKCE (Session A, Teil 1)
- `docs:` — Fortschritt Session 19 (dieser Commit; zitiert `04c98e4`)
- Vorgänger: `5e6fd01`

---

## Session 20 — 21. Juli 2026

Zwei Vorarbeiten plus Coding-Session A, Teil 2 — in einer Sitzung. Konsole/Config,
Architektur nachgezogen, dann gecodet und auf dem MatePad abgenommen.

### Erledigt — Vorarbeiten
- **Zustimmungsbildschirm auf „In Produktion" (unverifiziert) umgestellt.**
  `calendar.readonly` ist ein sensibler Scope; in „Testing" lief das Refresh-Token
  nach 7 Tagen ab. Nach der Umstellung auf dem MatePad einmal Konto getrennt und neu
  verbunden → frischer Token, der dauerhaft trägt. Der „nicht verifiziert"-Warnhinweis
  beim Login ist erwartet und wird einmal weggeklickt.
- **Architekturdokument nachgezogen** (`218eeb2`): §3 #1 relativiert (kein Fallback),
  §10 ersetzt (Custom-Tabs auf EMUI bestätigt, Device-Flow entfällt — `calendar.readonly`
  nicht in dessen erlaubter Scope-Liste), §12 auf „erledigt" gezogen samt „Enable custom
  URI scheme"-Schalter und `taskAffinity`-Fallstrick. Zusätzlich §5/§13 auf den
  **Schema-Split v4/v5** umgestellt.

### Erledigt — Coding-Session A, Teil 2 (`a555f3c`)
- **Schema v4** (`_dbVersion` 3→4, additive Migration via `_onUpgrade`):
  `calendar_sources` (`calendar_id` PK, `display_name`, `enabled` 0/1 default 0,
  `sync_token?`) und `calendar_source_tags` (spiegelt `task_tags`: lowercase `tag_key`,
  `ord`, ON DELETE CASCADE). Bestehende Einträge/Aufgaben bleiben unberührt.
- **Neue Dateien:** `lib/models/calendar_source.dart` (Modell mit `copyWith`),
  `lib/services/google_calendar_service.dart` (`calendarList.list` als roher `http`-GET
  mit Bearer-Token aus `GoogleAuthService`).
- **Repository-Methoden:** `loadCalendarSources`, `upsertCalendarSource` (spiegelt
  `upsertTask`), `mergeCalendarList` (vorhandene behalten `enabled`/Tags/`sync_token`,
  neue kommen aus, verschwundene fliegen samt Mapping raus).
- **UI** (`calendar_settings_screen.dart` neu geschrieben): Button „Kalender
  laden/aktualisieren", je Kalender Aktiv-Schalter + Tag-Chips + Tag-Editor
  (`TagAutocompleteField`, kanonisiert über die geteilte `TagRegistry`). Alles wandert
  sofort in die DB.
- **Kanten-Fix (die „zwei Zeilen"):** Kalender-Tags fließen jetzt ins Tag-Register
  (`journal_screen`: `_calendarSources` gehalten, im `_rebuildTagRegistry` mitgefüttert,
  nach Rückkehr aus den Einstellungen neu geladen). Ein nur an einem Kalender hängender
  Tag taucht dadurch im Autocomplete auf.

### Auf dem MatePad bestätigt
- Kalenderliste lädt vollständig (Business, Familie, Feiertage, googlemail,
  Kalenderwochen, Marvin-Kalender, harder-business).
- Aktivieren funktioniert; `steffen@harder-business.com` aktiviert und mit `#Wärme`
  getaggt.
- **Neustart-Persistenz:** Schalter + Tag stehen nach komplettem Neustart direkt aus der
  DB da, ohne erneutes Laden.
- **Autocomplete-Kante:** neuer Journal-Eintrag mit `#Wärme` — der nur am Kalender
  hängende Tag wurde vorgeschlagen.

### Entscheidungen & Lektionen
- **„In Produktion" (unverifiziert)** ist für die Ein-Personen-App der richtige Weg.
  Das 100-Nutzer-Limit ist projektweit und permanent; die verifizierte Domain
  `harder-business.com` läge für eine spätere Verifizierung (leichte Variante, ohne
  jährliche Sicherheitsprüfung — Calendar ist *sensibel*, nicht *eingeschränkt*) bereit.
- **Schema-Split:** v4 = nur Quellen (Teil 2), v5 = Termine (Session B). Kleine, für sich
  testbare Migrationen statt eines großen Sprungs.
- **Kalenderliste roh über `http`** (kein `googleapis`) — nichts Neues in den Deps; die
  Paketfrage für den Sync bleibt für Session B offen und ändert das Design nicht.
- **Merge statt Überschreiben:** lokaler Zustand (`enabled`, Tags) überlebt jedes erneute
  Laden der Kalenderliste.

### Offene Punkte
- `Switch.activeColor` gilt in ganz neuen Flutter-Versionen als deprecated — bislang nur
  eine mögliche Warnung, kein Fehler. Bei Bedarf auf `activeThumbColor` umstellen.
- (bestehend) `googleapis`-vs-`http`-Entscheidung für die Sync-Engine (Session B),
  Java-8-Warnungen aus einer Abhängigkeit, PowerShell Execution Policy (`-ExecutionPolicy
  Bypass`), `adb` nicht im PATH.

### Nächste Schritte
- **Coding-Session B:** Schema **v5** (`calendar_events` + `event_tags`) via `_onUpgrade`,
  Sync-Engine (`syncToken`, `singleEvents=true`, Fenster −30/+365, Delta-Sync + Resync bei
  410), Einblendung als „TERMINE"-Sektion im Journal, „Sync jetzt"-Button.

### Anforderungsdokument
- *Google Calendar-Anbindung* bleibt 🟡 Core ⏳ — Teil 2 von zwei Coding-Sessions ist
  erledigt (Auth + Kalenderauswahl + Tag-Mapping stehen); der eigentliche Termin-Sync
  folgt in Session B.

### Commits (heute)
- `218eeb2` — docs: Architektur Google Calendar nachgezogen (In Produktion, Device-Flow
  raus, Schema v4/v5 Split)
- `a555f3c` — feat: Kalenderliste, Schema v4 und Tag-Mapping (Session A, Teil 2)
- `docs:` — Fortschritt Session 20 (dieser Commit; zitiert `a555f3c`)
- Vorgänger: `a41608c`

---

## Session 21 — 22. Juli 2026

**Coding-Session B, Teil 1: der Datenweg.** Session B wurde — wie schon Session A —
in zwei testbare Teile geschnitten: Teil 1 holt die Termine ins lokale Schema,
Teil 2 blendet sie im Journal ein. Grund war das 45-Minuten-Fenster und die
Größe von `journal_screen.dart`: Der Datenweg ist für sich prüfbar (Sync läuft,
Zähler stimmt), die Einblendung ist danach reine UI-Arbeit auf fertigen Daten.

### Erledigt — Commit `a5549a1`

**1. Neues Modell** (`lib/models/calendar_event.dart`)
- `CalendarEvent`: `calendarId` + `eventId` als zusammengesetzte Identität,
  `iCalUid`, `summary`, `location`, `allDay`, `startDay`/`endDay` (`yyyy-MM-dd`),
  `startTime`/`endTime` (`HH:mm`, lokale Zeit), geerbte `tags`.
- **`endDay` ist inklusiv.** Google liefert bei ganztägigen Terminen ein
  *exklusives* `end.date` (der Tag *nach* dem Ende). Die Umrechnung passiert
  einmal beim Parsen — danach laufen alle Abfragen geradeaus.
- `coversDay(day)` spiegelt `DailyInfo.coversDay` — dieselbe Mechanik für
  „erscheint an jedem berührten Tag".
- `timeLabelForDay(day)` liefert schon die Anzeigelogik für Teil 2
  (`10:00–11:30`, bei mehrtägigen `ab 10:00` / `bis 11:30`, bei ganztägigen nichts).
- **Bewusst kein `JournalEntry`:** eigene Identität, von außen gepflegt, lokal
  nicht editierbar.

**2. Repo auf Schema-v5** (`lib/data/journal_repository.dart`)
- `_dbVersion` 4 → 5, `_onUpgrade` um eine Stufe ergänzt. Wie gehabt
  stufenweise ohne `else`; `_createCalendarEventTables` von `_onCreate` **und**
  `_onUpgrade` geteilt → kein Schema-Drift.
- `calendar_events`: **zusammengesetzter Primärschlüssel** (`calendar_id`,
  `event_id`) — dieselbe Einladung kann in mehreren aktivierten Kalendern
  liegen und wäre über die Event-ID allein nicht eindeutig. FK auf
  `calendar_sources` mit ON DELETE CASCADE. Index auf `start_day`.
- `event_tags`: materialisiert die vom Kalender geerbten Tags (PK
  `calendar_id` + `event_id` + `tag_key`, `ord`, zusammengesetzter FK mit
  CASCADE). Damit haben Einträge, Aufgaben und Termine **dieselbe Form der
  Tag-Abfrage**.
- Neue Methoden: `replaceCalendarEvents` (transaktional, löschen + neu
  schreiben), `deleteCalendarEventsFor`, `reapplyCalendarSourceTags`,
  `calendarEventsForDay` (Bereichsabfrage über *aktivierte* Kalender, ganztägig
  zuerst — die Grundlage der „TERMINE"-Sektion), `calendarEventsForTag`,
  `countCalendarEvents`.

**3. Sync-Engine** (`lib/services/google_calendar_service.dart`)
- `fetchEvents(calendarId, tags)`: `singleEvents=true`, `showDeleted=false`,
  `orderBy=startTime`, `maxResults=250`, Paginierung über `pageToken`
  (Notbremse bei 40 Seiten).
- Rollendes Fenster **−30 / +365 Tage**, gerechnet ab dem Sync-Zeitpunkt —
  so läuft die Zukunft nie aus.
- Robustes Parsen: abgesagte Termine, Einträge ohne ID oder ohne Startangabe
  werden übersprungen, statt den Sync zu kippen. Termine, die exakt um
  Mitternacht enden, werden dem Vortag zugeschlagen (sonst stünden sie einen
  Tag zu lang im Journal).
- Fehlermeldungen ziehen die Beschreibung aus Googles JSON-Body — statt einer
  nackten Statusnummer.

**4. „Termine jetzt synchronisieren"** (`calendar_settings_screen.dart`)
- Läuft Kalender für Kalender und schreibt jeden **einzeln** weg: Bricht einer
  ab, bleibt das bereits Gespiegelte erhalten und der betroffene Kalender wird
  namentlich gemeldet.
- Fortschritt am Button (laufender Kalendername), Ergebnismeldung mit
  Terminzahl und Fenstergröße, darunter eine Dauerzeile mit dem lokalen
  Bestand.
- Kalender **ausschalten** wirft dessen Termine sofort weg (nicht erst beim
  nächsten Sync). Tag-Änderung wird über `reapplyCalendarSourceTags` lokal
  nachgezogen, ohne erneuten Abruf.

### Architektur-Abweichung — `syncToken` entfällt

Das Architekturdokument sah Delta-Sync über `syncToken` mit Resync bei HTTP 410
vor. **Das ist mit dem Zeitfenster nicht kombinierbar:** Google akzeptiert
`timeMin`/`timeMax` zusammen mit `syncToken` nicht (HTTP 400). Es gilt entweder
Delta-Sync über den gesamten Kalender seit Anbeginn oder Vollabruf im Fenster.

**Entschieden: Vollabruf im rollenden Fenster, lokal vollständig ersetzen.**
Löschungen und Verschiebungen ergeben sich damit von selbst; es gibt keinen
Token-Zustand, der ablaufen und wieder eingefangen werden müsste. Für einen
persönlichen Kalender sind das wenige hundert Einträge pro Abruf —
*Verlässlichkeit vor Bastelei*. Die Spalte `sync_token` bleibt ungenutzt im
Schema stehen (keine Migration nötig, falls die Entscheidung je zurückgedreht
wird).

### Test auf dem MatePad — bestanden
- App startet nach der Migration v4→v5, bestehende Daten unberührt (kein
  Deinstallieren nötig).
- Kalender aktivieren, Tags zuordnen, Sync → Termine gespiegelt, Zähler stimmt.
- Kalender ausschalten → Zähler fällt sofort; wieder ein + Sync → Zahl zurück.
- **Zweiter Sync direkt hinterher → gleiche Zahl** (belegt „ersetzen statt
  anhängen", keine Dubletten).
- App-Neustart → Bestand steht (Persistenz).
- **Zusatztest von Steffen:** Termin im Google-Kalender neu angelegt → nach dem
  Sync ging der Zähler um genau eins hoch. Belegt den vollständigen Rundlauf,
  nicht nur den Erstabruf.

### Erkenntnis — die Terminzahl wirkt zu hoch
`singleEvents=true` löst Serientermine in **jedes einzelne Vorkommen** auf. Ein
wöchentlicher Termin zählt im +365-Fenster rund 52-mal. Die Gesamtzahl liegt
dadurch deutlich über dem, was man beim Blick in den Kalender im Kopf hat — das
ist korrekt und gewollt: Im Journal erscheint pro Tag genau ein Vorkommen, und
die App muss keine Wiederholungsregeln auswerten.

### Offene Punkte
- **Neu:** `use_null_aware_elements` in `google_calendar_service.dart`
  (`if (pageToken != null) 'pageToken': …` in der Query-Map → `?'pageToken':`).
- (bestehend) `Switch.activeColor` → `activeThumbColor`; `withOpacity` →
  `withValues()` repo-weit; `unnecessary_underscores`; Tag löschen; Smoke-Test;
  Java-8-Warnungen; PowerShell Execution Policy; `adb` nicht im PATH.
- Alle elf `flutter analyze`-Meldungen sind `info`, keine Fehler.

### Nächste Schritte
- **Coding-Session B, Teil 2:** Einblendung im Journal — „TERMINE"-Sektion pro
  Tag über `calendarEventsForDay`, Uhrzeit-Anzeige über `timeLabelForDay`,
  geerbte Tags sichtbar. Danach ist die Google-Calendar-Anbindung vollständig.
- Danach: **Claude-API** (Architektur-Session vor dem Coden).

### Anforderungsdokument
- *Google Calendar-Anbindung* bleibt 🟡 Core ⏳ — Auth, Kalenderauswahl,
  Tag-Mapping und Termin-Sync stehen; es fehlt die Einblendung.

### Commits (heute)
- `a5549a1` — feat: Termin-Sync und Schema v5 - Kalendertermine im rollenden
  Fenster gespiegelt (Session B, Teil 1)
- `docs:` — Fortschritt Session 21 (dieser Commit; zitiert `a5549a1`)
- Vorgänger: `c0414ed`

---

## Session 21 (Fortsetzung) — 22. Juli 2026

**Coding-Session B, Teil 2: die Einblendung.** Direkt im Anschluss an Teil 1 —
aus den 45 Minuten wurde eine lange Sitzung. Damit ist die
Google-Calendar-Anbindung funktional vollständig.

### Erledigt — Commit `6386e2c`

**1. TERMINE-Sektion im Journal** (`lib/screens/journal/journal_screen.dart`)
- Neue Akzentfarbe **Violett** (`_kEventAccent`) — vierte und letzte Farbe im
  Journal: Bernstein (Tagesinfo), Violett (Termine), Grün (Aufgaben), Blau
  (Einträge).
- `_EventsSection` + `_EventCard`: Zeit, Titel, optional Ort, geerbte Tags als
  Chips. **Bewusst nicht editierbar** — Termine gehören dem Kalender, nicht dem
  Journal. Kein Plus, kein Bearbeiten-Sheet; nur ein Zahnrad, das in die
  Kalender-Einstellungen führt.
- Zeitanzeige über `CalendarEvent.timeLabelForDay`: `10:00–11:30`, bei
  mehrtägigen am Randtag `ab 10:00` / `bis 11:30`, sonst `ganztägig`.
- **Sektion verschwindet vollständig, solange kein Kalender aktiviert ist** —
  wer Google Calendar nicht nutzt, sieht keinen leeren Kasten.
- `_openCalendarSettings` als eigene Methode: Nach der Rückkehr aus den
  Einstellungen werden Quellen **und** Termine neu geladen, ein dort
  ausgelöster Sync wirkt also sofort im Journal.
- Reihenfolge Tagesinfo → Termine → Aufgaben: erst der Rahmen des Tages, dann
  die festen Zeitpunkte, dann das Bewegliche. **Reversibel geflaggt** — reine
  Anordnungsfrage.

**2. Parser-Härtung** (`google_calendar_service.dart`)
- `_dateOnly` schneidet einen etwaigen Zeitanteil von `start.date`/`end.date`
  ab. Die API liefert dort ein reines `yyyy-MM-dd`; manche Darstellungen
  liefern einen vollen Zeitstempel. Für reine Datumsstrings wirkungslos,
  verhindert aber, dass so etwas je als Tages-Key in der DB landet.

**3. Lint-Aufräumung** — nur in ohnehin angefassten Dateien
- 4× `withOpacity` → `withValues(alpha:)` in `journal_screen.dart`
- `Switch.activeColor` → `activeThumbColor` in `calendar_settings_screen.dart`
- `task_overview_screen.dart` bewusst **nicht** angefasst.

### Fehlersuche: „ganztägige Termine erscheinen nicht"

Nach dem Einbau schien ein ganztägiger Testtermin nicht im Journal
aufzutauchen, obwohl der Zähler hochging.

**Vorgehen statt Raten:** Die SQL-Abfrage wurde gegen eine echte SQLite-DB mit
genau solchen Zeilen geprüft (fand alle drei Fälle korrekt), der Parser auf dem
Papier durchgerechnet. Da beides sauber war, kam ein **temporärer
Diagnose-Build** in den Sync-Dialog: geparste Gesamtzahl, davon ganztägig,
Treffer für heute, plus Probenzeilen mit `[start → end]`.

**Ergebnis:**
```
geparst gesamt: 42, davon ganztägig: 2
heute (2026-07-22): 1, davon ganztägig: 0
• Ganztägig 2 Tage [2026-07-27 → 2026-07-27]
• Ganztägig 1 Tag  [2026-07-27 → 2026-07-27]
```

Der Gegencheck über den Google-Calendar-Connector bestätigte es: Beide Termine
liegen im Kalender `steffen@harder-business.com` am **27. Juli**
(`start.date` 27., `end.date` 28. = eintägig), nicht am 22./23.
**Kein Fehler in Disponere** — der Ganztages-Pfad inklusive der Umrechnung des
exklusiven Enddatums arbeitet korrekt; beim Anlegen war das Datum verrutscht.
Der Diagnoseblock wurde anschließend wieder ausgebaut und ist nicht im Commit.

*Nebengewinn:* Der Ganztages-Pfad ist damit nicht mehr nur theoretisch,
sondern an echten Daten belegt.

### Prozess-Lektionen
- **Kein Fix auf Verdacht.** Erst frei prüfbare Teile isoliert testen
  (SQL gegen echte SQLite), dann ein Diagnose-Build, der die Hypothesen
  trennt — statt einen Build-Zyklus zu raten.
- **Lint-Fixes nur mit verifizierbarer Syntax.** Der freiwillig mitgenommene
  `use_null_aware_elements`-Fix wurde falsch geschrieben (`?'pageToken':` statt
  `'pageToken': ?…`) und hat den Build gebrochen. Ohne Dart-Compiler im
  Container wird Syntax nicht aus dem Kopf geändert; die Zeile wurde auf die
  bewährte `if (…)`-Form zurückgesetzt.
- **Der Google-Calendar-Connector ist ein brauchbares Debugging-Werkzeug**,
  wenn zu klären ist, was die API tatsächlich liefert.

### Offene Punkte
- (weiterhin) `use_null_aware_elements` in `google_calendar_service.dart` —
  korrekte Form ist `'pageToken': ?pageToken`, beim nächsten Build mitnehmen.
- (bestehend) 4× `withOpacity` in `task_overview_screen.dart`;
  `unnecessary_underscores` in `tag_management_screen.dart`; Tag löschen;
  Smoke-Test; Java-8-Warnungen; PowerShell Execution Policy; `adb` nicht im PATH.
- **Zeitzonen-Preis der lokalen Tages-Keys:** Ein Zeitzonenwechsel macht die
  gespeicherten Tage falsch. Korrektur ist ein Druck auf „Sync jetzt".

### Nächste Schritte
- **Claude-API** — Architektur-Session vor dem Coden (inkl. Tinten-Auswertung
  über die multimodale Bild-API).
- Danach ist für v1.0 nur noch die Theme-Entscheidung offen.

### Anforderungsdokument
- *Google Calendar-Anbindung* **🟡 Core ⏳ → ✅** — Auth, Kalenderauswahl,
  Tag-Mapping, Termin-Sync und Einblendung stehen. Nachzug im
  Anforderungsdokument steht noch aus.

### Commits (heute, Fortsetzung)
- `docs:` — Architektur nachgezogen (Vollabruf statt `syncToken`, Schema v5 wie
  gebaut, Session B geteilt)
- `6386e2c` — feat: TERMINE-Sektion im Journal - Kalendertermine mit Zeit, Ort
  und geerbten Tags (Session B, Teil 2)
- `docs:` — Fortschritt Session 21, Teil 2 (dieser Commit; zitiert `6386e2c`)
- Vorgänger: `3139d11`

---

## Session 22 — 23. Juli 2026

Reine Entscheidungs-Session, kein Code. Vier Festlegungen, die den Umfang von
v1.0 endgültig schließen — plus ein Termin, an dem sich ab jetzt alles misst.

### Der Termin

**Startklar am Freitag, 31. Juli 2026.** Danach zwei Wochen Urlaub (erste beide
Augustwochen), im Anschluss geht Disponere im Alltag live. Acht Tage ab heute.

*Wichtige Einordnung dazu:* Die App ist bereits jetzt einsatzfähig. Journal,
Tags, Tinten-Modus, Aufgaben, Tagesinfo und der Google-Calendar-Sync sind gebaut
und auf dem MatePad abgenommen. Der 31. ist kein Blocker, sondern ein Ziel — im
Zweifel wird der Rest nach dem Urlaub nachgezogen, statt etwas zu überstürzen.

### Entscheidung 1 — Wie aktiv ist Claude in Disponere?

Das war die eigentliche offene Frage. Im Anforderungsdokument stand seit jeher
der Satz *„Claude ist von Anfang an Teil der App"* — ohne dass je definiert
wurde, was „Teil" bedeutet. Unter „Offene Punkte" hieß es entsprechend
unbestimmt: *„Umfang und Einstiegspunkt der KI-Funktionen für v1.0 festlegen."*

**Entschieden: Disponere ist ein Werkzeug, kein Beobachter.**

- Claude spricht **nie ungefragt** ins Journal.
- Jede KI-Funktion wird vom Nutzer ausgelöst, jedes Ergebnis vom Nutzer gelesen
  und bewusst übernommen.
- Kein Hintergrundbetrieb, keine automatischen Aufrufe beim Speichern.

**Begründung:** Das Journal ist ein persönlicher Raum. Ungefragte Kommentare
werden dort schneller zu Rauschen als in einer Inbox — beim Zurücklesen liest
man sie jedes Mal wieder mit, und sie lassen sich nicht entfernen, ohne die
Einträge selbst anzufassen. Zudem stand das aktive Claude bereits im Dokument:
„Claude erkennt Terminverschiebung automatisch" ist dort 🟢 Enhancement der
Perlenkette und damit v2.0. Die Entscheidung bestätigt eine Linie, die implizit
längst gezogen war.

**Technische Ehrlichkeit, die dazugehört:** Das Claude in Disponere ist ein
API-Aufruf ohne Gedächtnis. Es kennt ausschließlich das, was die App in genau
diesem Request mitschickt — kein Projektwissen, keine Vorgeschichte. Was es
„weiß", entscheidet der Code. Präsenz ließe sich also ohnehin nur konstruieren,
nicht voraussetzen.

### Entscheidung 2 — Claude-Umfang für v1.0: zwei Knöpfe

1. **Tinten-Auswertung** — Handschrift-Eintrag antippen, Claude liest ihn über
   die multimodale Bild-API. Das Ergebnis wird gespeichert; damit wird Tinte
   nach einmaliger Auswertung **lokal durchsuchbar** — ein Umweg um den seit
   Juni offenen Punkt „lokale Tinten-Volltextsuche" (nicht on-device, aber
   einmal pro Eintrag).
2. **Wochenauswertung** — auf Knopfdruck in der App. Die Auswertung fließt als
   Start in die neue Woche. Als Prompt-Vorlage dienen die Plaud-Vorlagen
   (Abo vorhanden, kein Rad neu erfinden) — reine Prompt-Arbeit, kein Code.

**Nach v2.0 verschoben:** Tag-Vorschläge beim Speichern, Fragen an den eigenen
Wissensstand, automatisierte Wochenauswertung.

### Entscheidung 3 — Wochenauswertung bleibt in der App

Gewünscht war ursprünglich eine **automatisierte** Wochenauswertung: Bot auf der
IONOS-Linux-Maschine, Ergebnis als PDF per Mail.

**Verworfen für v1.0 — der Grund ist strukturell:** Das Journal liegt als
SQLite **lokal auf dem MatePad**. Ein Server hat darauf keinerlei Zugriff. Ein
Bot bräuchte daher zuerst Sync Gerät → Server — also genau das Cloud-Sync, das
laut Anforderungsdokument bewusst außerhalb von v1.0 liegt — dazu Server-Job,
PDF-Erzeugung, Mailversand und Schlüsselverwaltung auf dem Server. Zusammen mehr
Aufwand als die gesamte bisherige Claude-Integration, und es würde die
Grundentscheidung „Daten bleiben auf dem Gerät" durchlöchern.

Der Knopf in der App leistet dasselbe: Die Daten sind bereits da, ein Aufruf
genügt, das Ergebnis ist auf dem Tablet lesbar. Auch das aktive Lesen bleibt
erhalten — das entsteht nicht durch den Zustellweg.

**Der Automatisierungswunsch ist nicht gestrichen, sondern v2.0** — und dort an
Cloud-Sync gekoppelt.

### Entscheidung 4 — Theme: hell und dezent

**Entschieden: ein einziges helles Theme. Kein Dunkelmodus in v1.0.**

Vorlage ist Logseq auf dem MatePad (Screenshot vom 23.07.): fast weißer Grund,
fast schwarzer Text, eine einzige gedämpft-blaue Akzentfarbe ausschließlich für
Tags und Antippbares, Hierarchie über Größe und Gewicht statt über Farbe, keine
Karten mit Rahmen und Schatten — Trennung über Weißraum und feine Linien.

**Der bisherige Default (dunkel mit kühlen Blautönen) entfällt.** Er hatte einen
echten Konflikt mit dem Tinten-Modus: Handschrift ist dunkler Strich auf hellem
Grund; hell auf dunkel wirkt bei Handschrift wie Kreide auf Tafel, nie wie
Notizbuch. Die Entscheidung löst diesen seit Monaten mitlaufenden Punkt.

**Umsetzungsdetails:**
- Kein reines `#FFFFFF` / `#000000` — flimmert auf dem MatePad-Display.
- Tinte in dunklem Anthrazit, nicht Schwarz.
- **Konflikt im Anforderungsdokument:** Dort steht, die Tagesinfo sei „farblich
  abgesetzt". Das kollidiert mit dem Ein-Akzentfarben-Prinzip. Ersatz: leichte
  Grautönung des Blocks plus Beschriftung — gleiches Muster für TERMINE und
  AUFGABEN, damit sich alle drei Sektionen gleich verhalten.

Ein Dunkelmodus lässt sich jederzeit nachrüsten; ein Theme statt zwei ist bei
acht verbleibenden Tagen der spürbare Unterschied.

### Entscheidung 5 — Plaud ist ein Datenweg, kein KI-Weg

Plaud Note Pro liefert bereits ein **ausgewertetes** Dokument. Es erneut durch
die API zu schicken hieße, zweimal für dieselbe Arbeit zu zahlen und eine
Zusammenfassung der Zusammenfassung zu bekommen.

- Der Import bleibt reine Datenübernahme: Transkript rein, Journal-Eintrag
  daraus, Dateiname als Tag-Vorschlag — genau wie unter *Dokument-Import*
  beschrieben.
- **ToDos übernimmt der Nutzer selbst ins Journal.** Das ist kein Mangel, der
  später wegautomatisiert wird, sondern der Moment, in dem das Transkript
  tatsächlich gelesen und bewertet wird. Eine automatische Extraktion würde
  diesen Schritt überspringen und trotzdem eine prüfpflichtige Liste liefern.
- **Speicherort:** Entscheidend ist nicht, worauf Claude zugreifen kann, sondern
  was das MatePad erreicht. Disponere liest über den Android-Dateidialog aus
  einem **festen lokalen Ordner** (Downloads genügt; ein pCloud-Ordner geht
  ebenso, sofern dessen Android-App lokal synchronisiert). Der konkrete Ordner
  wird festgelegt, wenn der Import gebaut wird.
- Falls Plaud den Text direkt exportiert (nicht als gescanntes PDF), wird für
  diesen Weg **kein ML Kit** benötigt — der Import wäre dann deutlich schlichter
  als im Anforderungsdokument beschrieben. Zu prüfen, wenn es soweit ist.

*Dokument-Import* bleibt 🟢 Enhancement und damit außerhalb von v1.0. Sollte
Plaud zu einem regelmäßigen Weg ins Journal werden, wäre die Einstufung neu zu
bewerten — vorgemerkt, nicht entschieden.

### Restliste bis zum 31. Juli

1. **Architektur-Session Claude-API** → `docs:`-Commit (kein Code)
2. **Eine Coding-Session** — die zwei Knöpfe
3. **Theme umsetzen** — hell, dezent
4. **Anforderungsdokument nachziehen** — Google Calendar auf ✅, Theme-
   Entscheidung, Claude-Umfang, Tagesinfo-Formulierung
5. **Lint-Reste** — `use_null_aware_elements`, `withOpacity`, `unnecessary_underscores`

### Offene Punkte
- (neu) **Tagesinfo „farblich abgesetzt"** muss im Anforderungsdokument an das
  Ein-Akzentfarben-Prinzip angepasst werden.
- (neu) **Fester Plaud-Ordner** auf dem MatePad noch nicht bestimmt — erst
  relevant beim Dokument-Import.
- (weiterhin) `use_null_aware_elements` in `google_calendar_service.dart` —
  korrekte Form ist `'pageToken': ?pageToken`.
- (bestehend) 4× `withOpacity` in `task_overview_screen.dart`;
  `unnecessary_underscores` in `tag_management_screen.dart`; Tag löschen;
  Smoke-Test; Java-8-Warnungen; PowerShell Execution Policy; `adb` nicht im PATH;
  Zeitzonen-Preis der lokalen Tages-Keys.

### Nächste Schritte
- **Architektur-Session Claude-API.** Zu klären sind dort: API-Key-Ablage
  (`flutter_secure_storage`, Eingabe über einen Einstellungs-Screen — das Repo
  ist öffentlich, der Key darf nirgends im Code landen), Modellwahl und
  Token-Kosten, die Tinten-Pipeline (Striche → Offscreen-Render → PNG → base64,
  Auflösung als Abwägung zwischen Kosten und Erkennungsqualität), Persistenz des
  Erkennungsergebnisses (voraussichtlich **Schema v6**), Kontextumfang der
  Wochenauswertung, Einstiegspunkte in der UI und das Fehlerverhalten ohne Netz.

### Anforderungsdokument
- Kein Nachzug in dieser Session — gesammelt für den nächsten `docs:`-Commit:
  *Google Calendar-Anbindung* 🟡 Core ⏳ → ✅ (seit Session 21), Theme-
  Entscheidung, Claude-Umfang für v1.0, Tagesinfo-Formulierung.
- Der Punkt *„Claude-Integration — Umfang und Einstiegspunkt der KI-Funktionen
  für v1.0 festlegen"* kann aus der Liste der offenen Punkte gestrichen werden.

### Commits (heute)
- **Keine Code-Änderung (reine Entscheidungs-Session) → kein feat-Commit.**
- `docs:` — Fortschritt Session 22 (dieser Commit)
- Vorgänger: `6386e2c`

## Session 23 — 23. Juli 2026 (Architektur Claude-API)

**Architektur-Session.** Kein Code. Ergebnis ist das Dokument
`docs/disponere_architektur_claude_api_v1_0.md` (15 Abschnitte) und dieser
Fortschrittseintrag.

### Zwei Befunde aus dem frischen Clone

- **Die PNG-Pipeline aus den ML-Kit-Tagen existiert nicht mehr.**
  `_renderForOcr()` und das T-Icon sind mit der Umstellung auf Vektor-Tinte
  verschwunden. Kein Verlust: Damals wurde das *Widget* über `RepaintBoundary`
  abfotografiert; jetzt wird aus gespeicherten `InkData` gerendert, und das
  braucht ohnehin einen anderen Weg (`PictureRecorder`) — der Eintrag soll
  auswertbar sein, ohne dass sein Editor offen ist.
- **Disponere hat keine Suche.** Kein `LIKE`, kein Suchfeld, nichts; im
  Anforderungsdokument taucht Suche auch nicht als Punkt mit Priorität auf,
  nur als Eigenschaft („durchsuchbar") und als offener Punkt „lokale
  Tinten-Volltextsuche ungelöst". Der Satz aus Session 22 — *„damit wird Tinte
  lokal durchsuchbar"* — stimmte damit nur zur Hälfte: Die Auswertung macht
  Tinte **text-tragend**, auffindbar ist sie deswegen noch lange nicht.
  Konsequenz siehe Entscheidung 8.

### Getroffene Entscheidungen

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Schlüssel-Ablage | `flutter_secure_storage` (Keystore), Eingabe über Einstellungs-Screen |
| 2 | Direktaufruf | Gerät ruft `api.anthropic.com` unmittelbar, kein Proxy |
| 3 | Modell | `claude-sonnet-5`, **eine Konstante** im Service, nicht konfigurierbar |
| 4 | Bildaufbereitung | Offscreen-Render aus `InkData`, **schwarz auf weiß**, lange Kante ≤ 1568 px |
| 5 | Ergebnis-Ablage | **Schema v6** — `ink_text` / `ink_text_at` auf `entries`, **nicht** in `content` |
| 6 | Landeplatz Wochenauswertung | Erst Anzeige, dann Übernahme per Knopf als Eintrag `#Wochenauswertung` |
| 7 | Zeitfenster | Kalenderwoche Mo–So; **ab Freitag 12:00 die laufende**, davor die vorige; dazu Wochenpfeile |
| 8 | Suche | **Minimal-Suche in v1.0** über `content` und `ink_text`, Filterung **in Dart** |

### Begründungen, die tragen

- **`ink_text` statt `content`.** `content` ist, was der Nutzer geschrieben hat;
  `ink_text`, was die Maschine geraten hat. Diese Grenze zu verwischen wäre in
  einem Journal die falsche Sparsamkeit — beim Zurücklesen in zwei Jahren will
  man wissen, welches von beidem vor einem liegt. Der Zeitstempel macht
  „erneut auswerten" sauber möglich.
- **Die Umlaut-Falle in der Suche.** SQLites `LIKE` und `LOWER()` sind
  **ASCII-only**: `LOWER(content) LIKE '%über%'` findet „Über" **nicht**. Bei
  deutschen Texten ist das der Normalfall, kein Randfall. Das Projekt löst das
  an anderer Stelle bereits richtig — `tag_key` wird in **Dart** mit
  `toLowerCase()` normalisiert. Die Suche folgt demselben Weg: Kandidaten laden
  (nur vier Spalten, keine Tinte), in Dart filtern. Bei einigen tausend
  Einträgen unproblematisch; der Ausbauweg wäre eine mitgeführte, normalisierte
  Suchspalte — vorgemerkt, nicht gebaut.
- **Freitag 12:00 als Schwelle.** Erste Fassung war „letzte abgeschlossene
  Woche" — im Gespräch verworfen, weil die alte Woche dann erst am Montag
  auswertbar gewesen wäre. Am Freitagmittag ist die Arbeitswoche faktisch
  gelaufen. Wer erst am Montag auswertet, bekommt dieselbe Woche, nur
  vollständig inklusive Wochenende.
- **Wochenpfeile statt Datumsauswahl.** Nach dem Urlaub fehlen zwei Wochen, die
  automatische Regel kennt nur eine. Das Fenster wird ohnehin berechnet — der
  Pfeil zieht einen Wert ab. Vorwärts gedeckelt bei der vorgeschlagenen Woche.
  Der Kopf zeigt KW und Datumsspanne, sonst weiß man nach dem Blättern nicht
  mehr, wo man ist.
- **Ein Bild pro Eintrag.** Der Zeichenbereich ist `Expanded` +
  `SizedBox.expand()`, also fest und nicht scrollbar. Keine Mehrseitigkeit,
  kein Zusammensetzen von Teilbildern.
- **Strichbreite mit Untergrenze 2 px.** Zu dünne Striche nach dem Verkleinern
  sind der eigentliche Erkennungskiller — deutlich eher als eine zu geringe
  Auflösung.
- **Kein Zustand nach Fehlschlag.** Keine halb ausgewerteten Einträge, keine
  leeren `ink_text`-Spalten, keine Wiederaufnahme-Logik. Der zweite Versuch
  beginnt bei null.

### Technisch bestätigt

- **Kein neues Paket nötig.** `http` und `flutter_secure_storage` liegen bereits
  im Projekt; letzteres hält schon die Google-Tokens.
- **Kein GMS-Bezug.** Reines HTTPS gegen `api.anthropic.com`, kein SDK.

### Umfang ist gewachsen

Mit der Suche kommt ein Feature dazu, das im Anforderungsdokument bisher gar
nicht als Punkt geführt wird. Die Coding-Session teilt sich deshalb in zwei
Teile. Wenn es eng wird, ist **Teil 2 der Kandidat zum Verschieben, nicht
Teil 1**: Schema v6 ohne Suche ist ein sauberer Zwischenstand, Suche ohne
erkannten Text wäre sinnlos.

- **Coding-Session C, Teil 1** — Einstellungs-Screen, `claude_service.dart`,
  `ink_renderer.dart`, Schema v6, Tinten-Auswertung mit Vorschau
- **Coding-Session C, Teil 2** — Wochenauswertung (Fensterlogik, Pfeile,
  Übernahme) und Minimal-Suche

### Restliste bis zum 31. Juli

1. ~~Architektur-Session Claude-API~~ ✅ (diese Session)
2. **Coding-Session C, Teil 1** — Tinte
3. **Coding-Session C, Teil 2** — Wochenauswertung + Suche
4. **Theme umsetzen** — hell, dezent
5. **Anforderungsdokument nachziehen** — Google Calendar auf ✅, Theme-
   Entscheidung, Claude-Umfang, **Suche als neuer Punkt**, Tagesinfo-Formulierung
6. **Lint-Reste** — `use_null_aware_elements`, `withOpacity`, `unnecessary_underscores`

### Offene Punkte
- (neu) **Modell-ID und aktuelle Preise** gegen die Dokumentation abgleichen,
  bevor die Konstante festgeschrieben wird.
- (neu) **Skalierungswert 1568 px** an echter Handschrift gegenprüfen. Wenn die
  Erkennung enttäuscht: erst Strichbreite, dann Auflösung.
- (neu) **Suche gehört ins Anforderungsdokument** — sie ist dort bisher kein
  Feature mit Priorität.
- (weiterhin) Tagesinfo „farblich abgesetzt" an das Ein-Akzentfarben-Prinzip
  anpassen; fester Plaud-Ordner auf dem MatePad.
- (weiterhin) `use_null_aware_elements` in `google_calendar_service.dart` —
  korrekte Form ist `'pageToken': ?pageToken`.
- (bestehend) 4× `withOpacity` in `task_overview_screen.dart`;
  `unnecessary_underscores` in `tag_management_screen.dart`; Tag löschen;
  Smoke-Test; Java-8-Warnungen; PowerShell Execution Policy; `adb` nicht im PATH;
  Zeitzonen-Preis der lokalen Tages-Keys.

### Nächste Schritte
- **Coding-Session C, Teil 1.** Schlüssel eintragen, Tinten-Eintrag auswerten,
  Text erscheint — das ist das Testkriterium auf dem MatePad.

### Anforderungsdokument
- Weiterhin kein Nachzug. Gesammelt für den nächsten `docs:`-Commit:
  *Google Calendar-Anbindung* 🟡 Core ⏳ → ✅, Theme-Entscheidung, Claude-Umfang
  für v1.0, **Suche als neuer 🟡-Punkt**, Tagesinfo-Formulierung.

### Commits (heute, Teil II)
- **Keine Code-Änderung (Architektur-Session) → kein feat-Commit.**
- `docs:` — Architektur Claude-API (`6218f3a`)
- `docs:` — Fortschritt Session 23 (dieser Commit)
- Code-Vorgänger unverändert: `6386e2c`


## Session 24 — 23. Juli 2026 (Teil III)

### Charakter der Session
- **Coding-Session C, Teil 1** aus dem Architekturdokument §13: Schlüssel, Service,
  Renderer, Schema v6, Auswerten-Symbol im Tinten-Editor.
- Besonderheit dieser Session: Der Arbeitsstand lag zu Sitzungsbeginn bereits als
  **nicht committete Änderung im Arbeitsverzeichnis** vor — offenbar aus einem
  abgebrochenen Anlauf. Statt ihn blind zu übernehmen oder wegzuwerfen, wurde er
  vollständig gegen das Architekturdokument geprüft (§7 Ablauf, §10 Secrets,
  §11 Fehlerverhalten) und an einer Stelle korrigiert.
- Der Ritual-Schritt „frischer `git clone`" hat dabei genau das geleistet, wofür er
  gedacht ist: Er hat den Unterschied zwischen *committet* und *vorgefunden* sofort
  sichtbar gemacht.

### Erledigt — Claude-Anbindung Teil 1 (🟡 Core), Commit `6fe8ff3`

**1. Schlüsselverwaltung** (`lib/screens/settings/claude_settings_screen.dart`, neu)
- Eintragen, ersetzen, löschen, Verbindung testen. Verdecktes Feld mit Auge-Umschalter,
  auf Einfügen aus der Zwischenablage ausgelegt.
- Der Schlüssel wird nach dem Speichern **sofort aus dem Eingabefeld gelöscht** — er
  muss nicht länger auf dem Bildschirm stehen als nötig.
- Einstieg über ein Funkel-Symbol in der Journal-Kopfzeile, neben dem Kalender-Symbol.

**2. API-Service** (`lib/services/claude_service.dart`, neu)
- Direktaufruf gegen `api.anthropic.com/v1/messages`, Schlüssel aus
  `flutter_secure_storage` (Android Keystore). Kein neues Paket nötig.
- Fehlerarten als `enum ClaudeErrorKind` (`noKey`, `auth`, `rateLimit`, `network`,
  `server`, `response`), damit die UI mehr kann als eine Meldung anzeigen — bei
  `auth` und `noKey` führt der Dialog direkt in die Einstellungen.
- Antwort wird über `response.bodyBytes` als UTF-8 dekodiert. Ohne das legt `http`
  bei fehlendem `charset` Latin-1 zugrunde — aus „Frühstück" würde Buchstabensalat.
- Der Schlüssel taucht in **keiner** Fehlermeldung auf, auch nicht in Auszügen.

**3. Tinten-Renderer** (`lib/utils/ink_renderer.dart`, neu)
- `InkData` → `PictureRecorder` → PNG → base64. Kein Widget, keine `RepaintBoundary`.
- Schwarz auf Weiß, unabhängig vom App-Theme; Strichbreite skaliert mit, Untergrenze 2 px.

**4. Schema v6** (`journal_repository.dart`, `journal_entry.dart`)
- `entries.ink_text` + `entries.ink_text_at` via `_addInkTextColumns`, in `_onCreate`
  **und** `_onUpgrade` — Neuinstallation und Migration erzeugen dasselbe Schema.
- `setInkText()` als gezieltes `UPDATE`; gibt den Zeitstempel zurück, damit die UI ihn
  ohne Neuladen anzeigen kann.

**5. Auswertung im Tinten-Editor** (`drawing_screen.dart`)
- Auswerten-Symbol in der Kopfzeile → Ladeanzeige → Vorschau mit „Übernehmen" und
  „Verwerfen". Bei „Verwerfen" wird nichts geschrieben.
- Übernommener Text erscheint als einklappbares Feld „ERKANNTER TEXT" mit Zeitstempel.
- Der Editor schreibt **nicht** selbst in die Datenbank — Persistenz liegt beim Aufrufer
  über einen Callback, derselbe Schnitt wie beim Aufgaben-Sheet.

### Der Fehler, der beinahe drin geblieben wäre

`ConflictAlgorithm.replace` in `_upsertInTxn` schreibt die **ganze** Zeile neu. Wären
`ink_text` und `ink_text_at` dort nicht mitgeführt worden, hätte **jedes Nachbearbeiten
eines Tinten-Eintrags die Auswertung stillschweigend gelöscht** — ohne Fehlermeldung,
ohne sichtbare Ursache, erst Wochen später bemerkbar. Die Kette
`setInkText` → `_entries[index]` → `_updateInkEntry` wurde deshalb durchverfolgt; sie hält.

Daraus der Testschritt, der in die Abnahmeliste gehört: *Strich dazuschreiben, speichern,
Eintrag erneut öffnen — der erkannte Text muss noch da sein.*

### Geprüft gegen die Dokumentation (Architektur §15)
- **Modell-ID `claude-sonnet-5`** bestätigt (1M Kontext, 128k max output, Vision).
- **Preis** $2/$10 je Mio. Token als Einführungspreis bis 31.08.2026, danach $3/$15.
  Ein Tinten-PNG bei 1568 px liegt bei rund 2.000–2.500 Input-Token — **unter einem
  halben Cent je Auswertung**. Der Skalierungswert bleibt unverändert.
- **`thinking: {'type': 'disabled'}` ist für Sonnet 5 gültig und wichtig.** Sonnet 5
  unterstützt nur adaptives Thinking, hat es **standardmäßig an** und weist `"enabled"`
  mit 400 zurück; `"disabled"` wird akzeptiert. Ohne diese Zeile käme zu jeder
  Transkription ungefragt Thinking-Aufwand dazu.

### Korrektur gegenüber dem vorgefundenen Stand
- Im Editor eines **neuen** Eintrags war das Auswerten-Symbol sichtbar, warf beim Tippen
  aber eine Absage („erst übernehmen"). Ein Knopf, der da ist und nein sagt, ist
  schlechter als kein Knopf → Symbol erscheint jetzt nur bei bestehenden Einträgen.
  Die Absage bleibt als Absicherung im Code.

### Abweichungen vom Architekturdokument (§6, nachgezogen statt zurückgebaut)
1. **Zuschnitt auf die tatsächlich beschriebene Fläche** statt auf den vollen
   Zeichenbereich. Fünf Zeilen am oberen Rand ergäben sonst ein halb leeres Bild, auf
   dem die Schrift nur einen Bruchteil der Auflösung hätte.
2. **Mindestgröße 768 px** an der langen Kante. §6 sagt „nur hochskalieren, wenn nötig" —
   bei Vektorstrichen ist Hochskalieren verlustfrei und kostet nur wenige Token.

### Testergebnis auf dem MatePad (teilweise)
- ✅ App startet, **Schema-v6-Migration hat die vorhandenen Einträge überlebt**
- ✅ Funkel-Symbol öffnet die Claude-Einstellungen
- ✅ Tinten-Eintrag: im Neu-Modus kein Auswerten-Symbol, nach dem Übernehmen ist es da
- ⏳ Transkription selbst **nicht abgenommen** — siehe Blocker

### Blocker (nicht im Code)
- Die **Organisation in der Anthropic Console ist gesperrt** („Cannot purchase credits
  for a banned organization"). Ohne Guthaben kein Schlüssel und kein Aufruf.
  **Einspruch ist eingereicht.** Der Code ist geprüft; es fehlt allein der Zugang.
- Folge für den Plan: Die Abnahme von Teil 1 (Erkennung sichtbar) steht aus. Teil 2
  (Wochenauswertung, Suche) ist davon **nicht** blockiert — die Suche funktioniert
  offline, und die Wochenauswertung lässt sich bis zum Aufruf hin bauen.

### Offene Punkte
- (neu) **Stellhebel, falls die Erkennung enttäuscht** — in dieser Reihenfolge:
  Strichbreite, Auflösung, und als dritter das **Wiedereinschalten von Thinking**
  (die Zeile `body['thinking']` weglassen). Kontext hilft beim Entziffern schwieriger
  Handschrift.
- (neu) `stop_reason: max_tokens` wird nicht gesondert behandelt — bei sehr langer
  Handschrift käme ein abgeschnittener Text ohne Warnung zurück. Bei 4096 Token
  theoretisch; falls es je auftritt, ist es hier notiert.
- (weiterhin) Skalierungswert 1568 px an echter Handschrift gegenprüfen.
- (weiterhin) **Suche gehört ins Anforderungsdokument** als eigener 🟡-Punkt.
- (weiterhin) Tagesinfo „farblich abgesetzt" an das Ein-Akzentfarben-Prinzip anpassen;
  fester Plaud-Ordner auf dem MatePad; Theme-Umsetzung (hell) steht noch aus — die neuen
  Screens sind vorläufig im bestehenden dunklen Stil gehalten.
- (weiterhin) `use_null_aware_elements` in `google_calendar_service.dart`.
- (bestehend) 4× `withOpacity` in `task_overview_screen.dart`;
  `unnecessary_underscores` in `tag_management_screen.dart`; Tag löschen; Smoke-Test;
  Java-8-Warnungen; PowerShell Execution Policy; `adb` nicht im PATH.

### Nächste Schritte
- **Sobald der Zugang steht:** Teil 1 abnehmen — Schlüssel eintragen, Tinten-Eintrag
  auswerten, Text erscheint. Dazu der Nachbearbeitungs-Test aus dem Abschnitt oben.
- **Coding-Session C, Teil 2:** Wochenauswertung (Kontext einer KW, Fensterlogik ab
  Freitag 12:00, Wochenpfeile) und lokale Suche über `content` + `ink_text`.

### Anforderungsdokument
- Weiterhin kein Nachzug. Gesammelt für den nächsten `docs:`-Commit:
  *Google Calendar-Anbindung* 🟡 Core ⏳ → ✅, Theme-Entscheidung, Claude-Umfang für
  v1.0, **Suche als neuer 🟡-Punkt**, Tagesinfo-Formulierung.

### Commits (heute, Teil III)
- `6fe8ff3` — feat: Claude-Anbindung Teil 1 (Schlüssel, Renderer, Schema v6, Auswertung)
- `docs:` — Fortschritt Session 24 + Architektur §6/§15 nachgezogen (dieser Commit)
- Vorgänger: `3ad9277`

---

---

*Wird nach jeder Session aktualisiert.*
