# Disponere — Ideen-Eingang
### Landezone für neue Ideen vor der Triage
*Version 1.0*
*Stand: 13. August 2026*

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

*— noch keiner —*

---

## Verworfen (Gedächtnis)

*— noch keiner —*

---

*Eingang = Arbeitsfläche · Anforderungsdokument = settled record.*
