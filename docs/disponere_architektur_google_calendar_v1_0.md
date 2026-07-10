# Disponere – Architektur: Google Calendar-Anbindung

**Dokument-Revision:** v1.0
**Status:** Design abgeschlossen — vor Coding
**Erfüllt:** Anforderungen v3.0 → *Google Calendar-Anbindung* (🟡 Core) und Kernkonzept 2
(*Termine erscheinen automatisch als vor-getaggte Einträge mit Zeitstempel*)
**Nachgelagert:** zwei Coding-Sessions (A: Auth + Einstellungen, B: Sync + Schema v4 + Einblendung)

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
| 1 | **Auth** | AppAuth (System-Browser / Custom-Tab, Authorization Code + **PKCE**) primär; **Device-Flow** als dokumentierter Fallback | GMS-unabhängig; einmaliger Login, Refresh-Token danach. Fallback, falls Custom-Tabs auf EMUI zicken. |
| 2 | **Scope** | **read-only** (`calendar.readonly`) | Datenfluss ist einseitig; kleinster Scope, keine Konfliktlösung, bessere Vertrauens-Story. |
| 3 | **Datenmodell** | Eigene `calendar_events`-Tabelle, ins Journal **eingeblendet wie Aufgaben** (Schema v4) | Synchronisierte Google-Daten bleiben sauber von selbst geschriebenen Einträgen getrennt; Resync kann gefahrlos neu aufbauen. Deckt die Perlenkette-Union direkt ab. |
| 4 | **Tags** | Nur **Kalender→Tag global**; Termin erbt die Tags seines Kalenders. **Kein** Per-Termin-Override in v1.0 | „Neues Projekt = höchstens eine Zeile." Per-Termin-Override → 🟢 später. |
| 5 | **Secrets** | Config (Client-ID etc.) **git-ignored** (+ `.example`); **Refresh-Token in `flutter_secure_storage`** (Keystore), nicht in SQLite | Öffentliches Repo → keine Config committen. Token gehören in den Keystore, nicht in die DB. |

---

## 4. Datenfluss

**Read-only, Kalender → Journal.** Disponere liest den Hub-Kalender aus und bildet Termine lokal ab.
Es schreibt nichts nach Google zurück. Eine spätere „Termin verschoben"-Markierung (Perlenkette-Auslöser)
ist eine **lokale** Notiz und kein Write-back.

---

## 5. Datenmodell (Schema v4)

Spiegelt das bewährte **Aufgaben-Muster** (eigene Tabelle, `surfacedTasksForDay`, normalisierte
`task_tags` mit lowercase `tag_key` + `ord` + `ON DELETE CASCADE`).

**`calendar_events`**
`id` (PK, `calendarId:eventId`), `calendar_id`, `ical_uid`, `title`, `description?`,
`start_utc`, `end_utc`, `all_day` (0/1), `location?`, `google_updated`, `last_synced`
— Zeiten als **UTC + `all_day`-Flag** gespeichert, in Gerätezeitzone gerendert.

**`event_tags`** (exakt wie `task_tags`)
`event_id`, `tag`, `tag_key` (lowercase), `ord`; PK (`event_id`, `tag_key`); FK → `calendar_events` `ON DELETE CASCADE`

**`calendar_sources`**
`calendar_id` (PK), `display_name`, `enabled` (0/1), `sync_token?`

**`calendar_source_tags`** — die „Kalender→Tag"-Zuordnung
`calendar_id`, `tag`, `tag_key`, `ord`

**Neue Repository-Methoden** (analog zu `surfacedTasksForDay` / `tasksForTag`):
`surfacedEventsForDay(day)`, `eventsForTag(tagKey)`, Upsert/Delete für den Sync,
Getter/Setter für Quellen (aktiv/inaktiv) und Mapping. Tags laufen durch die geteilte
`TagRegistry`-Kanonisierung.

**`ical_uid` als Dedup-Reserve:** Taucht durch geteilte Kalender oder Einladungen derselbe Termin
zweimal auf, kann über die `iCalUID` dedupliziert werden. Ein Feld mehr, kein Umbau.

---

## 6. Sync-Design

- **`events.list` mit `singleEvents=true`** — Google expandiert Serien in Einzeltermine.
  **Kein RRULE-Motor nötig.** (Parameter bleibt über alle Syncs konstant, sonst wird der `syncToken` ungültig.)
- **Delta-Sync über `syncToken`**; bei `410 GONE` voller Resync des betroffenen Kalenders.
- **Fenster** z.B. −30 / +365 Tage.
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
  *EMUI-Risiko:* Custom-Tabs-Verfügbarkeit auf dem MatePad in Coding-Session A früh testen; sonst Device-Flow-Fallback.
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

## 12. Offene Setup-Entscheidungen (vor Coding-Session A, außerhalb des Codes)

- **Google-Cloud-Projekt** anlegen (nicht Huawei AGC!), **Calendar API aktivieren**,
  **OAuth-Consent-Screen** in „Testing" mit Steffen als Testnutzer, **OAuth-Client** anlegen.
- Konkrete Klick-Pfade gehören in die Vorbereitung von Coding-Session A, **nicht** in dieses Dokument.
- (Zurückgestellt) Business-Adresse / Workspace — kein Teil von v1.0.

---

## 13. Schnitt in Coding-Sessions

- **Coding-Session A — Auth + Einstellungen.** Konto verbinden (AppAuth/PKCE), Kalender listen
  (`calendarList.list`), je Kalender aktivieren + Tag-Mapping, Token sicher ablegen.
  *Testbar:* Login klappt, Kalender erscheinen, Mapping gespeichert.
- **Coding-Session B — Sync + Schema v4 + Einblendung.** Sync-Engine (`syncToken`, `singleEvents`),
  Schema-v4-Migration via `_onUpgrade`, `surfacedEventsForDay`/`eventsForTag`, TERMINE-Sektion,
  „Sync jetzt"-Button.
  *Testbar auf MatePad:* echte Termine erscheinen vor-getaggt am richtigen Day.

---

## 14. Nicht v1.0 (Abgrenzung)

Write-back nach Google · Auto-Hintergrund-Sync · Per-Termin-Tag-Override · mehrere Google-Konten ·
Nicht-Google-Kalendersysteme (außer als ICS-Bridge) · RRULE-Bearbeitung.

---

*Architektur-Dokument. Grundlage für Coding-Session A und B. Bei Abweichungen im Coding hier nachziehen.*
