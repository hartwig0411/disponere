# Disponere — Design-Grundlagen (helles Theme)

*Referenzdokument. Hält die visuellen Grundentscheidungen fest. Wird selten geaendert — nur wenn sich das Erscheinungsbild grundlegend aendert.*

**Version 2.0 — 28. Juli 2026**
**Status:** Entwurf bestaetigt. Journal-Layout (Seiten-Panel + `#Tag`-Gruppierung) in dieser Design-Session entschieden. Noch nicht in Flutter umgesetzt (reine Design-Session, kein Code).

*Aenderungen gegenueber v1.0: §4 neu gefasst (Trennung heute / vergangene Tage, `#Tag`-Gruppierung), neues §5 „Seiten-Panel — Heute-Agenda", Tagesinfo nebeneinander, neues §11 „Spaetere Versionen". Alte §5–§10 um je eine Nummer verschoben.*

---

## 1. Leitprinzip

Schlicht und reduziert. Vorbild ist Logseq: grosser, ruhiger Datumskopf als Anker, viel Weissraum, leise Farben, haarfeine Trenner. Die Grundhaltung lautet **weglassen** — Reduktion statt Dekoration.

Das Theme ist **hell**. Damit ist zugleich die Tinten-Frage entschieden: **dunkle Tinte auf hellem Grund**, wie auf Papier. Handschrift liest sich so, wie eine Handschrift sich lesen soll — kein Kampf gegen die Gewohnheit.

Ein **dunkles Theme ist fuer v1.0 nicht geplant.**

---

## 2. Farben

Alles Licht-Modus-Werte. Gedaempft, nichts schreit.

| Rolle | Hex |
|---|---|
| Seitenhintergrund (Papier) | `#FCFCFA` |
| Rahmen / Screen-Kante | `#E7E6E1` |
| Datum (gross) | `#1C1D22` |
| Wochentag (klein, ueber dem Datum) | `#A6A69E` |
| Getippter Text / Tinte allgemein | `#24252A` |
| Handschriftlicher Eintrag (Tinte) | `#2A2B48` (ein Hauch Blau-Schwarz) |
| **Akzentblau** (Tags, Cursor, Kalender-Icon, Aufgaben-Haekchen, aktives Icon, Panel-Badge) | `#185FA5` |
| Tagesinfo-Band (Flaeche) | `#F4F3EC` |
| Tagesinfo-Text | `#5E5E57` |
| Hairline-Trenner zwischen Tagen | `#ECEBE4` |
| Fuehrungslinie (Verschachtelung) | `#ECEBE4` |
| Bullet-Punkt | `#C4C3BA` |
| Platzhalter im Leerzustand | `#B4B4AA` |
| Aufgabe offen (Kaestchen-Rahmen) | `#B7C6D6` |
| Erledigter Aufgabentext (durchgestrichen) | `#A6A69E` |
| Icon-Leiste inaktiv | `#8A8A83` |
| Icon-Leiste aktiv | `#24252A` |
| Panel-Kante (linke Kante des Overlays) | `#E7E6E1` (wie Rahmen) |

---

## 3. Typografie

- **Datumskopf, zweizeilig:** oben der Wochentag klein, grau, in Grossbuchstaben mit leichter Laufweite; darunter das grosse Datum (ca. 30 px, Schriftstaerke 500). Deutscher und waermer als Logseqs reines `2026/07/26`.
- **Getippter Text:** serifenlos, neutral-dunkel, ca. 15 px.
- **`#Tag`-Kopf (in der Gruppierung vergangener Tage):** der Tag im Akzentblau, kleiner und leiser als der Datumskopf — ein Zwischentitel, kein Konkurrent zum Datum.
- **Handschrift = echte M-Pencil-Tinte** (Vektorstriche aus dem Tinten-Modus). In den Entwuerfen nur durch eine Handschrift-Schriftart (Caveat) angedeutet — in der App steht dort die tatsaechliche Handschrift von Steffen. Der Unterschied getippt/handschriftlich traegt sich damit von selbst, ganz ohne zusaetzliche Deko.

