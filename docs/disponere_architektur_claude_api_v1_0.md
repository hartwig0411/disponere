# Disponere – Architektur: Claude-API-Anbindung

**Dokument-Revision:** v1.0 (in-place gepflegt)
**Status:** Architektur-Session abgeschlossen (Session 23, 23.07.2026) — Coding-Session folgt
**Erfüllt:** Anforderungen v3.0 → *Claude-Integration* (🟡 Core)
**Vorgänger-Commit (Code):** `6386e2c` — TERMINE-Sektion im Journal
**Nachgelagert:** Coding-Session C, Teil 1 (Key, Service, Tinten-Auswertung, Schema v6) + Teil 2 (Wochenauswertung, Suche)

---

## 1. Zweck & Einordnung

Die Claude-Anbindung erfüllt in v1.0 **genau zwei** Funktionen. Beide werden **vom Nutzer ausgelöst**,
beide liefern ein Ergebnis, das der Nutzer **liest und bewusst übernimmt**:

1. **Tinten-Auswertung** — ein handschriftlicher Eintrag wird als Bild an die multimodale API
   geschickt und kommt als Text zurück. Der Text wird neben der Tinte gespeichert; die Tinte
   selbst bleibt unverändert das Original.
2. **Wochenauswertung** — eine Kalenderwoche (Mo–So) wird zusammengefasst und
   ausgewertet, angelehnt an die Plaud-Vorlagen.

**Leitsatz aus Session 22:** *Claude spricht nie ungefragt ins Journal.* Es gibt keine
Hintergrundverarbeitung, keine automatischen Tag-Vorschläge, keine stille Anreicherung von
Einträgen. Jeder API-Aufruf hat einen Knopfdruck als Ursache und ein sichtbares Ergebnis als Folge.

Aus (1) folgt eine dritte Funktion, die ohne Netz auskommt: die **lokale Suche**. Ohne sie wäre
der erkannte Text zwar gespeichert, aber unauffindbar — siehe §9.

---

## 2. Randbedingungen

- **Öffentliches Repository.** Kein Schlüssel, kein Token, keine Konfiguration mit Geheimnissen
  im Code. Wer Disponere baut, trägt seinen eigenen API-Schlüssel ein.
- **HMS Core, kein GMS.** Für die Claude-Anbindung unkritisch: reines HTTPS gegen
  `api.anthropic.com`, kein SDK, keine Play-Services-Abhängigkeit. Es wird **kein neues Paket**
  gebraucht — `http` und `flutter_secure_storage` liegen bereits im Projekt.
- **Netzabhängigkeit.** Beide Funktionen brauchen Netz. Ohne Netz bleibt die App vollständig
  benutzbar; nur die beiden Knöpfe melden einen Fehler. Die Suche funktioniert offline.
- **Einzelnutzer-App.** Der Nutzer ist der Eigentümer des Schlüssels. Daraus folgt die
  Secrets-Entscheidung in §10.

---

## 3. Getroffene Entscheidungen

| # | Entscheidung | Wahl | Begründung |
|---|---|---|---|
| 1 | **Schlüssel-Ablage** | `flutter_secure_storage` (Android Keystore), Eingabe über einen Einstellungs-Screen | Paket bereits im Projekt (hält die Google-Tokens). Öffentliches Repo → Schlüssel darf nirgends im Code liegen. |
| 2 | **Direktaufruf statt Proxy** | Gerät ruft `api.anthropic.com` unmittelbar | Bei einer Einzelnutzer-App ist der Nutzer der Schlüssel-Eigentümer. Ein Proxy würde einen Server einführen, den es nicht gibt und nicht geben soll. Bewusste Entscheidung, siehe §10. |
| 3 | **Modell** | `claude-sonnet-5`, als **eine Konstante** im Service | Handschrift ist die anspruchsvollere Aufgabe; ein kleineres Modell wäre dort das falsche Sparen. Nicht in den Einstellungen konfigurierbar — eine falsch getippte Modell-ID ist ein 404. |
| 4 | **Bildaufbereitung** | Offscreen-Render aus `InkData` über `PictureRecorder`, **schwarz auf weiß**, lange Kante ≤ 1568 px | Der Renderer erzeugt eine eigene Darstellung *für die Erkennung*, keinen Screenshot der Anzeige — deshalb unabhängig vom Theme. Größere Bilder werden serverseitig heruntergerechnet; man zahlte für Pixel, die niemand sieht. |
| 5 | **Ergebnis-Ablage** | Neue Spalten `ink_text` / `ink_text_at` auf `entries` (**Schema v6**) — **nicht** in `content` | `content` ist, was der Nutzer geschrieben hat; `ink_text`, was die Maschine geraten hat. Diese Grenze zu verwischen wäre in einem Journal die falsche Sparsamkeit. |
| 6 | **Landeplatz der Wochenauswertung** | Erst Anzeige-Screen, dann **Übernahme per Knopf** als Eintrag mit Tag `#Wochenauswertung` | Direkte Folge des Leitsatzes aus §1. Kein automatischer Schreibzugriff aufs Journal. |
| 7 | **Zeitfenster der Wochenauswertung** | Kalenderwoche Mo–So; **ab Freitag 12:00 die laufende**, davor die vorige. Dazu ein **Pfeil „eine Woche zurück"** | Am Freitagmittag ist die Woche faktisch gelaufen — bis Montag zu warten wäre unbrauchbar. Der Pfeil deckt Nachholen nach Urlaub oder Unterbrechung ab; das Fenster wird ohnehin berechnet, der Pfeil zieht nur einen Wert ab. |
| 8 | **Suche** | Minimal-Suche in v1.0 über `content` **und** `ink_text`, Filterung **in Dart** | Ohne Suche ist der erkannte Text gespeichert, aber unauffindbar. Filterung in Dart wegen Umlauten — Begründung in §9. |

