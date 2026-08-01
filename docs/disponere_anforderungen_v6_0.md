# Disponere
### Strukturiertes Denken und Notieren
*Anforderungsdokument — Version 6.0*
*Stand: 01. August 2026 (Nachtrag Teilen & Bilder)*

---

## Was sich gegenüber Version 5.0 geändert hat

Zwei Nachträge, beide am 01. August 2026:

- **Ideen-Erfassung über zwei Meta-Tags in Disponere selbst.** `#Disponere-Versio`
  sammelt Ideen/Anforderungen, die zügig — möglichst in der aktuellen Version — integriert
  werden sollen; `#Disponere-Visio` sammelt Feature-Ideen für künftige Versionen. Die Inhalte
  beider Tags werden regelmäßig in dieses Claude-Projekt gespiegelt. Damit dokumentiert
  Disponere seine eigene Weiterentwicklung — dieselbe Versio-/Visio-Trennung, die das
  Anforderungsdokument zwischen „v1.0" und „v2-Ausblick" zieht, nur als lebende Einträge.
- **Neuer Feature-Block „Teilen & Bilder" (`#Disponere-Versio`, absolute Priorität).** Drei
  zusammenhängende Anforderungen: Bilder in Disponere ablegen · Disponere als Empfangsziel im
  System-Teilen-Dialog (Geteiltes landet im Journal des aktuellen Tages) · aus Disponere heraus
  teilen. Alles **reines AOSP-Android, GMS-frei** — funktioniert auf dem HMS-MatePad ohne
  Google-Dienst. **Architektur-Entscheidung:** der Empfangsweg läuft über ein **natives
  MethodChannel** in `MainActivity`, nicht über das Plugin `receive_sharing_intent` (robuster
  auf HMS, in derselben Werkzeuglinie wie FreeScript-PlatformView und AppAuth). Bilder als
  Eintragsinhalt erfordern **Schema-Migration v6 → v7**.

---

## Was sich gegenüber Version 4.0 geändert hat

Version 4.0 stand nach Session 27 und war ein großer Sammel-Nachzug. Seither (Sessions 28–40)
sind die beiden letzten offenen 🟡-Core-Punkte gefallen — **Theme** und **Claude-Anbindung** —
und das Journal-Layout wurde auf Design v2.0 umgestellt. **Disponere ist damit funktional
vollständig für v1.0.** Die Änderungen im Einzelnen:

- **Theme (hell) umgesetzt** — von „entschieden, Umsetzung offen" auf ✅. Über **alle**
  Screens ausgerollt (Journal in Session 29, die übrigen fünf Screens in Session 39). Es war
  der zuletzt verbliebene 🟡-Core-Funktionspunkt für v1.0.
- **Anthropic-Konto wieder frei / API läuft** — der wochenlange Blocker (Organisation durch
  automatische Safeguards gesperrt) ist aufgehoben, Guthaben in der Console bestätigt
  (Session 37/38). Der Zugang steht von 🟡 Core ⏳ auf ✅.
- **Claude-Anbindung abgenommen (Session 38)** — Tinten-Auswertung, Wochenauswertung und
  Suche wurden erstmals gegen die laufende API auf dem MatePad abgenommen. Transkription auf
  Anhieb makellos (inkl. Umlauten), Wochenauswertung ohne Halluzination. Die „Abnahme steht
  aus"-Vorbehalte aus v4.0 entfallen.
- **Journal-Layout auf Design v2.0** — heutige **Termine und Aufgaben** wandern in ein
  seitliches **Heute-Panel** (Overlay, Session 33); die Heute-Spalte ist freie Schreibfläche
  (Datumskopf, Tagesinfo-Band, eigene Einträge). Vergangene Tage werden nach **`#Tag`
  gruppiert** (Session 35); Tagesinfo erscheint als **`Wrap`-Band** (drei nebeneinander,
  Session 36). Zwei kleine Layout-Bugs gefixt (Session 37). Die alte Sektionsreihenfolge
  TAGESINFO → TERMINE → AUFGABEN → Einträge lebt weiter in der Tag-Ansicht.
- **Neuer Screen: Tag-Ansicht (Session 31)** — „alles zu einem Tag über alle Tage" als reine
  Lese-Ansicht, über antippbare `#Tag`-Chips erreichbar. Die Realisierung des Prinzips
  „Tag-Seite = gefilterte Sicht" aus Kernkonzept 1.

---

## Vision

Disponere ist eine Android-App für das Huawei MatePad Pro. Herzstück ist das handschriftliche
Notieren mit dem M-Pencil. Gedanken werden nicht nur festgehalten, sondern durch Tags
strukturiert und miteinander verknüpft — über ein einziges, durchgehendes Journal.

