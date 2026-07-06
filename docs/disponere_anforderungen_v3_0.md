# Disponere
### Strukturiertes Denken und Notieren
*Anforderungsdokument — Version 3.0*
*Stand: Juni 2026 (nach Session 12)*

---

## Was sich gegenüber Version 2.0 geändert hat

- **Handschrift-Engine final entschieden:** Huawei **FreeScript** (native System-Handschrifterkennung) via natives `EditText` / PlatformView — **nicht** Huawei ML Kit. ML Kit bleibt nur für *gedruckten* Text (Dokument-Import) relevant.
- **Stempel-Tool aus v1.0 gestrichen** — Tag-Vergabe läuft über ein dediziertes Tag-Feld. Die räumliche Idee lebt als v2-Feature weiter.
- **Zwei Eingabe-Modi** pro Eintrag eingeführt: Text-Modus und Tinten-Modus.
- **Datenmodell präzisiert:** ein durchgehendes Journal, Tags als gefilterte Sicht, Datum als Abfrage.
- **Tag-System ausgebaut:** Mehrfach-Tags (`#`-getrennt), Tag-Register mit Normalisierung, Autocomplete.
- **Persistenz:** Migration `shared_preferences` → lokale DB (SQLite) eingeplant.
- **Umsetzungsstand** durchgehend markiert: ✅ gebaut · 🔧 in Arbeit · ⏳ geplant.

---

## Vision

Disponere ist eine Android-App für das Huawei MatePad Pro. Herzstück ist das handschriftliche Notieren mit dem M-Pencil. Gedanken werden nicht nur festgehalten, sondern durch Tags strukturiert und miteinander verknüpft — über ein einziges, durchgehendes Journal.

Disponere ist Open Source — gebaut für einen Nutzer, offen für alle. Und ein Beispiel sinnvoller Mensch-KI-Zusammenarbeit: Claude ist von Anfang an Teil der App.

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
| Handschrift → Tinte | Canvas, Speicherung als Strichdaten (Vektoren) | Bleibt editierbar; PNG nur bei Bedarf 🔧 |
| OCR gedruckter Text | Huawei ML Kit | Nur für Dokument-Import; kann **keine** Handschrift |
| Persistenz | lokal: `shared_preferences` → **SQLite** | Migration geplant ⏳ |
| Lizenz | Open Source | GitHub, frei zugänglich |
| KI-Integration | Claude (Anthropic API) | Teil der Vision von Anfang an ⏳ |

---

## Kernkonzepte

### 1. Ein Journal, Tags als Sicht ✅
- Es gibt **ein** durchgehendes Journal (Tageszeitachse). Kein Datei-pro-Tag, kein Journal-pro-Projekt.
- "Projekte" (z.B. Wasser, Wärme, MBS) sind **Tags**, keine eigenen Journale.
- Eine **Tag-Seite ist eine gefilterte Sicht** über das eine Journal; ein **"Tag" (Datum) ist eine Abfrage**, keine Datei.
- Perspektivisch lokale DB, abfragbar nach Datum / Tag / Zeitraum (Grundlage u.a. für die Perlenkette).

### 2. Daily Journal
- Beim ersten Start eines Tages wird automatisch eine neue Journal-Sicht angelegt
- Das Journal ist die zentrale Arbeitsfläche; jeder Eintrag trägt Datum und Uhrzeit ✅
- Google Calendar-Integration: Termine erscheinen automatisch als vor-getaggte Einträge mit Zeitstempel ⏳
- Aufgaben mit Fälligkeit heute erscheinen ebenfalls im Journal ⏳

### 3. Tag-System ✅
- **Mehrfach-Tags pro Eintrag**, `#`-getrennt (`#MBS #ValSys #Vertrag`). Ein Tag = ein Wort. ✅
- Tags können nachträglich hinzugefügt / entfernt werden (über Editierbarkeit). ✅
- **Tag-Register mit Normalisierung:** Schreibvarianten werden case-insensitiv zusammengeführt (`ValSys` = `valsys` → ein Tag). Kanonische Schreibweise = **case-preserving, "erste Schreibweise gewinnt"** (Akronyme/deutsche Substantive bleiben lesbar). Abgeleitet aus den Einträgen, keine eigene Persistenz. ✅
- **Autocomplete:** Vorschlags-Chips zum getippten Fragment; bei keinem Treffer Fuzzy-Vorschlag "Meintest du …?" (Levenshtein). An beiden Eingabewegen. ✅
- **Tag-Verwaltung / Umbenennen** (kanonische Schreibweise selbst festlegen — löst die reihenfolge-abhängige Kanonisierung). ⏳

