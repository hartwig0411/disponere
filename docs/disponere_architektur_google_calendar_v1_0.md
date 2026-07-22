# Disponere – Architektur: Google Calendar-Anbindung

**Dokument-Revision:** v1.0 (in-place gepflegt)
**Status:** Coding-Session A, Teil 1 abgeschlossen (Auth/PKCE, „In Produktion" umgestellt) — Teil 2 folgt
**Erfüllt:** Anforderungen v3.0 → *Google Calendar-Anbindung* (🟡 Core) und Kernkonzept 2
(*Termine erscheinen automatisch als vor-getaggte Einträge mit Zeitstempel*)
**Nachgelagert:** Coding-Session A Teil 2 (Schema, Kalenderliste, Tag-Mapping) + Session B (Sync + Einblendung)

---

## 1. Zweck & Einordnung

Google-Kalendertermine sollen **automatisch am richtigen Day im Journal** erscheinen, **vor-getaggt**
über eine einmal eingerichtete Kalender→Tag-Zuordnung. Der Datenfluss ist **einseitig**:
Kalender → Journal. Kein Zurückschreiben nach Google.

Termine müssen zudem **nach Tag abfragbar** sein — das ist die Voraussetzung der Perlenkette (v2.0),
die „Journal-Einträge, Kalendertermine, fällige Aufgaben" zu einem Tag über einen Zeitraum vereint.

---

## 2. Zentrale Randbedingung — „HMS Core, kein Google"

Das Zielgerät (MatePad MRDI-W09) läuft **ohne Google Play Services**. Das ist kein Widerspruch zur
Google-Calendar-Anbindung, wenn sauber getrennt wird:

- **Google-frei bleibt das Gerät.** Keine GMS-Abhängigkeit, insbesondere **kein `google_sign_in`**
  (das braucht GMS).
- **Mit Google reden wir über reines HTTPS-REST** (Google Calendar API v3) plus einen
  **GMS-unabhängigen OAuth-Flow**.

Aus dieser Trennung folgen die Auth-Entscheidung und die Paket-Wahl weiter unten.

---

## 3. Getroffene Entscheidungen

| # | Entscheidung | Wahl | Begründung |
|---|---|---|---|
| 1 | **Auth** | AppAuth (System-Browser / Custom-Tab, Authorization Code + **PKCE**). **Kein Fallback.** | GMS-unabhängig; einmaliger Login, Refresh-Token danach. Custom-Tabs laufen auf EMUI einwandfrei (Session A bestätigt). Device-Flow scheidet aus: `calendar.readonly` steht nicht auf seiner erlaubten Scope-Liste. |
| 2 | **Scope** | **read-only** (`calendar.readonly`) | Datenfluss ist einseitig; kleinster Scope, keine Konfliktlösung, bessere Vertrauens-Story. |
| 3 | **Datenmodell** | Eigene `calendar_events`-Tabelle, ins Journal **eingeblendet wie Aufgaben** (Schema v4/v5, s. §5) | Synchronisierte Google-Daten bleiben sauber von selbst geschriebenen Einträgen getrennt; Resync kann gefahrlos neu aufbauen. Deckt die Perlenkette-Union direkt ab. |
| 4 | **Tags** | Nur **Kalender→Tag global**; Termin erbt die Tags seines Kalenders. **Kein** Per-Termin-Override in v1.0 | „Neues Projekt = höchstens eine Zeile." Per-Termin-Override → 🟢 später. |
| 5 | **Secrets** | Config (Client-ID etc.) **git-ignored** (+ `.example`); **Refresh-Token in `flutter_secure_storage`** (Keystore), nicht in SQLite | Öffentliches Repo → keine Config committen. Token gehören in den Keystore, nicht in die DB. |

---

## 4. Datenfluss

**Read-only, Kalender → Journal.** Disponere liest den Hub-Kalender aus und bildet Termine lokal ab.
Es schreibt nichts nach Google zurück. Eine spätere „Termin verschoben"-Markierung (Perlenkette-Auslöser)
ist eine **lokale** Notiz und kein Write-back.

---

## 5. Datenmodell (Schema v4 + v5)

Spiegelt das bewährte **Aufgaben-Muster** (eigene Tabelle, `surfacedTasksForDay`, normalisierte
`task_tags` mit lowercase `tag_key` + `ord` + `ON DELETE CASCADE`). Das Modell wird in **zwei
Migrationen** angelegt: **v4** bringt die Kalender-Quellen (Session A, Teil 2), **v5** die eigentlichen
Termine (Session B). So bleibt jede Migration klein und für sich testbar.

### Schema v4 — Kalender-Quellen (Session A, Teil 2)

**`calendar_sources`**
`calendar_id` (PK), `display_name`, `enabled` (0/1), `sync_token?`

**`calendar_source_tags`** — die „Kalender→Tag"-Zuordnung
`calendar_id`, `tag`, `tag_key`, `ord`

### Schema v5 — Termine (Session B, Teil 1) — *umgesetzt, Commit `a5549a1`*

**`calendar_events`**
PK **zusammengesetzt** (`calendar_id`, `event_id`) · `ical_uid?` · `summary` · `location?` ·
`all_day` (0/1) · `start_day`, `start_time?` · `end_day`, `end_time?`
— FK auf `calendar_sources(calendar_id)` `ON DELETE CASCADE`, Index auf `start_day`.

**`event_tags`**
`calendar_id`, `event_id`, `tag`, `tag_key` (lowercase), `ord`; PK (`calendar_id`, `event_id`,
`tag_key`); zusammengesetzter FK → `calendar_events` `ON DELETE CASCADE`

**Abweichung 1 — zusammengesetzter PK statt String-Schlüssel `calendarId:eventId`.**
Dieselbe Einladung kann in mehreren aktivierten Kalendern liegen; die Event-ID allein ist
also nicht eindeutig. Ein echter zusammengesetzter Schlüssel drückt das im Schema aus,
statt es in einen zusammengeklebten String zu verstecken — und die Fremdschlüssel von
`event_tags` greifen direkt.

**Abweichung 2 — lokale Tages-/Zeit-Keys statt `start_utc`/`end_utc`.**
`start_day`/`end_day` sind `yyyy-MM-dd`, `start_time`/`end_time` sind `HH:mm` in
**Gerätezeit**; `end_day` ist **inklusiv**. Grund: Die Kernabfrage ist „welche Termine
berühren diesen Kalendertag" — mit lokalen Tages-Keys ist das derselbe String-Vergleich
wie bei `daily_info` (`start_day <= ? AND end_day >= ?`), mit UTC-Zeitstempeln müsste
jede Tagesabfrage erst rechnen und die Zeitzone auflösen.
*Preis:* Ein Zeitzonenwechsel (Reise) macht die gespeicherten Tage falsch. Für ein
Tablet, das zu Hause steht, ist das tragbar — und die Korrektur ist ein Knopfdruck auf
„Sync jetzt", weil ohnehin vollständig neu gespiegelt wird. **Reversibel geflaggt.**

**Abweichung 3 — `description`, `google_updated`, `last_synced` entfallen.**
Beim Vollabruf (siehe §6) gibt es keinen Änderungsvergleich, für den Zeitstempel nötig
wären. `description` ist für die Einblendung nicht vorgesehen; nachrüstbar ohne Umbau.

**`ical_uid` als Dedup-Reserve:** Taucht durch geteilte Kalender oder Einladungen derselbe
Termin zweimal auf, kann über die `iCalUID` dedupliziert werden. Feld ist angelegt und
befüllt, wird in v1.0 nicht ausgewertet.

### Repository-Methoden (analog zu `surfacedTasksForDay` / `tasksForTag`)

- **v4 (Session A, Teil 2):** `loadCalendarSources`, `upsertCalendarSource`, `mergeCalendarList`.
- **v5 (Session B, Teil 1):** `calendarEventsForDay(day)` (nur *aktivierte* Kalender, ganztägig
  zuerst), `calendarEventsForTag(tag)`, `replaceCalendarEvents`, `deleteCalendarEventsFor`,
  `reapplyCalendarSourceTags`, `countCalendarEvents`.

Tags laufen durchgehend durch die geteilte `TagRegistry`-Kanonisierung.

---

## 6. Sync-Design

- **`events.list` mit `singleEvents=true`** — Google expandiert Serien in Einzeltermine.
  **Kein RRULE-Motor nötig.** *Nebenwirkung:* Ein wöchentlicher Termin zählt im +365-Fenster
  rund 52 Zeilen; die Gesamtzahl liegt deutlich über der gefühlten. Das ist korrekt.
- **Vollabruf im Zeitfenster statt Delta-Sync.** Ursprünglich war `syncToken` mit Resync bei
  `410 GONE` vorgesehen. **Das ist mit dem Zeitfenster nicht kombinierbar:** Google lehnt
  `timeMin`/`timeMax` zusammen mit `syncToken` mit HTTP 400 ab. Entweder Delta über den
  gesamten Kalender seit Anbeginn — oder Vollabruf im Fenster.
  **Entschieden: Vollabruf**, und die Termine eines Kalenders lokal vollständig ersetzen
  (`replaceCalendarEvents`, eine Transaktion). Löschungen und Verschiebungen ergeben sich
  damit von selbst; es gibt keinen Token-Zustand, der ablaufen und wieder eingefangen werden
  müsste. Für einen persönlichen Kalender sind das wenige hundert Einträge pro Abruf —
  *Verlässlichkeit vor Bastelei*. Die Spalte `sync_token` bleibt ungenutzt im Schema stehen.
- **Fenster −30 / +365 Tage, rollend** ab dem Sync-Zeitpunkt, damit die Zukunft nie ausläuft.
- **Paginierung** über `pageToken`, `maxResults=250`, Notbremse bei 40 Seiten.
- **Robustheit:** Abgesagte Termine sowie Einträge ohne ID oder Startangabe werden übersprungen,
  statt den Sync zu kippen. Jeder Kalender wird einzeln weggeschrieben — bricht einer ab,
  bleibt das übrige Ergebnis stehen und der betroffene Kalender wird namentlich gemeldet.
- **Auslöser:** App-Start + **„Sync jetzt"-Button**. **Kein Hintergrunddienst** in v1.0 (persönliches Tablet).
- **All-Day vs. terminiert:** All-Day zuerst, dann terminierte nach Startzeit; Surfacing nach **Day**
  (Gerätezeitzone).

---

## 7. Einblendung im Journal

Neue **„TERMINE"-Sektion** mit eigenem Icon, **klar von AUFGABEN unterscheidbar** (Anforderung).
Karten sind **read-only** (Tap → Detailansicht, kein Edit-Back in v1.0, passend zum read-only-Scope).

---

## 8. Tag-Vererbung

In den Einstellungen ordnest du **pro Kalender** einen oder mehrere Default-Tags zu
(z.B. Kalender „Wärme" → `#Wärme`). Beim Sync erbt **jeder Termin die Tags seines Kalenders**.
Ein Kalender darf mehrere Tags erben. Ein-/Ausschalten je Kalender über `calendar_sources.enabled`
— nur aktivierte Kalender werden abgefragt und eingeblendet.

---

## 9. Secrets & Sicherheit

- **Config nicht committen:** Client-ID / OAuth-Config in eine **git-ignorierte** Datei
  (+ eine eingecheckte `*.example`). Öffentliches Repo!
- **Refresh-Token** in **`flutter_secure_storage`** (Android-Keystore-gestützt), **nicht** in SQLite/Prefs.

---

## 10. Paket-Kandidaten (reversibel geflaggt)

- **`flutter_appauth`** — GMS-unabhängiger OAuth (Custom-Tabs / externer Browser).
  *Verifiziert (Session A):* Custom-Tabs laufen auf dem MatePad (EMUI) einwandfrei. Das ursprünglich
  als Fallback vorgesehene **Device-Flow entfällt** — `calendar.readonly` steht nicht auf seiner
  erlaubten Scope-Liste; das Risiko, das der Fallback absichern sollte, ist nicht eingetreten.
- **`googleapis`** (`CalendarApi`, reines Dart) gefüttert mit dem AppAuth-Bearer-Token **oder** rohe
  REST-Calls über `http`. Entscheidung in Coding-Session B, ändert das Design nicht.
- **`flutter_secure_storage`** — Token-Ablage.

---

## 11. Grundannahmen aus der Design-Diskussion

- **Hub-Konto = bestehendes Google-Konto (gmail).** Proton bleibt für Business-Mail. Die Idee
  „professionelle Business-Adresse als Google-Identität" (Gratis-Konto ohne Gmail bzw. Workspace)
  ist **zurückgestellt, nicht v1.0**.
- **Kuratierter Zulauf** (die Intelligenz liegt beim Nutzer, nicht in der App):
  - *Immer relevant* → Fremdtermin per **Einladung** an das Hub-Konto (zieht bei Verschiebung mit).
  - *Nur manchmal relevant* → **„Kopieren nach…"** in den Hub-Kalender (eigenständige Dublette, kein Dauer-Abo).
- **Outlook-/Fremdsystem-Zulauf (z.B. BEW-Wärme):** Eine per Outlook **ge-mailte** Einladung an ein
  **Nicht-Gmail**-Konto landet **nicht** automatisch im Google-Kalender (Google scannt kein fremdes Postfach).
  Zulauf daher per **ICS-Abo** (falls ICS-Link verfügbar) oder **Handimport**. Beim gmail-Hub greift die
  Gmail-Auto-Eintragung — deshalb ist der bestehende gmail-Hub hier der pragmatische Weg.
- **`iCalUID` wird mitgeführt** als Dedup-Reserve (s. §5).

---

## 12. Setup-Entscheidungen (außerhalb des Codes)

*Stand nach Coding-Session A, Teil 1 — die vormals offenen Punkte sind entschieden und angewandt.*

Google-Cloud-Projekt vorhanden; Google Calendar API aktiviert.
OAuth-Zustimmungsbildschirm (Google Auth Platform): Extern.
Scope `calendar.readonly` unter Datenzugriff hinzugefügt.
OAuth-Client Typ Android erstellt (Paketname `com.steffen.disponere`, Debug-SHA-1
hinterlegt). Client-ID, SHA-1 und abgeleitetes Redirect-Schema liegen privat
(git-ignoriert), nicht im öffentlichen Repo.

**Veröffentlichungsstatus — entschieden (21.07.2026):** `calendar.readonly` ist ein
sensibler Scope; in „Testing" läuft das Refresh-Token nach 7 Tagen ab. Deshalb auf
**„In Produktion" (unverifiziert)** umgestellt — damit trägt der einmalige Login dauerhaft.
Der „nicht verifiziert"-Hinweis beim Login ist erwartet und wird einmal weggeklickt.
Volle Google-Verifizierung wird für eine Ein-Personen-App **nicht** verfolgt (permanentes
100-Nutzer-Limit; die Domain `harder-business.com` läge als verifizierte Domain bereit,
falls sie je gebraucht wird).

**Custom-URI-Schema-Schalter — Pflicht:** Unter Clients → Android-Client →
Erweiterte Einstellungen muss **„Enable custom URI scheme"** aktiv sein, sonst greift das
Custom-Redirect-Schema nicht. Nach dem Speichern 5–10 min Wartezeit einplanen.

**Manifest-Fallstrick `taskAffinity`:** `android:taskAffinity=""` an `MainActivity`
(aus der Flutter-Vorlage) lässt AppAuths `RedirectUriReceiverActivity` in einem separaten
Android-Task landen — der Login-Rücksprung schlägt dann fehl („User cancelled flow").
Lösung: `android:taskAffinity=""` aus dem Manifest entfernen.

(Zurückgestellt) Business-Adresse / Workspace — kein Teil von v1.0.

---

## 13. Schnitt in Coding-Sessions

- **Coding-Session A, Teil 1 — Auth.** ✅ Abgeschlossen. Konto verbinden (AppAuth/PKCE),
  Token sicher ablegen (`flutter_secure_storage`), stiller Refresh nach Neustart,
  Trennen/Neu-verbinden. „In Produktion" umgestellt.
- **Coding-Session A, Teil 2 — Einstellungen + Schema v4.** Kalender listen (`calendarList.list`),
  je Kalender aktivieren + Tag-Mapping, Schema-**v4**-Migration (`calendar_sources` +
  `calendar_source_tags`) via `_onUpgrade`.
  *Testbar:* Kalender erscheinen, Aktiv-Schalter + Mapping werden gespeichert und überleben Neustart.
- **Coding-Session A, Teil 2 — Einstellungen + Schema v4.** ✅ Abgeschlossen (`a555f3c`).
- **Coding-Session B, Teil 1 — Sync + Schema v5.** ✅ Abgeschlossen (`a5549a1`). Sync-Engine
  (Vollabruf im rollenden Fenster, `singleEvents`), Schema-**v5**-Migration
  (`calendar_events` + `event_tags`) via `_onUpgrade`, `calendarEventsForDay`/
  `calendarEventsForTag`, „Sync jetzt"-Button mit Bestandsanzeige.
  *Getestet auf MatePad:* Sync läuft, Zähler stimmt, zweiter Sync erzeugt keine Dubletten,
  ein neu angelegter Termin erhöht den Zähler um eins.
- **Coding-Session B, Teil 2 — Einblendung.** TERMINE-Sektion pro Tag im Journal über
  `calendarEventsForDay`, Uhrzeit über `CalendarEvent.timeLabelForDay` (bei mehrtägigen
  „ab …" / „bis …"), geerbte Tags sichtbar.
  *Testbar auf MatePad:* echte Termine erscheinen vor-getaggt am richtigen Day.

*Warum Session B geteilt wurde:* Der Datenweg ist für sich prüfbar (Sync läuft, Zähler
stimmt), ohne die große `journal_screen.dart` anzufassen. Derselbe Schnitt wie bei
Session A — das Risiko zuerst, die UI danach.

---

## 14. Nicht v1.0 (Abgrenzung)

Write-back nach Google · Auto-Hintergrund-Sync · Per-Termin-Tag-Override · mehrere Google-Konten ·
Nicht-Google-Kalendersysteme (außer als ICS-Bridge) · RRULE-Bearbeitung.

---

*Architektur-Dokument. Grundlage für Coding-Session A und B. Bei Abweichungen im Coding hier nachziehen.*