Disponere ist Open Source — gebaut für einen Nutzer, offen für alle. Und ein Beispiel
sinnvoller Mensch-KI-Zusammenarbeit: Claude ist von Anfang an Teil der App.

---

## Ideen-Erfassung: `#Disponere-Versio` / `#Disponere-Visio`

Disponere dokumentiert seine eigene Weiterentwicklung mit zwei Meta-Tags in der App selbst:

- **`#Disponere-Versio`** — Ideen und Anforderungen, die **zügig, möglichst in der aktuellen
  Version** integriert werden sollen.
- **`#Disponere-Visio`** — Feature-Ideen für **künftige Versionen**.

Die Inhalte beider Tags werden regelmäßig in das Claude-Projekt gespiegelt und von dort ins
Anforderungsdokument überführt (Versio → v1.0-Abschnitte, Visio → v2-Ausblick). So ist die
Ideen-Pipeline dieselbe Perlenkette wie der Rest der App: getaggte Einträge, die an der
richtigen Stelle auftauchen.

---

## Zielgerät

| Eigenschaft | Wert |
|---|---|
| Gerät | Huawei MatePad Pro (MRDI-W09) |
| System | Android 12 / EMUI (HMS Core, kein Google) |
| Eingabe | Huawei M-Pencil (Stift erste Priorität) + Tastatur |
| Handschrift-Engine | Huawei FreeScript — systemweit, on-device, offline, Google-frei |

---

## Technologie

| Entscheidung | Wahl | Begründung / Status |
|---|---|---|
| Framework | Flutter | Eine Codebasis, gute Stylus-Unterstützung |
| Handschrift → Text | FreeScript via natives `EditText` (PlatformView, Hybrid Composition) | On-device, offline; Flutters Scribe-Weg auf dem MatePad nicht nutzbar ✅ |
| Handschrift → Tinte | Canvas, Speicherung als Strichdaten (Vektoren) | Bleibt editierbar; PNG nur als Render-Version für die Auswertung ✅ |
| OCR gedruckter Text | Huawei ML Kit | Nur für Dokument-Import; kann **keine** Handschrift |
| Persistenz | lokal: **SQLite** (`sqflite`), Schema v6 | Migration vollzogen; abfragbar nach Datum / Tag / Zeitraum ✅ |
| Kalender | Google Calendar API, **read-only**, OAuth via `flutter_appauth` (PKCE) | Kein GMS nötig; Token im Android Keystore ✅ |
| KI-Integration | Claude (Anthropic API), Modell `claude-sonnet-5`, Direktaufruf ohne Proxy | Zwei nutzerausgelöste Funktionen ✅, gegen die laufende API abgenommen (Session 38) |
| Theme | ein helles Theme, eine Akzentfarbe | Umgesetzt, über alle Screens ausgerollt ✅ |
| Lizenz | Open Source | GitHub, frei zugänglich |

**Pakete:** `sqflite`, `path`, `path_provider`, `flutter_secure_storage`, `flutter_appauth`, `http`.

---

## Kernkonzepte

### 1. Ein Journal, Tags als Sicht ✅
- Es gibt **ein** durchgehendes Journal (Tageszeitachse). Kein Datei-pro-Tag, kein Journal-pro-Projekt.
- „Projekte" (z.B. Wasser, Wärme, MBS) sind **Tags**, keine eigenen Journale.
- Eine **Tag-Seite ist eine gefilterte Sicht** über das eine Journal; ein **„Tag" (Datum) ist eine
  Abfrage**, keine Datei. Realisiert als **Tag-Ansicht** (eigener Screen, siehe Funktionen):
  alles zu einem `#Tag` über alle Tage, per Chip-Tap erreichbar. ✅
- Die lokale DB ist nach Datum / Tag / Zeitraum abfragbar. Einträge, Aufgaben und Termine haben
  **dieselbe Form der Tag-Abfrage** (normalisierte Verknüpfungstabellen mit `tag_key`).

### 2. Daily Journal ✅
- Beim ersten Start eines Tages wird automatisch eine neue Journal-Sicht angelegt.
- Das Journal ist die zentrale Arbeitsfläche; jeder Eintrag trägt Datum und Uhrzeit. ✅
- **Heute = freie Schreibfläche.** Der heutige Block zeigt Datumskopf, Tagesinfo-Band und die
  eigenen Einträge — sonst nichts, was von der Schreibfläche ablenkt.