### 4. Zwei Eingabe-Modi
- **Text-Modus:** Stift (FreeScript) **oder** Tastatur → gespeichert als **Text** → durchsuchbar, von Claude lesbar. ✅
- **Tinten-Modus:** Canvas → gespeichert als **Strichdaten (Vektoren)**, **keine** Umwandlung → bleibt Handschrift, editier- und weiterschreibbar. 🔧 (Canvas vorhanden; Modell + Serialisierung ausstehend)
- Begründung Strichdaten statt PNG: "Editierbarkeit" ist 🟡 Core — ein nicht weiterbearbeitbarer Tinten-Eintrag würde das brechen. PNG nur als Anzeige-/Render-Version bei Bedarf.

### 5. Daily Info ⏳
- Eigener Bereich oben im Journal, farblich abgesetzt
- Zeigt menschlichen Kontext für den Tag (was ist heute bei Menschen im Umfeld los)
- Freier Text, ein Eintrag pro Zeile; je Eintrag ein Datum oder eine Zeitspanne (von/bis)
- Erscheint automatisch im Journal aller betroffenen Tage
- Klar getrennt von Aufgaben und Kalenderterminen

### 6. Aufgaben ⏳
- Jederzeit erstellbar; Datum und Uhrzeit optional
- Am Fälligkeitstag automatisch im Journal; klar unterscheidbar von Kalenderterminen

### 7. Perlenkette *(Version 2.0)* ⏳

**Kontext:** Termine zu einem Thema bilden eine Kette. Wird ein Termin verschoben, stellt sich die Frage: Was liegt zwischen heute und dem neuen Termin, das ich beachten muss?

**Funktionsweise:**
- An einen Tag gebunden — zeigt alle Einträge, Termine und Aufgaben mit diesem Tag in einem definierten Zeitraum
- Auslöser: Termin im Journal als verschoben markiert, oder manueller Button "Perlenkette prüfen"
- Disponere zeigt alle Perlen — vom aktuellen Tag bis zum neuen Termin — chronologisch: Journal-Einträge, Kalendertermine, fällige Aufgaben, betreffende Daily-Info-Einträge mit dem Tag
- Nutzer sieht auf einen Blick Kollisionen, Vorbereitungsschritte, neu zu Bewertendes

**Abgrenzung:** keine allgemeine Kalenderansicht, keine Aufgabenverwaltung — Überblick im Kontext einer Entscheidung.

---

## Funktionen

### Handschrift (final)
- **Text-Modus:** FreeScript via natives `EditText` / PlatformView (Hybrid Composition) — on-device, offline, Google-frei ✅
- Ein natives `EditText` deckt **beide** Eingabearten ab: M-Pencil (FreeScript) und Tastatur
- Flutters eigener Weg (`Scribe` / `stylusHandwritingEnabled`) ist auf dem MatePad **nicht** verfügbar — FreeScript meldet sich nicht über die Standard-AOSP-Schnittstelle
- **Tinten-Modus:** Canvas mit Palm Rejection (`Listener` + `PointerDeviceKind.stylus`) ✅ — Striche-Speicherung 🔧
- ML Kit Text Recognition nur für **gedruckten** Text (Dokument-Import)

### Google Calendar-Anbindung ⏳
- **Kalender → Tag-Zuordnung, global einmal** eingerichtet; Termine kommen vor-getaggt ins Journal
- Auswahl, welche Kalender berücksichtigt werden (Privat, Familie, Wasser, Wärme …)
- Neues Projekt = höchstens eine Zeile in der Zuordnung

### Dokument-Import ⏳
- Pro Import entscheidet der Nutzer: **als Text** (Journal-Eintrag + Inhalt auf Tag-Seite) oder **als Dokument** (Datei als Anhang an einen Tag)
- Quellen: Plaud Note Pro Transkripte (PDF / Text); Dateiname als Vorschlag für den ersten Tag
- Gedruckter Text wird per Huawei ML Kit erkannt

### Editierbarkeit ✅
- Jeder Eintrag + seine Tags jederzeit editierbar — Karte antippen öffnet das vorbefüllte Sheet
- `timestamp` bleibt beim Bearbeiten erhalten (Eintrag behält seinen Platz auf der Zeitachse)
- Bearbeiten via Tastatur (das native FreeScript-Feld kann derzeit nicht vorbefüllt werden)

### Claude-Integration ⏳
- Text-Einträge direkt lesbar
- Tinten-Einträge auswertbar über die **multimodale Anthropic-Bild-API** (Handschrift-PNG mitschicken) — braucht Netz + API-Call, Erkennung schrift-abhängig
- **Lokale Volltextsuche von Tinte ungelöst** (keine On-Device-Handschrift-OCR)
- Mögliche Funktionen: Zusammenfassen, Tag-Vorschläge, Fragen an den eigenen Wissensstand

