# Disponere — Design-Grundlagen (helles Theme)

*Referenzdokument. Hält die visuellen Grundentscheidungen fest. Wird selten geaendert — nur wenn sich das Erscheinungsbild grundlegend aendert.*

**Version 1.0 — 26. Juli 2026**
**Status:** Entwurf bestaetigt. Noch nicht in Flutter umgesetzt (reine Design-Session, kein Code).

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
| **Akzentblau** (Tags, Cursor, Kalender-Icon, Aufgaben-Haekchen, aktives Icon) | `#185FA5` |
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

---

## 3. Typografie

- **Datumskopf, zweizeilig:** oben der Wochentag klein, grau, in Grossbuchstaben mit leichter Laufweite; darunter das grosse Datum (ca. 30 px, Schriftstaerke 500). Deutscher und waermer als Logseqs reines `2026/07/26`.
- **Getippter Text:** serifenlos, neutral-dunkel, ca. 15 px.
- **Handschrift = echte M-Pencil-Tinte** (Vektorstriche aus dem Tinten-Modus). In den Entwuerfen nur durch eine Handschrift-Schriftart (Caveat) angedeutet — in der App steht dort die tatsaechliche Handschrift von Steffen. Der Unterschied getippt/handschriftlich traegt sich damit von selbst, ganz ohne zusaetzliche Deko.

---

## 4. Aufbau eines Tages im Journal

Reihenfolge von oben nach unten:

1. **Datumskopf** (zweizeilig).
2. **Tagesinfo-Band** — direkt unter dem Datum, als ruhige, leicht getoente Flaeche. Was fuer den ganzen Tag gilt oder zu beachten ist, gehoert an den Anfang.
3. **Auftauchende Eintraege** — Termine, Aufgaben und Notizen, die am richtigen Tag von selbst erscheinen, ueber **Tags** gruppiert. Feine Fuehrungslinien links zeigen die Verschachtelung.

Zwischen zwei Tagen steht ein haarfeiner Hairline-Trenner. Das Journal laeuft **neu nach alt** (heute oben).

Das ist der Kern, den Logseq so nicht hat: Termine, Aufgaben und Tagesinfo tauchen automatisch am passenden Tag auf und sind ueber Tags verbunden.

---

## 5. Auftauchende Elemente und ihre Marker

- **Termin (Kalender):** blaues Kalender-Icon + Uhrzeit.
- **Aufgabe offen:** leeres Kaestchen (Rahmen im gedaempften Blau).
- **Aufgabe erledigt:** blau gefuelltes Kaestchen mit weissem Haekchen, Text grau und durchgestrichen.
- **Tagesinfo:** Info-Icon im getoenten Band oben.
- **Journal-Eintrag getippt:** neutrale serifenlose Schrift.
- **Journal-Eintrag handschriftlich:** Tinte (echte Handschrift).

---

## 6. Leerer Heute-Zustand

Ein frischer Tag ohne Inhalt zeigt nur: Datumskopf, einen **wartenden Punkt**, einen **blauen Cursor** (im Akzentblau) und einen leisen Platzhalter *„Tippen oder mit dem Stift schreiben …"*.

*Zur Praxis offen:* Ob der Platzhalter-Text bleibt oder es ganz bar wird (nur Punkt + Cursor, wie Logseq). Vorerst: Platzhalter behalten.

---

## 7. Tag-Ansicht (der Kick)

Das Gegenstueck zu Logseqs „Linked References" — und das, worum es Steffen geht.

- **Einstieg:** Tippen auf ein beliebiges blaues `#Tag`, egal wo (Journal, Aufgabe, ueberall).
- **Kopf:** der Tag selbst im Akzentblau — dieselbe grosse, ruhige Kopfzeile wie ein Datum, nur eben ein Tag. Darunter leise ein Zaehler, z. B. „4 Eintraege · zuletzt heute".
- **Inhalt:** alles, was zu diesem Tag gehoert — getippte Eintraege, handschriftliche Notizen, Aufgaben (inkl. Status), Termine, Tagesinfo — nach Tagen gruppiert.
- **Richtung:** **neu nach alt** (das Aktuelle zuerst, passend zum Journal).
- **Zurueck:** Pfeil oben links.

Ein Tag, ein Strang, die ganze Geschichte auf einen Blick.

---

## 8. Navigation und Icon-Leiste

**Untere Leiste — vier Icons, auf Disponere zugeschnitten** (kein Logseq-Nachbau; das Mikro ist raus, weil Sprachaufnahme kein Feature ist):

1. **Journal / heute** (Buch)
2. **Suche** (Lupe) — die Volltextsuche
3. **Aufgaben** (Kaestchen) — die Aufgaben-Uebersicht
4. **Neuer Eintrag** (Stift)

**Oben rechts:** Funkel-Symbol (Claude-Funktionen) und Sidebar-Umschalter.
**Oben links:** Menue.

*Zur Praxis offen:* Ob die Navigation dauerhaft unten sitzt. Vorerst ja — die Praxis zeigt, ob es sich gut anfuehlt.

---

## 9. Offene Punkte (bewusst der Praxis ueberlassen)

- Navigation unten vs. woanders.
- Tagesinfo-Band oben vs. an anderer Stelle.
- Platzhalter-Text im Leerzustand behalten oder streichen.

Diese drei sind bewusst nicht endgueltig festgelegt; sie entscheiden sich beim taeglichen Gebrauch.

---

## 10. Naechster Schritt

Umsetzung in Flutter (Theme + Widgets) in einer eigenen Coding-Session. In dieser Design-Session wurde bewusst kein Code geschrieben.

---