- **Heute-Panel (seitliches Overlay):** heutige **Termine** und **Aufgaben** liegen in einer
  von rechts einblendbaren Schublade, nicht mehr in der Journal-Spalte. Aufgaben sind dort
  direkt abhakbar; ein Badge zählt heutige Termine + offene Aufgaben. *(Design v2.0 §4a/§5.)*
- **Google Calendar:** Termine erscheinen automatisch als vor-getaggte Einträge mit Zeit —
  heute im Heute-Panel, an vergangenen Tagen im jeweiligen Tagesblock. ✅
- **Aufgaben** mit Fälligkeit heute erscheinen im Heute-Panel; an ihrem Fälligkeitstag in der
  Vergangenheit im jeweiligen Tagesblock. ✅
- **Vergangene Tage nach `#Tag` gruppiert:** je Tag ein Datumskopf, tag-lose Notizen oben,
  darunter ein Cluster pro `#Tag` (nach erster Uhrzeit sortiert, neu nach alt). Ein Eintrag
  mit mehreren Tags erscheint unter jedem — Mehrfach-Auftauchen ist der Normalfall.
  *(Design v2.0 §4b.)*
- **Alte Sektionsreihenfolge** TAGESINFO → TERMINE → AUFGABEN → Einträge gilt nicht mehr im
  Journal, wohl aber weiter innerhalb eines Tages in der **Tag-Ansicht** (siehe Kernkonzept 1
  und Funktionen).

### 3. Tag-System ✅
- **Mehrfach-Tags pro Eintrag**, `#`-getrennt (`#MBS #ValSys #Vertrag`). Ein Tag = ein Wort. ✅
- Tags können nachträglich hinzugefügt / entfernt werden (über Editierbarkeit). ✅
- **Tag-Register mit Normalisierung:** Schreibvarianten werden case-insensitiv zusammengeführt
  (`ValSys` = `valsys` → ein Tag). Kanonische Schreibweise = **case-preserving, „erste
  Schreibweise gewinnt"** (Akronyme / deutsche Substantive bleiben lesbar). ✅
- **Autocomplete:** Vorschlags-Chips zum getippten Fragment; bei keinem Treffer Fuzzy-Vorschlag
  „Meintest du …?" (Levenshtein). An beiden Eingabewegen. ✅
- **Tag-Verwaltung / Umbenennen:** Durchschreiben über alle Einträge, case-insensitiver Merge,
  Nutzungszähler — der Hebel gegen die reihenfolge-abhängige Kanonisierung. ✅

### 4. Zwei Eingabe-Modi ✅
- **Text-Modus:** Stift (FreeScript) **oder** Tastatur → gespeichert als **Text** → durchsuchbar,
  von Claude lesbar. ✅
- **Tinten-Modus:** Canvas → gespeichert als **Strichdaten (Vektoren)**, **keine** Umwandlung →
  bleibt Handschrift, editier- und weiterschreibbar. Tinten-Editor mit Weiterschreiben, Radierer,
  Orientierungs-Fit. ✅
- Begründung Strichdaten statt PNG: „Editierbarkeit" ist 🟡 Core — ein nicht weiterbearbeitbarer
  Tinten-Eintrag würde das brechen. Ein PNG entsteht nur **flüchtig** als Render-Version für die
  Claude-Auswertung und wird nicht gespeichert.

### 5. Daily Info (Tagesinfo) ✅
- Eigenes Band oben im Tagesblock, durch **leichte Grautönung und Beschriftung** abgehoben —
  nicht durch eine eigene Farbe.
  *(Ersetzt die Formulierung „farblich abgesetzt" aus v3.0; sie kollidierte mit dem
  Ein-Akzentfarben-Prinzip des entschiedenen Themes.)*
- **Darstellung als `Wrap`:** die Tagesinfo-Karten stehen **nebeneinander**, drei pro Zeile,
  ab der vierten Umbruch — heute wie an vergangenen Tagen dasselbe Widget. *(Design v2.0,
  Session 36.)*
- Zeigt menschlichen Kontext für den Tag (was ist heute bei Menschen im Umfeld los).
- Freier Text, ein Eintrag pro Zeile; je Eintrag ein Datum oder eine Zeitspanne (von/bis).
- Erscheint automatisch im Journal aller betroffenen Tage.
- Klar getrennt von Aufgaben und Kalenderterminen.

### 6. Aufgaben ✅
- Jederzeit erstellbar; Datum und Uhrzeit optional.
- Am Fälligkeitstag automatisch im Journal; klar unterscheidbar von Kalenderterminen.
- Eigener Aufgaben-Übersicht-Screen; Aufgaben sind tag-abfragbar wie Einträge.