---

## 4. Datenfluss

**Einseitig, angefordert, quittiert.**

```
Tinten-Auswertung:
  InkData (SQLite) → Renderer → PNG → base64 → API
                                              ↓
                     entries.ink_text ← Anzeige ← Antwort

Wochenauswertung:
  Journal + Aufgaben + Tagesinfo + Termine (eine KW) → Text → API
                                                             ↓
              neuer Eintrag #Wochenauswertung ← [Knopf] ← Anzeige ← Antwort
```

Nichts davon läuft im Hintergrund. Es gibt keinen Zeitplan, keinen Auslöser außer dem Knopfdruck
und keinen Schreibzugriff ohne vorherige Anzeige.

---

## 5. Datenmodell (Schema v6)

Zwei neue Spalten auf der bestehenden `entries`-Tabelle:

```sql
ALTER TABLE entries ADD COLUMN ink_text    TEXT;  -- erkannter Text; NULL = nie ausgewertet
ALTER TABLE entries ADD COLUMN ink_text_at TEXT;  -- ISO-Zeitstempel der Auswertung
```

Migration analog zu den bisherigen Stufen, idempotent gedacht:

```dart
if (oldVersion < 6) {
  await _addInkTextColumns(db);
}
```

`_onCreate` legt die Spalten direkt in der `CREATE TABLE entries` mit an, damit Neuinstallation und
Migration dasselbe Schema erzeugen — dasselbe Muster wie bei `daily_info` und den Kalendertabellen.

**Semantik der beiden Spalten:**

| Zustand | Bedeutung |
|---|---|
| `ink_text IS NULL` | Nie ausgewertet. Knopf zeigt „Auswerten". |
| `ink_text` gesetzt | Ausgewertet. Knopf zeigt „Erneut auswerten"; `ink_text_at` zeigt, wann. |
| Erneute Auswertung | Überschreibt beide Spalten. Die Tinte selbst wird nie verändert. |

`ink_text` ist in v1.0 **nicht editierbar** — es ist ein Maschinenergebnis mit Zeitstempel, kein
Nutzertext. Korrigierbarkeit ist als 🟢 vorgemerkt (§14).

**Repository-Methoden:**

```dart
Future<void> setInkText(String entryId, String text);   // + ink_text_at = jetzt
Future<List<JournalEntry>> searchEntries(String query); // siehe §9
```

---

## 6. Tinten-Renderer

Neue Datei `lib/utils/ink_renderer.dart`. Kein Widget, keine `RepaintBoundary` — der Eintrag soll
auswertbar sein, **ohne dass sein Editor offen ist**.

```
InkData (Striche + Canvas-Maße)
  → Skalierungsfaktor bestimmen (lange Kante → max. 1568 px)
  → ui.PictureRecorder + Canvas
  → weißer Hintergrund füllen
  → Striche schwarz zeichnen (Zeichenlogik aus InkPainter, Koordinaten skaliert)
  → Picture.toImage(w, h)
  → toByteData(format: ImageByteFormat.png)
  → base64Encode
```

**Festlegungen:**

