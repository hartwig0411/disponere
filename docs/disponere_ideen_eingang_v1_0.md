# Disponere — Ideen-Eingang
### Landezone für neue Ideen vor der Triage
*Version 1.0*
*Stand: 24. September 2026*

---

## Wozu dieses Dokument

Zwischen „Steffen wirft eine Idee rüber" und „die Idee steht entschieden im
Anforderungsdokument" fehlte bisher ein Platz. Ohne den landet eine Idee entweder
ungefiltert im Anforderungsdokument (und bläht es auf) oder sie geht verloren.

Dieses Dokument ist dieser Platz — die **Arbeitsfläche**. Das Anforderungsdokument
bleibt der **settled record** (nur Entschiedenes).

- **Eingang (dieses Dokument)** = roh, in Bearbeitung, wird bei jeder Triage kürzer.
- **`disponere_anforderungen`** = fertig sortiert: Versio-Features, v2-Ausblick,
  Offene Punkte.

---

## So läuft es

**1. Erfassen.** Neue Ideen kommen roh hier rein — Empfangsdatum, dein Originaltext,
unverändert. Nichts wird verworfen, nichts umgeschrieben. Ein Eingang pro Idee, immer
nach der gleichen Vorlage (unten).

**2. Triage (reiner Chat, keine Code-Session).** Ich gehe die offenen Eingänge einzeln
durch und sortiere jeden in genau einen Ausgang:

| Ausgang | wandert nach | bleibt im Eingang? |
|---|---|---|
| **→ VERSIO** | `disponere_anforderungen` (aktuelle Version, Feature/Abschnitt) | nein — entfernt |
| **→ VISIO** | `disponere_anforderungen` (v2-Ausblick) | nein — entfernt |
| **OFFEN** | `disponere_anforderungen` (Offene Punkte, mit der zu klärenden Frage) | nein — entfernt |
| **VERWORFEN** | nirgends | **ja** — bleibt unten als Gedächtnis, mit einer Zeile Begründung |

Nach der Triage sind die offenen Eingänge leer; nur „Verworfen" bleibt stehen, damit
dieselbe Idee nicht in drei Monaten neu aufschlägt.

### Status-Werte (je Eingang)

- `NEU` — reingekommen, noch nicht angeschaut.
- `ZU LESEN` — Bild/Tinte liegt vor, Transkription steht aus (siehe Bilder-Weg).
- `OFFEN` — verstanden, aber es gibt eine Gabelung zu klären.
- `→ VERSIO` / `→ VISIO` — einsortiert; gehört ins Anforderungsdokument bzw. v2-Ausblick.
- `VERWORFEN` — mit einer Zeile Begründung; bleibt als Gedächtnis.

### Bilder-Weg (Tinte / Screenshot)

Ideen können auch als handschriftliche Notiz oder Screenshot kommen.

