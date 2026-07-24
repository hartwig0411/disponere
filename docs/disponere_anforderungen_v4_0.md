# Disponere
### Strukturiertes Denken und Notieren
*Anforderungsdokument — Version 4.0*
*Stand: 24. Juli 2026 (nach Session 27)*

---

## Was sich gegenüber Version 3.0 geändert hat

Version 3.0 stand nach Session 12. Seitdem sind fünfzehn Sitzungen vergangen, in denen
das Dokument bewusst nicht mitgezogen wurde — der Nachzug war in jedem Fortschrittsbericht
als offener Punkt vermerkt. Er passiert hier, in einem Zug.

- **Persistenz vollzogen:** `shared_preferences` → **SQLite**, inzwischen bei **Schema v6**
  (v3 normalisierte Tag-Tabellen · v4 Kalender-Quellen · v5 Termine · v6 erkannter Tinten-Text).
- **Google Calendar-Anbindung gebaut** — von 🟡 Core ⏳ auf ✅. OAuth (AppAuth/PKCE, ohne
  Google-Play-Dienste), Kalenderliste mit Tag-Zuordnung, Sync-Engine, Einblendung im Journal.
- **Claude-Integration im Umfang festgelegt und gebaut** — von ⏳ auf ✅. **Genau zwei**
  Funktionen in v1.0: Tinten-Auswertung und Wochenauswertung. Leitsatz: *Claude spricht nie
  ungefragt ins Journal.*
- **Zwei neue 🟡-Core-Punkte**, die es in v3.0 noch nicht gab: **Suche** und
  **Wochenauswertung**. Beide gebaut.
- **Theme entschieden:** ein einziges **helles** Theme, Logseq-nah. Der bisherige Default
  (dunkel mit kühlen Blautönen) entfällt. Umsetzung steht noch aus.
- **Tagesinfo-Formulierung korrigiert:** „farblich abgesetzt" kollidierte mit dem
  Ein-Akzentfarben-Prinzip des neuen Themes und ist ersetzt.
- **Tinten-Modus, Aufgaben, Daily Info, Tag-Verwaltung** — alle vier von ⏳/🔧 auf ✅.

---

## Vision

Disponere ist eine Android-App für das Huawei MatePad Pro. Herzstück ist das handschriftliche
Notieren mit dem M-Pencil. Gedanken werden nicht nur festgehalten, sondern durch Tags
strukturiert und miteinander verknüpft — über ein einziges, durchgehendes Journal.

Disponere ist Open Source — gebaut für einen Nutzer, offen für alle. Und ein Beispiel
sinnvoller Mensch-KI-Zusammenarbeit: Claude ist von Anfang an Teil der App.

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
| KI-Integration | Claude (Anthropic API), Modell `claude-sonnet-5`, Direktaufruf ohne Proxy | Zwei nutzerausgelöste Funktionen ✅ (Abnahme der Tinten-Auswertung steht aus — siehe Offene Punkte) |
| Theme | ein helles Theme, eine Akzentfarbe | Entschieden, Umsetzung ⏳ |
| Lizenz | Open Source | GitHub, frei zugänglich |

**Pakete:** `sqflite`, `path`, `path_provider`, `flutter_secure_storage`, `flutter_appauth`, `http`.

---

## Kernkonzepte

### 1. Ein Journal, Tags als Sicht ✅
- Es gibt **ein** durchgehendes Journal (Tageszeitachse). Kein Datei-pro-Tag, kein Journal-pro-Projekt.
- „Projekte" (z.B. Wasser, Wärme, MBS) sind **Tags**, keine eigenen Journale.
- Eine **Tag-Seite ist eine gefilterte Sicht** über das eine Journal; ein **„Tag" (Datum) ist eine
  Abfrage**, keine Datei.
- Die lokale DB ist nach Datum / Tag / Zeitraum abfragbar. Einträge, Aufgaben und Termine haben
  **dieselbe Form der Tag-Abfrage** (normalisierte Verknüpfungstabellen mit `tag_key`).