- **Schwarz auf weiß**, unabhängig vom App-Theme. Das Theme wurde in Session 22 auf hell
  entschieden — der Renderer bleibt trotzdem theme-unabhängig, damit ein späterer Theme-Wechsel
  die Erkennung nicht beeinflusst.
- **Strichbreite skaliert mit**, **Untergrenze 2 px**. Zu dünne Striche nach dem Verkleinern sind
  der eigentliche Erkennungskiller — deutlich eher als eine zu geringe Auflösung.
- **Eine Seite pro Eintrag.** Der Zeichenbereich ist `Expanded` + `SizedBox.expand()`, also fest und
  nicht scrollbar. Es gibt keine Mehrseitigkeit, kein Zusammensetzen von Teilbildern.
- Wird nur **hochskaliert, wenn nötig** — kleine Zeichnungen werden nicht künstlich aufgeblasen.

---

## 7. Tinten-Auswertung — Ablauf

**Aufruf:**

```
POST https://api.anthropic.com/v1/messages
Header: x-api-key: <Schlüssel>
        anthropic-version: 2023-06-01
        content-type: application/json

Body:   model, max_tokens,
        messages: [ { role: "user", content: [
            { type: "image", source: { type: "base64",
                                       media_type: "image/png",
                                       data: <base64> } },
            { type: "text", text: <Transkriptions-Prompt> }
        ] } ]
```

**Prompt-Richtung** (Feinschliff in der Coding-Session): Handschrift transkribieren, **nur den Text**
zurückgeben, keine Einleitung und keinen Kommentar, Unleserliches als `[?]` markieren, Zeilenumbrüche
der Vorlage erhalten.

**Ablauf in der UI:**

1. Nutzer öffnet einen Tinten-Eintrag, tippt das Auswerten-Symbol in der Kopfzeile.
2. Ladeanzeige, Aufruf, Zeitlimit 60 s.
3. Ergebnis erscheint **als Vorschau**, darunter „Übernehmen" und „Verwerfen".
4. Bei „Übernehmen" → `setInkText()`, Spalten gesetzt, Eintrag ist ab sofort auffindbar.
5. Bei „Verwerfen" → **nichts wird geschrieben**, kein halber Zustand.

Auch hier gilt der Leitsatz: gelesen und bewusst übernommen.

---

## 8. Wochenauswertung — Umfang

**Zeitfenster:** eine Kalenderwoche, **Montag 00:00 bis Sonntag 23:59** (Entscheidung 7).

Welche Woche vorgeschlagen wird, hängt vom Zeitpunkt des Aufrufs ab:

| Aufruf | Vorgeschlagenes Fenster |
|---|---|
| **Freitag ab 12:00** bis Sonntag 23:59 | die **laufende** Woche, Montag 00:00 bis zum Aufrufzeitpunkt |
| Montag 00:00 bis **Freitag 11:59** | die **vorige** Woche, Montag bis Sonntag |

Begründung: Am Freitagmittag ist die Arbeitswoche faktisch gelaufen — bis Montag warten zu müssen,
wäre unbrauchbar. Wer die Auswertung erst am Montag macht, bekommt dieselbe Woche, nur vollständig
inklusive Wochenende.

**Pfeil „eine Woche zurück".** Im Kopf des Screens sitzen zwei Pfeile, mit denen das Fenster
wochenweise verschoben wird. Vorwärts ist bei der automatisch vorgeschlagenen Woche gedeckelt —
es gibt nichts auszuwerten, was noch nicht stattgefunden hat. Das deckt das Nachholen nach Urlaub
oder Unterbrechung ab, ohne eine Datumsauswahl einzuführen.

Der Screen nennt das ausgewertete Fenster **im Kopf mit Datum** („KW 30 · 20.07.–26.07."), damit
nie Zweifel besteht, worüber gerade geredet wird — besonders wenn zurückgeblättert wurde.

**In den Request geht:**

| Quelle | Umfang |
|---|---|
| Journal-Einträge | `content`, plus `ink_text` wo vorhanden — Tinte ohne Auswertung fließt nicht ein |
| Aufgaben | im Fenster fällige und erledigte, mit Tags |
| Tagesinfo | die Einträge der Woche |
| Kalendertermine | Titel und Zeit — kosten fast nichts und liefern den Rahmen, in dem die Woche stattgefunden hat |

Alles wird zu **einem Text** zusammengestellt, nach Tagen gegliedert, Tags erhalten. Die Tags sind
für die Auswertung die eigentliche Struktur — sie zeigen, worauf die Woche verteilt war.

**Prompt:** angelehnt an die Plaud-Vorlagen. Reine Textarbeit, wird in der Coding-Session festgelegt
und lebt als Konstante in `claude_prompts.dart`, damit sie ohne Eingriff in die Logik änderbar ist.

**Ergebnis:** Anzeige-Screen mit „Ins Journal übernehmen" (→ Eintrag von heute, Tag
`#Wochenauswertung`) und „Verwerfen". Zeitlimit 120 s.