---

## 4. Aufbau eines Tages im Journal

Der Kern von Disponere: Termine, Aufgaben und Tagesinfo tauchen automatisch am passenden Tag auf und sind ueber Tags verbunden. Das Journal laeuft **neu nach alt** (heute oben), zwischen zwei Tagen steht ein haarfeiner Hairline-Trenner.

**Der heutige Tag und vergangene Tage sind bewusst verschieden aufgebaut** — weil sie verschiedene Aufgaben haben. Heute ist Arbeitsflaeche zum Schreiben; die Vergangenheit ist die fertige Tagesgeschichte zum Nachlesen.

### 4a. Heute — freie Schreibflaeche

Der Grund fuer die ganze Ueberarbeitung: An vollen Tagen drueckten Tagesinfos, Termine und Aufgaben die eigenen Journal-Eintraege so weit nach unten, dass sie beim Oeffnen praktisch unsichtbar waren. Deshalb wird **heute** die Spalte freigeraeumt.

Reihenfolge heute von oben nach unten:

1. **Datumskopf** (zweizeilig).
2. **Tagesinfo-Band** — direkt unter dem Datum, ruhige, leicht getoente Flaeche. Mehrere Tagesinfos stehen **nebeneinander** (`Wrap`, nicht gestapelt); ab der vierten bricht es von selbst in eine zweite Zeile um.
3. **Deine Eintraege** — getippte Notizen und Tinte, **chronologisch** (keine `#Tag`-Cluster; der Schreibfluss soll ungeteilt bleiben).

**Termine und Aufgaben von heute stehen nicht in der Spalte**, sondern im **Seiten-Panel** (§5). Sie sind einen Tipp weit weg, aber nicht mehr im Weg. Das Tagesinfo-Band bleibt in der Spalte oben — nur Termine und Aufgaben wandern.

### 4b. Vergangene Tage — die fertige Tagesgeschichte

Hier zaehlt Vollstaendigkeit, nicht Schreibraum. Termine und Aufgaben bleiben **inline im Journal** — das „Auftauchen am richtigen Tag" ist Teil der Seele der App und bleibt fuer die Vergangenheit erhalten. Zusaetzlich wird der Tag nach `#Tag` gruppiert, damit sich die Tagesgeschichte nach Thema wie ein Strang liest.

Reihenfolge an einem vergangenen Tag von oben nach unten:

1. **Datumskopf** (zweizeilig).
2. **Tagesinfo-Band** (nebeneinander wie oben).
3. **Tag-lose Notizen** — deine Eintraege ohne `#Tag` stehen **oben, chronologisch**, noch vor den Clustern. Bewusst so: die eigenen freien Notizen bleiben vorn, und das leise Fehlen eines Tags draengt sanft dazu, sie spaeter mit einem `#Tag` zu versehen.
4. **`#Tag`-Cluster** — je ein Block pro Tag, mit `#Tag`-Kopf (Akzentblau). Die Cluster sind **nach der ersten Uhrzeit** des jeweiligen Tags geordnet, sodass der Tag grob dem zeitlichen Verlauf folgt. Innerhalb eines Clusters chronologisch (vorlaeufig; bei der Umsetzung feinjustierbar).

**Mehrfach-Auftauchen ist gewollt.** Ein Element mit mehreren Tags (z. B. eine Aufgabe `#MBS #Waerme`) erscheint **unter jedem seiner Tags**. So werden die Schnittstellen sichtbar — und Schnittstellen sind der Normalfall, nicht die Ausnahme (Disponere selbst ist voll davon: die Kalender-Anbindung ist `#Disponere` *und* `#GoogleCalendar` usw.). Es ist stets **dasselbe** Element: dieselbe Karte, dieselben Chips der uebrigen Tags. Das Abhaken einer Aufgabe streicht **alle** ihre Vorkommen gleichzeitig durch — technisch dadurch, dass nach dem Abhaken aus dem Repository neu aufgebaut wird, nicht aus einer zwischengespeicherten Widget-Kopie. Keine Sync-Logik noetig.