### 7. Suche ✅ *(neu gegenüber v3.0)*
- Volltext über `content` **und** `ink_text` — also auch über den von Claude erkannten
  Handschrift-Text. Ohne sie wäre der erkannte Text gespeichert, aber unauffindbar.
- **Läuft offline** gegen die lokale DB; keine Netz- und keine API-Abhängigkeit.
- Gefiltert wird **in Dart, nicht in SQL**: SQLites `LIKE` und `LOWER()` sind ASCII-only —
  `LOWER('Über')` bleibt `Über`. Bei deutschen Texten ist das kein Randfall.
- Trefferkarte mit Datum, Uhrzeit und einem Ausschnitt **um die Fundstelle**; Tinten-Treffer
  sind als „erkannter Text" markiert. Ein Treffer öffnet den Eintrag.
- Ab zwei Zeichen, 250 ms Verzögerung. Suche über Aufgaben, Tagesinfo und Termine ist 🟢.

### 8. Wochenauswertung ✅ *(neu gegenüber v3.0)*
- Fasst eine **Kalenderwoche (Mo–So)** aus Einträgen, Aufgaben, Tagesinfos und Terminen zusammen
  und schickt sie als Kontext an Claude.
- **Zeitfenster:** ab **Freitag 12:00** die laufende Woche, davor die vorige. Dazu Pfeile zum
  wochenweisen Blättern. Bei laufender Woche endet das Fenster **heute** — Samstag und Sonntag
  sind noch nicht passiert.
- **Gliederung des Ergebnisses:** Zusammenfassung · Woran es hakte · Aufgaben (`[x]` / `[ ]`,
  erledigte zuerst) · Vorschläge (nummeriert, höchstens vier).
- **Harte Regel:** Ergänze nichts, was nicht im Material steht. Ergibt sich nichts Konkretes,
  steht genau das da — statt vier ausgedachter Ratschläge.
- Landeplatz: erst Anzeige-Screen, dann **Übernahme per Knopf** als Eintrag mit `#Wochenauswertung`.
- **Mindmap-Darstellung** der sechs festen Überschriften ist als 🟢 vorgemerkt — reine Anzeige
  auf einer Gliederung, die ohnehin im Text steht. Voraussetzung: die Überschriften bleiben
  stabil. Jede spätere Änderung an ihnen ist damit auch eine Änderung an dieser Aussicht.

### 9. Perlenkette *(Version 2.0)* ⏳

**Kontext:** Termine zu einem Thema bilden eine Kette. Wird ein Termin verschoben, stellt sich
die Frage: Was liegt zwischen heute und dem neuen Termin, das ich beachten muss?

**Funktionsweise:**
- An einen Tag gebunden — zeigt alle Einträge, Termine und Aufgaben mit diesem Tag in einem
  definierten Zeitraum.
- Auslöser: Termin im Journal als verschoben markiert, oder manueller Button „Perlenkette prüfen".
- Disponere zeigt alle Perlen — vom aktuellen Tag bis zum neuen Termin — chronologisch:
  Journal-Einträge, Kalendertermine, fällige Aufgaben, betreffende Daily-Info-Einträge mit dem Tag.
- Nutzer sieht auf einen Blick Kollisionen, Vorbereitungsschritte, neu zu Bewertendes.

**Abgrenzung:** keine allgemeine Kalenderansicht, keine Aufgabenverwaltung — Überblick im
Kontext einer Entscheidung.

---

## Funktionen

### Handschrift (final) ✅
- **Text-Modus:** FreeScript via natives `EditText` / PlatformView (Hybrid Composition) —
  on-device, offline, Google-frei. Ein natives `EditText` deckt **beide** Eingabearten ab:
  M-Pencil (FreeScript) und Tastatur.
- **Wichtige Unterscheidung:** In normalen Flutter-`TextField`s (z.B. Tagesinfo) kommt die
  Handschrifterkennung von der **aktiven Tastatur** (Gboard-Handschrift), **nicht** von
  FreeScript. FreeScript ist ausschließlich das dedizierte native Feld.
- Flutters eigener Weg (`Scribe` / `stylusHandwritingEnabled`) ist auf dem MatePad **nicht**
  verfügbar — FreeScript meldet sich nicht über die Standard-AOSP-Schnittstelle.
- **Tinten-Modus:** Canvas mit Palm Rejection (`Listener` + `PointerDeviceKind.stylus`),
  Strichdaten serialisiert.
- ML Kit Text Recognition nur für **gedruckten** Text (Dokument-Import).