---

## 9. Suche (v1.0, Minimalumfang)

Ohne Suche wäre §7 eine Funktion, die Text erzeugt, den niemand wiederfindet. Deshalb gehört die
Suche in denselben Zug — aber in klar begrenztem Umfang.

**Umfang:** Suchfeld im Journal, Volltext über `entries.content` **und** `entries.ink_text`,
Trefferliste nach Zeitstempel absteigend, Tippen springt zum Eintrag. Treffer, die aus `ink_text`
stammen, werden als solche **markiert** — es macht einen Unterschied, ob der Fund im eigenen Text
oder in einer Maschinenerkennung steht.

**Kein** Ranking, **keine** Tag-Filter, **keine** Trefferhervorhebung im Text. Aufgaben, Tagesinfo
und Termine bleiben in v1.0 außerhalb der Suche (§14).

**Die Umlaut-Falle — und warum in Dart gefiltert wird:**

SQLites `LIKE` und `LOWER()` sind **ASCII-only**. `WHERE LOWER(content) LIKE '%über%'` findet
„Über" **nicht**, weil SQLite das große Ü nicht kleinschreiben kann. Bei deutschen Texten ist das
kein Randfall, sondern der Normalfall.

Das Projekt löst das an anderer Stelle bereits richtig: `tag_key` wird in **Dart** mit
`toLowerCase()` normalisiert, nicht in SQL. Die Suche folgt demselben Weg:

```dart
// Kandidaten laden, in Dart filtern — toLowerCase() kann Umlaute.
final rows = await db.query('entries',
    columns: ['id', 'timestamp', 'content', 'ink_text'],
    orderBy: 'timestamp DESC');
final q = query.toLowerCase();
final hits = rows.where((r) =>
    (r['content']  as String?)?.toLowerCase().contains(q) == true ||
    (r['ink_text'] as String?)?.toLowerCase().contains(q) == true);
```

Bei einem persönlichen Journal in der Größenordnung einiger tausend Einträge ist das
unproblematisch — es werden nur vier Spalten geladen, keine Tinte. Sollte es je spürbar werden,
ist der Ausbauweg eine mitgeführte, in Dart normalisierte Suchspalte; das ist eine Migration und
kein Umbau. Vorgemerkt, nicht gebaut.

---

## 10. Secrets & Sicherheit

- **Schlüssel** im Keystore über `flutter_secure_storage`, Schlüsselname `anthropic_api_key`.
  Nicht in SQLite, nicht in `shared_preferences`, nicht in einer Konfigurationsdatei.
- **Eingabe** über den Einstellungs-Screen, verdecktes Feld, Einfügen aus der Zwischenablage.
  Einen hundertstelligen Schlüssel auf dem MatePad abzutippen ist keine zumutbare Bedienung.
- **„Verbindung testen"** schickt einen minimalen Request und meldet nur, ob der Schlüssel
  akzeptiert wurde. So scheitert die Einrichtung sichtbar und nicht erst beim ersten echten Aufruf.
- **„Schlüssel löschen"** entfernt ihn aus dem Keystore.
- **Der Schlüssel wird nie protokolliert** — nicht in `debugPrint`, nicht in Fehlermeldungen,
  nicht in Screens. Fehlerdialoge zeigen Statuscode und API-Meldung, nie den Request-Header.

**Zur Einordnung, ausdrücklich festgehalten:** Die verbreitete Warnung „niemals API-Schlüssel in
Client-Apps" zielt auf verteilte Apps mit fremden Nutzern, deren Aufrufe auf **Kosten des
Herausgebers** laufen. Hier ist der Nutzer der Schlüssel-Eigentümer und trägt seine eigenen Kosten.
Der Direktaufruf ist damit eine bewusste, begründete Entscheidung — kein übersehenes Risiko.
Für ein öffentliches Repo heißt das: Jeder, der Disponere baut, trägt seinen eigenen Schlüssel ein.

---

## 11. Fehlerverhalten