Feine Fuehrungslinien links zeigen die Verschachtelung. Das ist der Kern, den Logseq so nicht hat.

---

## 5. Seiten-Panel — Heute-Agenda

Das Panel haelt die Journalspalte **heute** frei, ohne die Termine und Aufgaben zu verstecken.

- **Inhalt:** die Agenda von **heute** — Termine (mit Uhrzeit) und Aufgaben (offen und erledigt).
- **Fest auf heute:** Das Panel zeigt immer den heutigen Tag, **unabhaengig von der Scrollposition** im Journal. Scrollst du zu einem vergangenen Tag, aendert sich das Panel nicht (dessen Agenda steht ja inline, §4b).
- **Auslöser:** der **Sidebar-Umschalter oben rechts** (§9).
- **Erscheinung — Overlay ueberall:** Das Panel schiebt sich in **beiden** Lagen (Hoch- und Querformat) gleich von rechts ueber das Journal — ein einziger Layout-Pfad. „Verlaesslichkeit vor Bastelei": robust und schlicht, kein Andocken, keine zweite Spalten-Logik. Solange es offen ist, verdeckt es den rechten Teil des Journals; Agenda anschauen oder schreiben, nicht beides zugleich.
- **Standardzustand: geschlossen.** Beim App-Start ist der Schreibraum frei. Am Umschalter sitzt eine leise **Zahl** (Badge, Akzentblau) mit der Anzahl der heutigen Agenda-Punkte (Termine + offene Aufgaben), damit man sieht, dass etwas wartet, ohne dass es im Weg ist.
- **Arbeits-Panel — nur Abhaken.** Eine Aufgabe laesst sich **direkt im Panel abhaken**: das Kaestchen fuellt sich blau, der Text wird grau und durchgestrichen. Dieselbe Aufgabe im Journal streicht sich mit (Repository-Neuaufbau). **Kein** Springen ins Journal, **kein** Oeffnen von Terminen — bewusst weggelassen, damit das Panel schlank und robust bleibt. Das Bearbeiten lebt weiter im Journal und in der Aufgaben-Uebersicht.
- **Leerfall:** Kein Termin, keine Aufgabe heute → das Panel zeigt still *„Heute nichts geplant"*, und am Umschalter steht keine Zahl.
- **Tageswechsel:** Weil die Agenda immer *heute* zeigt, muss sie sich beim Datumssprung ueber Mitternacht **und** beim App-Resume **neu laden** — sonst haengen die Daten des Vortags nach. Gilt genauso fuer den Datumskopf und die inline auftauchenden Elemente des heutigen Tages.

---

## 6. Auftauchende Elemente und ihre Marker

- **Termin (Kalender):** blaues Kalender-Icon + Uhrzeit.
- **Aufgabe offen:** leeres Kaestchen (Rahmen im gedaempften Blau).
- **Aufgabe erledigt:** blau gefuelltes Kaestchen mit weissem Haekchen, Text grau und durchgestrichen.
- **Tagesinfo:** Info-Icon im getoenten Band oben.
- **Journal-Eintrag getippt:** neutrale serifenlose Schrift.
- **Journal-Eintrag handschriftlich:** Tinte (echte Handschrift).

Erscheint ein Element mehrfach (mehrere Tags, §4b), traegt jedes Vorkommen denselben Marker und dieselbe Karte — es ist erkennbar dasselbe Element.

---

## 7. Leerer Heute-Zustand

Ein frischer Tag ohne Inhalt zeigt nur: Datumskopf, einen **wartenden Punkt**, einen **blauen Cursor** (im Akzentblau) und einen leisen Platzhalter *„Tippen oder mit dem Stift schreiben …"*.

*Zur Praxis offen:* Ob der Platzhalter-Text bleibt oder es ganz bar wird (nur Punkt + Cursor, wie Logseq). Vorerst: Platzhalter behalten.

---

## 8. Tag-Ansicht (der Kick)