### Google Calendar-Anbindung ✅
- **Read-only.** Disponere liest und schreibt nichts nach Google zurück.
- **OAuth über AppAuth/PKCE**, ohne Google-Play-Dienste. Refresh-Token im Android Keystore
  (`flutter_secure_storage`), nicht in der DB. Consent-Screen „In Produktion", weil
  `calendar.readonly` ein sensibler Scope ist und Token im Testing-Modus nach 7 Tagen ablaufen.
- **Kalender → Tag-Zuordnung, global einmal** eingerichtet; Termine kommen vor-getaggt ins Journal.
  Auswahl, welche Kalender berücksichtigt werden. Neues Projekt = höchstens eine Zeile.
  Kein Per-Termin-Override in v1.0.
- **Sync:** Vollabruf im rollenden Fenster **−30 / +365 Tage**, `singleEvents=true` (Google
  expandiert Serien — kein RRULE-Motor nötig). Termine eines Kalenders werden lokal vollständig
  ersetzt; Löschungen und Verschiebungen ergeben sich damit von selbst.
  Auslöser: **„Sync jetzt"-Knopf**, kein Hintergrunddienst.
- **Einblendung:** TERMINE-Sektion pro Tag, ganztägige zuerst, mit Zeit und Ort; bei mehrtägigen
  „ab …" / „bis …". Geerbte Tags sind sichtbar.
- `iCalUID` wird als Dedup-Reserve mitgeführt, in v1.0 nicht ausgewertet.

### Claude-Integration ✅ *(Umfang festgelegt)*
**Leitsatz:** *Claude spricht nie ungefragt ins Journal.* Keine Hintergrundverarbeitung, keine
automatischen Tag-Vorschläge, keine stille Anreicherung. Jeder API-Aufruf hat einen Knopfdruck
als Ursache und ein sichtbares Ergebnis als Folge.

**Genau zwei Funktionen in v1.0:**
1. **Tinten-Auswertung** — ein handschriftlicher Eintrag wird als Bild (schwarz auf weiß,
   lange Kante ≤ 1568 px, aus den Vektordaten gerendert, **unabhängig vom Theme**) an die
   multimodale API geschickt und kommt als Text zurück. Ergebnis landet in **eigenen Spalten**
   `ink_text` / `ink_text_at`, **nicht** in `content`: `content` ist, was der Nutzer geschrieben
   hat; `ink_text`, was die Maschine geraten hat. Die Tinte bleibt unverändert das Original.
2. **Wochenauswertung** — siehe Kernkonzept 8.

Daraus folgt die **lokale Suche** (Kernkonzept 7) als dritte, netzunabhängige Funktion.

**Randbedingungen:** Öffentliches Repo → kein Schlüssel im Code; jeder trägt seinen eigenen ein
(Einstellungs-Screen, Keystore). Direktaufruf gegen `api.anthropic.com`, kein Proxy — bei einer
Einzelnutzer-App ist der Nutzer der Schlüssel-Eigentümer.

### Editierbarkeit ✅
- Jeder Eintrag + seine Tags jederzeit editierbar — Karte antippen öffnet das vorbefüllte Sheet
  bzw. den Tinten-Editor.
- `timestamp` bleibt beim Bearbeiten erhalten (Eintrag behält seinen Platz auf der Zeitachse).
- Bearbeiten via Tastatur (das native FreeScript-Feld kann derzeit nicht vorbefüllt werden).