| Fall | Verhalten |
|---|---|
| Kein Schlüssel hinterlegt | Dialog mit Hinweis und direktem Weg in die Einstellungen |
| Kein Netz / Zeitüberschreitung | SnackBar; **nichts wird gespeichert**; erneuter Versuch = zweiter Knopfdruck |
| 401 / 403 | Dialog „Schlüssel wurde abgelehnt" + Weg in die Einstellungen |
| 429 (Rate Limit) | Dialog mit Hinweis, später erneut versuchen |
| 5xx / unerwartete Antwort | Dialog mit Statuscode und API-Meldung — **nicht** verschlucken |
| Leere oder unbrauchbare Antwort | Als Fehler behandeln, nicht als leeres Ergebnis speichern |

**Grundregel:** Ein fehlgeschlagener Aufruf hinterlässt **keinen Zustand**. Es gibt keine halb
ausgewerteten Einträge, keine leeren `ink_text`-Spalten, keine Wiederaufnahme-Logik. Der zweite
Versuch beginnt bei null.

Kein Kostenlimit, kein Aufruf-Zähler in v1.0: Einzelnutzer, manuell ausgelöst, überschaubar.

---

## 12. UI-Einstiegspunkte

| Funktion | Ort |
|---|---|
| Tinten-Auswertung | Symbol in der Kopfzeile des Tinten-Editors — der Eintrag ist dort ohnehin offen, kein Konflikt mit Gesten auf der Karte |
| Wochenauswertung | Überlauf-Menü (⋮) des Journals |
| Claude-Einstellungen | Überlauf-Menü (⋮) des Journals, neben den Kalender-Einstellungen |
| Suche | Suchsymbol in der Kopfzeile des Journals |

---

## 13. Schnitt in Coding-Sessions

**Coding-Session C, Teil 1 — Grundlage und Tinte**

1. `claude_settings_screen.dart` — Schlüssel speichern, löschen, Verbindung testen
2. `claude_service.dart` — Schlüsselzugriff, HTTP, Fehlerabbildung, Modell-Konstante
3. `ink_renderer.dart` — `InkData` → PNG → base64
4. **Schema v6** — Migration, `setInkText()`
5. Auswerten-Symbol im Tinten-Editor, Vorschau mit Übernehmen/Verwerfen

→ Auf dem MatePad testbar: Schlüssel eintragen, Tinten-Eintrag auswerten, Text erscheint.

**Coding-Session C, Teil 2 — Wochenauswertung und Suche**

6. Kontext-Zusammenstellung einer KW Mo–So (Einträge, Aufgaben, Tagesinfo, Termine) + Fensterlogik Freitag 12:00 + Wochenpfeile
7. `claude_prompts.dart`, Anzeige-Screen, Übernahme als `#Wochenauswertung`
8. `searchEntries()` + Such-Screen mit Herkunftsmarkierung der Treffer

---

## 14. Nicht v1.0 (Abgrenzung)

- **Automatische Tag-Vorschläge** durch Claude — widerspricht dem Leitsatz aus §1
- **Hintergrund- oder Stapelauswertung** aller Tinten-Einträge auf einmal
- **Korrigierbarkeit von `ink_text`** — 🟢, mit der Folgefrage, was eine erneute Auswertung dann
  mit der Korrektur macht
- **Suche über Aufgaben, Tagesinfo, Termine** — 🟢
- **Trefferhervorhebung, Ranking, Tag-Filter in der Suche** — 🟢
- **Normalisierte Suchspalte** — erst wenn die Dart-Filterung spürbar wird (§9)
- **Chat mit dem eigenen Journal** („Fragen an den eigenen Wissensstand") — reizvoll, aber ein
  eigenes Konzept und nicht in acht Tagen
- **Auswertung frei wählbarer Zeiträume** (Monat, Tag-gefiltert, Datumsauswahl) — 🟢; wochenweises Blättern ist über die Pfeile abgedeckt
- **Perlenkette-Erkennung durch Claude** — bleibt v2.0

---

## 15. Beim Coden zu prüfen

- **Modell-ID** und **aktuelle Preise** gegen die Dokumentation abgleichen, bevor die Konstante
  festgeschrieben wird
- **Token-Kosten des Bildes** in der Größenordnung gegenprüfen und den Skalierungswert (1568 px)
  bestätigen oder anpassen
- **Erkennungsqualität** auf echter Handschrift: Wenn die Ergebnisse enttäuschen, ist die
  Strichbreite der erste Stellhebel, die Auflösung der zweite

---

*Architektur-Session vom 23.07.2026 (Session 23). Code-Stand bei Erstellung: `6386e2c`.*