Das Gegenstueck zu Logseqs „Linked References" — und das, worum es Steffen geht. *(Umgesetzt in Session 31; hier als Design-Referenz gehalten.)*

- **Einstieg:** Tippen auf ein beliebiges blaues `#Tag`, egal wo (Journal, Aufgabe, ueberall).
- **Kopf:** der Tag selbst im Akzentblau — dieselbe grosse, ruhige Kopfzeile wie ein Datum, nur eben ein Tag. Darunter leise ein Zaehler, z. B. „4 Eintraege · zuletzt heute".
- **Inhalt:** alles, was zu diesem Tag gehoert — getippte Eintraege, handschriftliche Notizen, Aufgaben (inkl. Status), Termine, Tagesinfo — nach Tagen gruppiert.
- **Richtung:** **neu nach alt** (das Aktuelle zuerst, passend zum Journal).
- **Zurueck:** Pfeil oben links.

Ein Tag, ein Strang, die ganze Geschichte auf einen Blick.

---

## 9. Navigation und Icon-Leiste

**Untere Leiste — vier Icons, auf Disponere zugeschnitten** (kein Logseq-Nachbau; das Mikro ist raus, weil Sprachaufnahme kein Feature ist):

1. **Journal / heute** (Buch)
2. **Suche** (Lupe) — die Volltextsuche
3. **Aufgaben** (Kaestchen) — die Aufgaben-Uebersicht
4. **Neuer Eintrag** (Stift)

**Oben rechts:** Funkel-Symbol (Claude-Funktionen) und **Sidebar-Umschalter** — Letzterer oeffnet das Heute-Panel (§5) und traegt das Zahl-Badge.
**Oben links:** Menue.

*Zur Praxis offen:* Ob die Navigation dauerhaft unten sitzt. Vorerst ja — die Praxis zeigt, ob es sich gut anfuehlt.

---

## 10. Offene Punkte (bewusst der Praxis ueberlassen)

- Navigation unten vs. woanders.
- Tagesinfo-Band oben vs. an anderer Stelle.
- Platzhalter-Text im Leerzustand behalten oder streichen.
- Reihenfolge **innerhalb** eines `#Tag`-Clusters an vergangenen Tagen (vorlaeufig chronologisch) — feinjustierbar bei der Umsetzung.

Diese sind bewusst nicht endgueltig festgelegt; sie entscheiden sich beim taeglichen Gebrauch.

---

## 11. Spaetere Versionen (nicht v1.0)

- **Tag-Kategorien** — `#Tags` in Kategorien ordnen. Erst eine spaetere Version; hier nur als gesetzte Idee vermerkt, damit sie nicht verloren geht. Beruehrt das v1.0-Layout nicht.
- **Deduplizierung gleicher Termine** — sobald ein zweiter Kalender dazukommt, kann derselbe Termin von zwei Kalendern getragen werden und damit zweimal (mit zwei Tags) erscheinen. Dafuer ist das `iCalUID`-Feld reserviert. Heute kein Thema, aber der Moment, ab dem es eins wird.

---

## 12. Naechster Schritt

Umsetzung in Flutter in einer eigenen Coding-Session, in dieser Reihenfolge:

1. **Seiten-Panel (Heute-Agenda)** — loest das Dringende (Zuschuetten heute). Overlay von rechts, Badge, Abhaken; Termine + Aufgaben aus der heutigen Spalte nehmen. **Dabei mitfixen:** Tageswechsel-Reload der Heute-Daten (Tagesinfo/Termine/Aufgaben) bei Resume und Datumssprung — die Daten werden bislang nur in `initState` geladen und haengen sonst vom Vortag nach.
2. **`#Tag`-Gruppierung auf vergangenen Tagen** — tag-lose Notizen oben, Cluster nach erster Uhrzeit, Mehrfach-Auftauchen.
3. **Kleiner Change:** Tagesinfo nebeneinander (`Wrap`).

In dieser Design-Session wurde bewusst kein Code geschrieben.

---