### Backup ⏳
- Export / Import (lokale DB + Tinten-Assets), Nutzer legt das Archiv selbst ab (z.B. pCloud)
- Echtes Cloud-Sync bleibt in v1.0 bewusst draußen

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
| Datenpersistenz | 🔴 Blocker | ✅ `shared_preferences` (SQLite-Migration ⏳) |
| Handschrift Text-Modus (FreeScript) | 🟡 Core | ✅ |
| Google Calendar-Anbindung | 🟡 Core | ⏳ |
| Anthropic API-Zugang | 🟡 Core | ⏳ |

### Features

| Feature | Kategorie | Status |
|---|---|---|
| Tastatureingabe (Journaleinträge) | 🔴 Blocker | ✅ |
| Handschrift Text-Modus (FreeScript) | 🟡 Core | ✅ |
| Handschrift Tinten-Modus (Canvas / Striche) | 🟡 Core | 🔧 Canvas da, Speicherung ⏳ |
| Mehrfach-Tags pro Eintrag | 🟡 Core | ✅ |
| Tag-Register / Normalisierung | 🟡 Core | ✅ |
| Editierbarkeit von Einträgen + Tags | 🟡 Core | ✅ |
| Daily Info | 🟡 Core | ⏳ |
| Aufgaben-Management | 🟡 Core | ⏳ |
| Tag-Autocomplete ("Meintest du …?") | 🟢 Enhancement | ✅ |
| Tag-Verwaltung / Umbenennen | 🟢 Enhancement | ⏳ |
| Dokument-Import | 🟢 Enhancement | ⏳ |

*Entfallen gegenüber v2.0: Stempel-Tool (aus v1.0 gestrichen — räumliche Idee lebt als v2-Feature "Bereiche in Handschrift markieren").*

### Perlenkette (Version 2.0) — alle ⏳

| Teilfunktion | Kategorie |
|---|---|
| Tag-System | 🔴 Blocker (✅ vorhanden) |
| Google Calendar-Integration | 🔴 Blocker (⏳) |
| Vorwärts-Zeitraum (heute → Zieltermin) | 🟡 Core |
| Rückwärts-Zeitraum (Kontext davor) | 🟡 Core |
| Manueller Button ("Perlenkette prüfen") | 🟡 Core |
| Claude erkennt Terminverschiebung automatisch | 🟢 Enhancement |
| Visuelle Zeitlinie (Perlen-UI) | 🟢 Enhancement |
| Tap auf Perle öffnet Journal-Tag | 🟢 Enhancement |

---

## Bewusst nicht in Version 1.0

- Graph-Ansicht (à la Logseq) — spätere Version
- Weitere Kalender-Systeme außer Google Calendar
- Cloud-Sync
- Desktop-Version
- Perlenkette *(Version 2.0)*
- **Stempel-Tool** — gestrichen; Idee lebt als v2-Feature "Bereiche in Handschrift markieren"
- **Lokale Volltextsuche von Tinte** — keine On-Device-Engine vorhanden (evtl. v2+, nicht garantiert)

---

## Offene Punkte

| Punkt | Beschreibung |
|---|---|
| Tinten-Modus — Datenmodell | Strichdaten serialisieren (JSON), `JournalEntry` um einen Tinten-Körper erweitern, Striche laden / weiterschreiben |
| Tag-Verwaltung / Umbenennen | Kanonische Schreibweise selbst festlegen — Hebel gegen reihenfolge-abhängige Kanonisierung |
| Lokale Tinten-Volltextsuche | Keine On-Device-Handschrift-OCR (ML Kit kann keine Handschrift, FreeScript ist reine Eingabe) |
| DB-Migration | `shared_preferences` → SQLite, abfragbar nach Datum / Tag / Zeitraum (Basis u.a. Perlenkette) |
| Claude-Integration | Umfang und Einstiegspunkt der KI-Funktionen für v1.0 festlegen |
| Google Calendar | API-Zugänge einrichten; Kalender → Tag-Mapping bauen |
| Perlenkette — Datenmodell | Eigener Index über tag-verknüpfte Einträge, oder Laufzeit-Abfrage über Journal + Calendar + Aufgaben? |

---

## v2-Ausblick

- **Bereiche in der Handschrift markieren** und gezielt einen Zusatz-Tag nur diesem Bereich zuordnen — elegante Wiedergeburt der Stempel-Idee, passt zur ursprünglichen Vision (Zeile / Satz / Absatz mehreren Tags zuordnen)
- **Perlenkette** (Konzept siehe oben)

---

*Disponere — "anordnen, einteilen, in Ordnung bringen"*