- Das Bild kommt **in den Chat** (damit ich es lesen kann) **und** lokal nach
  `E:\disponere\docs\bilder\`.
- Dateiname: `JJJJ-MM-TT_stichwort.png` — nach Datum sortierbar, im Eingang eindeutig
  zitierbar.
- **Die Bilder werden nicht committet** (`docs/bilder/` ist per `.gitignore`
  ausgeschlossen — das Repo ist öffentlich). Sie bleiben nur auf Vega.
- Ich lege den Eingang mit dem **transkribierten Text** an, markiere „aus Bild gelesen
  am TT.MM." und verweise auf den Dateinamen. Bis zur Transkription steht er auf
  `ZU LESEN`.

---

## Eintragsvorlage

Kopiervorlage für einen neuen Eingang (Pflichtfelder oben, situative Felder unten):

```
### E-NN · <Kurzname>
- **Eingegangen:** TT.MM.JJJJ
- **Quelle:** Text aus Disponere  /  aus Bild gelesen am TT.MM. (Datei: docs/bilder/JJJJ-MM-TT_stichwort.png)
- **Kanal (deine Einordnung, falls klar):** Versio / Visio / offen
- **Original (dein Text):** <unverändert>
- **In einem Satz (meine Umformulierung):** <kurz>
- **Status:** NEU / ZU LESEN / OFFEN / → VERSIO / → VISIO / VERWORFEN
- **Größe (grob):** Doku-Zeile / halbe Session / volle Session / Architektur-Session
- **Bei OFFEN — zu klärende Frage:** <die Gabelung>
- **Bei VERWORFEN — Begründung:** <eine Zeile>
- **Nach Triage → wohin:** <Abschnitt im Anforderungsdok / v2-Ausblick / Offene Punkte>
```

`E-NN` fortlaufend nummerieren (E-01, E-02, …), damit sich ein Eingang im Chat kurz
adressieren lässt.

---

## Beispiel (bereits einsortiert — nicht mehr offen)

Zeigt die Vorlage mit echtem Inhalt und die Verzahnung mit „Offene Punkte". Dieser
Eingang ist schon abgearbeitet (in `disponere_anforderungen_v6_2.md`) und steht hier
nur als Muster.

### E-00 · Datierter Eintrag (Rezept für Freitag)
- **Eingegangen:** 13.08.2026
- **Quelle:** Text aus Disponere (im Chat gemeldet)
- **Kanal:** Versio
- **Original (dein Text):** „Rezept als Aufgabe für Freitag hinterlegen — dafür habe
  ich immer ein Bild. Das geht nicht."
- **In einem Satz (meine Umformulierung):** Ein Inhalt mit Bild, der an einem gewählten
  Tag im Journal aufsurft — ohne Abhaken, ohne die Idee der Aufgabe zu verändern.
- **Status:** → VERSIO (einsortiert)
- **Größe (grob):** volle Session (kleine Schema-Erweiterung am Eintrag)
- **Entscheidung:** datierter Eintrag mit optionalem Anzeige-Day; `Task` und
  `attachments` bleiben unangetastet.
- **Nach Triage → wohin:** Anforderungen v6.2 — Änderungsblock, Feature-Zeile, und
  Offene Punkte („Anzeige-Semantik: nur am gewählten Tag oder auch am Erstelltag?").

---

## Offene Eingänge

### E-05 · Autosave / Entwurf sichern in den Compose-Sheets
- **Eingegangen:** 15.09.2026
- **Quelle:** Text aus Disponere (im Chat gemeldet)
- **Kanal (deine Einordnung, falls klar):** Versio (Verlässlichkeit, v1.0-relevant)
- **Original (dein Text):** „Das Thema automatisch speichern. Mir ist es im Tagesgeschäft ein paar Mal passiert, dass Geschriebenes weg war, nachdem ich das Fenster kurz runterlegte oder im Meeting zu einem Thema diskutierte und dann weiterschreiben wollte." — Präzisierung: „passiert bei Neuer Eintrag oder, was für mich gleich ist, wenn ich ein Kalenderevent zu einem Eintrag gemacht habe."
- **In einem Satz (meine Umformulierung):** Ungespeicherter Tipptext in den Compose-Sheets („Neuer Eintrag" und Event→Eintrag-Brücke) geht verloren, wenn Android die App im Hintergrund beendet — ein Entwurfs-Slot soll den Text laufend sichern und beim Zurückkommen wiederherstellen.
- **Status:** OFFEN
- **Größe (grob):** halbe Session
- **Umfang (geklärt):** nur Tipptext-Flächen — „Neuer Eintrag"-Sheet und Event→Eintrag-Brücke (`bridge_sheet`). Nicht das native FreeScript-Feld, nicht die Tintenrolle.
- **Mechanik (Vorschlag):** Entwurf laufend entprellt schreiben, garantiert beim Lebenszyklus-`paused` flushen; beim Öffnen vorbelegen; beim echten Speichern/Verwerfen leeren. Ablage in `shared_preferences` (ein Slot, reversibel).
- **Bei OFFEN — zu klärende Fragen:** (1) Wiederherstellung still oder mit Hinweis „Entwurf wiederhergestellt"? (2) `shared_preferences` (ein Slot) vs. SQLite-Tabelle, falls je mehrere parallele Entwürfe gewünscht. (3) Start-Reihenfolge nach Prefs/DB-Init — Berührungspunkt mit N5 (Kaltstart-Race).
- **Nach Triage → wohin:** Anforderungen (Verlässlichkeit / Compose-Verhalten).

---

## Verworfen (Gedächtnis)

*— noch keiner —*

---

## Einsortiert (Kurzprotokoll)

*Knappe Zeile pro triagiertem Eingang — damit nachvollziehbar bleibt, wohin er ging.
Die ausführliche Fassung lebt im Anforderungsdokument.*

- **E-01 · Bild in der Eintragskarte klein / als Icon → VERSIO** (21.08.2026). Entschieden:
  **kleines Vorschau-Quadrat** (Motiv erkennbar, kein generisches Icon), Vollbild beim
  Antippen, gilt in Journal- und Tag-Ansicht gleich. Reine Anzeige-Änderung an der gebauten
  Bild-Ablage, kein Schema-Eingriff. → `disponere_anforderungen_v6_7.md` (Änderungsblock
  „gegenüber v6.6", Feature 1 „Teilen & Bilder", Feature-Zeile). Bild lokal auf Vega abgelegt.
- **E-02 · Tags aus der Wochenauswertung ausschließen (Feld „Nicht Auswerten") → VERSIO**
  (26.08.2026). Entschieden: Standard = alle Tags; Feld „Nicht Auswerten" nimmt Ausnahmen auf.
  Filter auf **Tag-Ebene** — ein Eintrag bleibt drin, solange er noch mindestens einen
  nicht-ausgeschlossenen Tag hat (tag-lose Einträge nie betroffen), fällt nur bei *allen* Tags
  ausgeschlossen ganz heraus. Ausschlussliste = **globale, persistente Einstellung**, bei jeder
  neuen Woche im Feld vorbefüllt und beim Ändern zurückgeschrieben. Kein Schema-Zwang; Ablage
  der Liste reversibel. → `disponere_anforderungen_v6_9.md` (Änderungsblock „gegenüber v6.8",
  Kernkonzept 8, Feature-Zeile). Größe: halbe Session. **Gebaut in Session 64 (9.9.2026, feat `f9397fb`); Weg B: Filter über Einträge, Aufgaben und Termine, ausgeschlossene Tags auch aus Suffixen und Tag-Übersicht.**
- **E-03 · Tags im Brücken-Sheet editierbar → VERSIO** (29.08.2026). Entschieden: geerbte Tags im
  gemeinsamen `bridge_sheet` editierbar (hinzufügen/entfernen/ändern) über alle drei Brücken-Beine,
  mit Kanonisierung; beim read-only-Termin kein Rückschreiben auf die Quelle. →
  `disponere_anforderungen_v6_13.md`. Größe: halbe Session. **Gebaut in Session 61 (feat `d031935`).**
- **E-04 · OneCalendar im Teilen-Menü (`text/calendar` / `.ics`)** — direkt in Warteschlange und
  Anforderungen erfasst, lief nicht über den Eingang. Steht dort als **offener Punkt**; hier nur als
  Pointer, damit die Nummerierung nachvollziehbar bleibt.
- **E-06 · Text überall markier- und kopierbar → VERSIO** (24.09.2026). Gemeldet im Chat mit
  Screenshot der Tag-Ansicht (#Comos); Behelf bisher: Eintrag → Aufgabe → Eintrag, aufwendig und
  verfälschend. Entschieden: **Ausschnitt markieren**, **überall** wo gespeicherter Text steht
  (ohne Strichbilder/Bilder), **Weg 2**: lange drücken wird einheitlich zur Markier-Geste, die
  bisherigen Long-Press-Menüs wandern hinter ein ⋮-Symbol an der Karte. Kein Schema. →
  `disponere_anforderungen_v6_17.md` (Änderungsblock „gegenüber v6.16", Abschnitt „Text markieren
  & kopieren", Feature-Zeile). Größe: halbe bis ganze Session. Als nächste Session vor E-05.
  **Gebaut in Session 67 (24.09.2026, feat `0ac7dab`); `SelectionArea` je Screen, ⋮-Widget
  `card_menu_button.dart`, auch an der Aufgabenübersicht (vierte Long-Press-Belegung).**

---

*Eingang = Arbeitsfläche · Anforderungsdokument = settled record.*