### Tag-Ansicht ✅ *(neu gegenüber v4.0)*
- Eigener Screen (`tag_view_screen.dart`): **alles zu einem `#Tag` über alle Tage**. Kopf =
  `#Tag` groß im Akzentblau + Zählzeile („N Einträge · M Aufgaben · …", nur nicht-leere Typen).
- Inhalt **nach Kalendertag gruppiert, neu nach alt**; je Tag die Reihenfolge TAGESINFO →
  TERMINE → AUFGABEN → Einträge, Aufgaben ohne Fälligkeit in einer Gruppe „Ohne Datum" am Ende.
  Der heutige Tag ist als „HEUTE" ausgezeichnet.
- **Reine Lese-Ansicht** — kein Bearbeiten, kein Abhaken; das lebt weiter im Journal. Direkte
  Interaktion kann später nachziehen.
- **Quervernetzung:** die übrigen Tags jedes Elements stehen als antippbare Chips darunter →
  Sprung in die jeweilige Tag-Ansicht (Perlenkette im Kleinen).
- **Erreichbar** über jeden `#Tag`-Chip im Journal.
- **Tagesinfo per Inline-`#Tag`:** eine `DailyInfo` hat kein Tag-Feld; sie taucht über das
  Inline-`#Tag` im Text auf (voller Token, `#Urlaub` trifft nicht `#Urlaubsplanung`) — ohne
  Schema-Eingriff.

### Theme ✅ *(umgesetzt, über alle Screens ausgerollt)*
- **Ein einziges helles Theme. Kein Dunkelmodus in v1.0.** Der bisherige Default (dunkel mit
  kühlen Blautönen) entfällt. Journal in Session 29, die übrigen fünf Screens in Session 39.
  Zentrale Farbquelle: `lib/theme/app_colors.dart` (`buildLightTheme()`), Akzentblau `#185FA5`.
- Vorlage: Logseq auf dem MatePad — fast weißer Grund, fast schwarzer Text, **eine** gedämpfte
  Akzentfarbe ausschließlich für Tags und Antippbares, Hierarchie über Größe und Gewicht statt
  über Farbe, keine Karten mit Rahmen und Schatten, Trennung über Weißraum und feine Linien.
- **Begründung:** Handschrift ist dunkler Strich auf hellem Grund. Hell auf dunkel wirkt bei
  Handschrift wie Kreide auf Tafel, nie wie Notizbuch. Das löst den seit Monaten mitlaufenden
  Konflikt zwischen Theme und Tinten-Modus.
- Kein reines `#FFFFFF` / `#000000` (flimmert auf dem MatePad-Display); Tinte in dunklem
  Anthrazit, nicht Schwarz.
- Ein Dunkelmodus lässt sich jederzeit nachrüsten.

### Teilen & Bilder ⏳ *(`#Disponere-Versio`, absolute Priorität)*

Drei zusammenhängende Anforderungen, aus Disponere selbst über `#Disponere-Versio` gemeldet
(01.08.2026). Umsetzung **Feature-weise in dieser Reihenfolge** (1 ist Fundament für die
Bild-Wege in 2 und 3). Alles **reines AOSP-Android, GMS-frei** — läuft auf dem HMS-MatePad
ohne Google-Dienst; on-device-Test auf dem MatePad wegen HarmonyOS-Eigenheiten im Teilen-Dialog
zwingend.

1. **Bilder in Disponere ablegen.** Neuer Eintragsinhalt neben Text und Tinte. Bild-Bytes in
   den App-privaten Speicher kopieren (überlebt dort), Pfad in der DB referenzieren →
   **Schema-Migration v6 → v7** (Anhang-Tabelle bzw. -Spalte). Bildauswahl über `image_picker`
   (Galerie/Kamera, AOSP-Intents). Anzeige als Thumbnail in der Eintragskarte, Vollbild beim
   Antippen. Fundament für die Bild-Wege in 2 und 3.

2. **Disponere als Empfangsziel beim Teilen.** `<intent-filter>` mit `ACTION_SEND` im
   `AndroidManifest.xml` → Disponere erscheint im System-Teilen-Dialog. Das Geteilte landet als
   Eintrag **im Journal des aktuellen Tages**. Empfangsweg: **natives MethodChannel in
   `MainActivity`** (`getIntent()` / `onNewIntent()`), **nicht** das Plugin
   `receive_sharing_intent` — robuster auf HMS, in derselben Werkzeuglinie wie
   FreeScript-PlatformView und AppAuth. Zwei Fälle: Kaltstart per Teilen und laufende App.
   Geteilter Text/URL → Texteintrag; geteiltes Bild → nutzt Feature 1. Kleines Landeblatt
   (Inhalt zeigen, Tags ergänzen, speichern) vorgesehen.

3. **Aus Disponere heraus teilen.** Teilen-Einstieg am Eintrag (Icon / Long-Press), sendet den
   System-Teilen-Intent via `share_plus` (AOSP, GMS-frei). Texteintrag → Text; **Tinteneintrag
   → PNG** über den vorhandenen `ink_renderer.dart` (Schwarz-auf-weiß-Render, schon für die
   Claude-Auswertung gebaut, direkt wiederverwendbar); Bildeintrag → Datei. Text/Tinte sind
   unabhängig von Feature 1.

**Aufwand (grob):** Feature 1 eine volle Session (größtes, Schema-Migration), Feature 2 ~eine
Session (Text/URL; Bilder danach klein), Feature 3 halbe bis eine Session (leichtestes).
Gesamt rund 3–4 fokussierte Sessions je nach Politur und HMS-Teilen-Dialog-Iteration.

### Dokument-Import ⏳ 🟢
- Pro Import entscheidet der Nutzer: **als Text** (Journal-Eintrag + Inhalt auf Tag-Seite) oder
  **als Dokument** (Datei als Anhang an einen Tag).
- Quellen: Plaud Note Pro Transkripte (PDF / Text); Dateiname als Vorschlag für den ersten Tag.
- **Plaud ist ein Datenweg, kein KI-Weg.** Plaud liefert bereits ein ausgewertetes Dokument;
  es erneut durch die API zu schicken hieße, zweimal für dieselbe Arbeit zu zahlen. ToDos
  übernimmt der Nutzer selbst ins Journal — das ist der Moment, in dem das Transkript
  tatsächlich gelesen und bewertet wird.
- Gelesen wird über den Android-Dateidialog aus einem festen lokalen Ordner. Exportiert Plaud
  echten Text statt eines gescannten PDFs, wird **kein ML Kit** gebraucht.

### Backup ⏳ 🟢
- Export / Import (lokale DB + Tinten-Assets), Nutzer legt das Archiv selbst ab (z.B. pCloud).
- Echtes Cloud-Sync bleibt in v1.0 bewusst draußen.

---

## Schnittstellen & Abhängigkeiten

Drei Kategorien — analog zum Basketball-Prinzip:

| Kategorie | Bedeutung | Analogie |
|---|---|---|
| 🔴 **Blocker** | Ohne das läuft die App nicht | Kein Ball — kein Spiel |
| 🟡 **Core** | Ohne das fehlt der eigentliche Mehrwert | Kann nicht werfen — kein richtiges Spiel |
| 🟢 **Enhancement** | Verbessert das Erlebnis, App läuft auch ohne | Falsche Klamotten — läuft trotzdem |

Status: ✅ gebaut · 🔧 in Arbeit · ⏳ geplant

### Fundament (technisch)

| Abhängigkeit | Kategorie | Status |
|---|---|---|
| Flutter läuft auf MatePad | 🔴 Blocker | ✅ |
| Daily Journal funktioniert | 🔴 Blocker | ✅ |
| Tag-System funktioniert | 🔴 Blocker | ✅ |
| Datenpersistenz | 🔴 Blocker | ✅ SQLite, Schema v6 |
| Handschrift Text-Modus (FreeScript) | 🟡 Core | ✅ |
| Google Calendar-Anbindung | 🟡 Core | ✅ |
| Anthropic API-Zugang | 🟡 Core | ✅ API läuft, abgenommen (Session 38) |

### Features

| Feature | Kategorie | Status |
|---|---|---|
| Tastatureingabe (Journaleinträge) | 🔴 Blocker | ✅ |
| Handschrift Text-Modus (FreeScript) | 🟡 Core | ✅ |
| Handschrift Tinten-Modus (Canvas / Striche) | 🟡 Core | ✅ |
| Mehrfach-Tags pro Eintrag | 🟡 Core | ✅ |
| Tag-Register / Normalisierung | 🟡 Core | ✅ |
| Editierbarkeit von Einträgen + Tags | 🟡 Core | ✅ |
| Daily Info (Tagesinfo) | 🟡 Core | ✅ |
| Aufgaben-Management | 🟡 Core | ✅ |
| Kalendertermine im Journal (Heute-Panel / Tagesblock) | 🟡 Core | ✅ |
| Tinten-Auswertung durch Claude | 🟡 Core | ✅ abgenommen (Session 38) |
| Wochenauswertung | 🟡 Core | ✅ abgenommen (Session 38) |
| Suche (`content` + `ink_text`) | 🟡 Core | ✅ abgenommen (Session 38) |
| Tag-Ansicht (alles zu einem Tag) | 🟡 Core | ✅ |
| Theme (hell, dezent) | 🟡 Core | ✅ |
| Tag-Autocomplete („Meintest du …?") | 🟢 Enhancement | ✅ |
| Tag-Verwaltung / Umbenennen | 🟢 Enhancement | ✅ |
| Dokument-Import | 🟢 Enhancement | ⏳ |
| Backup / Export | 🟢 Enhancement | ⏳ |
| Bild als Eintragsinhalt (Anhang, Schema v7) | 🟡 Core | ⏳ Versio, hohe Prio |
| Teilen: Disponere als Empfangsziel (`ACTION_SEND`, natives MethodChannel) | 🟢 Enhancement | ⏳ Versio, hohe Prio |
| Teilen: aus Disponere heraus (`share_plus`) | 🟢 Enhancement | ⏳ Versio, hohe Prio |
| Mindmap-Darstellung der Wochenauswertung | 🟢 Enhancement | ⏳ |

*Entfallen gegenüber v2.0: Stempel-Tool (aus v1.0 gestrichen — räumliche Idee lebt als
v2-Feature „Bereiche in Handschrift markieren").*

### Perlenkette (Version 2.0)

| Teilfunktion | Kategorie | Status |
|---|---|---|
| Tag-System | 🔴 Blocker | ✅ vorhanden |
| Google Calendar-Integration | 🔴 Blocker | ✅ vorhanden |
| Vorwärts-Zeitraum (heute → Zieltermin) | 🟡 Core | ⏳ |
| Rückwärts-Zeitraum (Kontext davor) | 🟡 Core | ⏳ |
| Manueller Button („Perlenkette prüfen") | 🟡 Core | ⏳ |
| Claude erkennt Terminverschiebung automatisch | 🟢 Enhancement | ⏳ |
| Visuelle Zeitlinie (Perlen-UI) | 🟢 Enhancement | ⏳ |
| Tap auf Perle öffnet Journal-Tag | 🟢 Enhancement | ⏳ |

*Beide 🔴-Blocker der Perlenkette stehen inzwischen — das Fundament für v2.0 ist gelegt.*

---

## Bewusst nicht in Version 1.0

- Graph-Ansicht (à la Logseq) — spätere Version
- Weitere Kalender-Systeme außer Google Calendar (außer als ICS-Bridge)
- Cloud-Sync · Desktop-Version
- Perlenkette *(Version 2.0)*
- **Stempel-Tool** — gestrichen; Idee lebt als v2-Feature „Bereiche in Handschrift markieren"
- **Lokale Volltextsuche von Tinte** (ohne vorherige Auswertung) — keine On-Device-Engine
- **Dunkelmodus** — ein Theme statt zwei
- Kalender: **Write-back nach Google** · Auto-Hintergrund-Sync · Per-Termin-Tag-Override ·
  mehrere Google-Konten · RRULE-Bearbeitung
- Claude: automatische Tag-Vorschläge · Hintergrund- oder Stapelauswertung ·
  Korrigierbarkeit von `ink_text` · **Chat mit dem eigenen Journal** · Auswertung frei
  wählbarer Zeiträume
- Suche: über Aufgaben, Tagesinfo und Termine · Trefferhervorhebung, Ranking, Tag-Filter

---

## Offene Punkte

| Punkt | Beschreibung |
|---|---|
| Erkennungsqualität Handschrift | Bei der Abnahme (Session 38) auf Anhieb makellos, kein Nachjustieren nötig. Falls sie später enttäuscht, in dieser Reihenfolge: Strichbreite, Auflösung, Wiedereinschalten von Thinking. |
| `stop_reason: max_tokens` | Bei sehr langer Handschrift theoretisch abgeschnittener Text ohne Warnung — nicht gesondert behandelt, bislang nie aufgetreten. |
| Lokale Tinten-Volltextsuche | Ohne vorherige Claude-Auswertung nicht möglich — keine On-Device-Handschrift-OCR. |
| Zeitzonen-Preis der Tages-Keys | Kalendertermine liegen als lokale Tages-Keys in der DB. Ein Zeitzonenwechsel macht sie falsch; Korrektur ist ein Druck auf „Sync jetzt". Reversibel geflaggt. |
| Perlenkette — Datenmodell | Eigener Index über tag-verknüpfte Einträge, oder Laufzeit-Abfrage über Journal + Calendar + Aufgaben? |
| Tags der Wochenauswertung | Beim Übernehmen nur `#Wochenauswertung`, oder zusätzlich die Tags der Woche? Letzteres ließe sie unter jedem berührten Projekt auftauchen — nah am Kern der App. Journal-Arbeit, nicht Prompt-Arbeit. |
| Plaud-Ordner auf dem MatePad | Fester lokaler Ordner für den Dokument-Import noch festzulegen. |
| Bild-Ablage (Feature 1) | App-privater Zielordner, Thumbnail-Strategie und Anhang-Datenmodell (eigene Tabelle vs. Spalte am Eintrag) in der Feature-1-Session festzulegen; Schema-Migration v6 → v7. |

---

## v2-Ausblick

- **Bereiche in der Handschrift markieren** und gezielt einen Zusatz-Tag nur diesem Bereich
  zuordnen — elegante Wiedergeburt der Stempel-Idee, passt zur ursprünglichen Vision
  (Zeile / Satz / Absatz mehreren Tags zuordnen)
- **Perlenkette** (Konzept siehe oben)
- **Dunkelmodus** als zweites Theme
- **Chat mit dem eigenen Journal** — reizvoll, aber ein eigenes Konzept
- **Automatische Zustellung der Wochenauswertung** — an Cloud-Sync gekoppelt

---

*Disponere — „anordnen, einteilen, in Ordnung bringen"*