### 2. Daily Journal ✅
- Beim ersten Start eines Tages wird automatisch eine neue Journal-Sicht angelegt.
- Das Journal ist die zentrale Arbeitsfläche; jeder Eintrag trägt Datum und Uhrzeit. ✅
- **Google Calendar:** Termine erscheinen automatisch als vor-getaggte Einträge mit Zeit. ✅
- **Aufgaben** mit Fälligkeit heute erscheinen ebenfalls im Journal. ✅
- **Reihenfolge der Sektionen:** TAGESINFO → TERMINE → AUFGABEN → Einträge. Erst der Rahmen
  des Tages, dann das Eigene.

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
- Eigener Bereich oben im Journal, durch **leichte Grautönung und Beschriftung** abgehoben —
  nicht durch eine eigene Farbe. Gleiches Muster für TERMINE und AUFGABEN, damit sich alle drei
  Sektionen gleich verhalten.
  *(Ersetzt die Formulierung „farblich abgesetzt" aus v3.0; sie kollidierte mit dem
  Ein-Akzentfarben-Prinzip des entschiedenen Themes.)*
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

### Theme ⏳ *(entschieden, Umsetzung offen)*
- **Ein einziges helles Theme. Kein Dunkelmodus in v1.0.** Der bisherige Default (dunkel mit
  kühlen Blautönen) entfällt.
- Vorlage: Logseq auf dem MatePad — fast weißer Grund, fast schwarzer Text, **eine** gedämpfte
  Akzentfarbe ausschließlich für Tags und Antippbares, Hierarchie über Größe und Gewicht statt
  über Farbe, keine Karten mit Rahmen und Schatten, Trennung über Weißraum und feine Linien.
- **Begründung:** Handschrift ist dunkler Strich auf hellem Grund. Hell auf dunkel wirkt bei
  Handschrift wie Kreide auf Tafel, nie wie Notizbuch. Das löst den seit Monaten mitlaufenden
  Konflikt zwischen Theme und Tinten-Modus.
- Kein reines `#FFFFFF` / `#000000` (flimmert auf dem MatePad-Display); Tinte in dunklem
  Anthrazit, nicht Schwarz.
- Ein Dunkelmodus lässt sich jederzeit nachrüsten.

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
| Anthropic API-Zugang | 🟡 Core | ⏳ Code steht; Konto-Zugang blockiert (Einspruch läuft) |

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
| Kalendertermine im Journal (TERMINE-Sektion) | 🟡 Core | ✅ |
| Tinten-Auswertung durch Claude | 🟡 Core | ✅ gebaut, Abnahme steht aus |
| Wochenauswertung | 🟡 Core | ✅ |
| Suche (`content` + `ink_text`) | 🟡 Core | ✅ |
| Theme (hell, dezent) | 🟡 Core | ⏳ entschieden, Umsetzung offen |
| Tag-Autocomplete („Meintest du …?") | 🟢 Enhancement | ✅ |
| Tag-Verwaltung / Umbenennen | 🟢 Enhancement | ✅ |
| Dokument-Import | 🟢 Enhancement | ⏳ |
| Backup / Export | 🟢 Enhancement | ⏳ |
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
| **Theme-Umsetzung** | Entschieden (hell, dezent, eine Akzentfarbe) — betrifft alle Screens, noch nicht gebaut. Der letzte 🟡-Core-Punkt für v1.0. |
| **Anthropic-Konto** | Organisation gesperrt, Einspruch eingereicht. Ohne Guthaben kein Schlüssel — die **Abnahme** der Tinten-Auswertung steht aus. Der Code ist geprüft; es fehlt allein der Zugang. |
| Erkennungsqualität Handschrift | Falls sie enttäuscht, in dieser Reihenfolge: Strichbreite, Auflösung, Wiedereinschalten von Thinking. |
| Lokale Tinten-Volltextsuche | Ohne vorherige Claude-Auswertung nicht möglich — keine On-Device-Handschrift-OCR. |
| Zeitzonen-Preis der Tages-Keys | Kalendertermine liegen als lokale Tages-Keys in der DB. Ein Zeitzonenwechsel macht sie falsch; Korrektur ist ein Druck auf „Sync jetzt". Reversibel geflaggt. |
| Perlenkette — Datenmodell | Eigener Index über tag-verknüpfte Einträge, oder Laufzeit-Abfrage über Journal + Calendar + Aufgaben? |
| Tags der Wochenauswertung | Beim Übernehmen nur `#Wochenauswertung`, oder zusätzlich die Tags der Woche? Letzteres ließe sie unter jedem berührten Projekt auftauchen — nah am Kern der App. Journal-Arbeit, nicht Prompt-Arbeit. |
| Plaud-Ordner auf dem MatePad | Fester lokaler Ordner für den Dokument-Import noch festzulegen. |

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
