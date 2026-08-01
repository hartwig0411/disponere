# Disponere — Fahrplan naechste Session(en)

*Stand: 01. August 2026. Grundlage der Umsetzung: `disponere_anforderungen_v6_0.md`
(Feature-Block „Teilen & Bilder"). Loest den abgearbeiteten Theme-/Tag-Ansicht-Fahrplan ab.*

## Thema: Teilen & Bilder (`#Disponere-Versio`, absolute Prioritaet)

Drei zusammenhaengende Anforderungen, gemeldet aus Disponere selbst (01.08.2026). Alles
**reines AOSP-Android, GMS-frei** — laeuft auf dem HMS-MatePad ohne Google-Dienst.
**On-device-Test auf dem MatePad zwingend** (HarmonyOS-Eigenheiten im Teilen-Dialog und in der
Foto-Auswahl).

## Getroffene Entscheidungen (stehen fest)

- **Empfangsweg:** natives **MethodChannel in `MainActivity`** (`getIntent()` / `onNewIntent()`),
  **nicht** das Plugin `receive_sharing_intent`. Robuster auf HMS, in derselben Werkzeuglinie
  wie FreeScript-PlatformView und AppAuth.
- **Reihenfolge:** **Feature-weise 1 → 2 → 3.** Feature 1 (Bilder) ist Fundament fuer die
  Bild-Wege in 2 und 3.

## Reihenfolge (nicht vertauschen)

### Session A — Feature 1: Bilder in Disponere ablegen
*Groesste der drei; enthaelt die Schema-Migration. Mit vollem Budget nach Reset starten.*
- **Schema-Migration v6 → v7**: Anhang-Datenmodell (eigene Tabelle vs. Spalte am Eintrag — in
  der Session festzulegen). Bild-Bytes in den **App-privaten Speicher** kopieren, Pfad in der DB.
- Bildauswahl via `image_picker` (Galerie/Kamera, AOSP-Intents).
- Anzeige: **Thumbnail** in der Eintragskarte, **Vollbild** beim Antippen (kleiner Viewer).
- Voraussichtlich angefasst: `journal_repository.dart` (Migration + CRUD, ganze Datei),
  neues Anhang-Modell, `entry_card.dart`, Eintrags-Sheet, Bild-Viewer.

### Session B — Feature 2: Disponere als Empfangsziel
- `<intent-filter>` mit `ACTION_SEND` (Text/URL, danach `image/*`) im `AndroidManifest.xml`.
- **Natives MethodChannel** in `MainActivity`: Kaltstart-Intent (`getIntent()`) UND laufende App
  (`onNewIntent()`). Extras nach Flutter reichen.
- Geteiltes → Eintrag **im Journal des aktuellen Tages**. Text/URL → Texteintrag; Bild → nutzt
  Feature 1. Kleines **Landeblatt** (Inhalt zeigen, Tags ergaenzen, speichern).
- Voraussichtlich angefasst: `MainActivity` (Kotlin), `AndroidManifest.xml`,
  `journal_screen.dart` / Eintrags-Sheet, evtl. `journal_repository.dart`.

### Session C — Feature 3: Aus Disponere heraus teilen
*Leichteste; Text/Tinte unabhaengig von Feature 1.*
- Teilen-Einstieg am Eintrag (Icon / Long-Press), `share_plus` (AOSP, GMS-frei).
- Texteintrag → Text; **Tinteneintrag → PNG** ueber vorhandenen `ink_renderer.dart`
  (Schwarz-auf-weiss, schon fuer die Claude-Auswertung gebaut, direkt wiederverwendbar);
  Bildeintrag → Datei.
- Voraussichtlich angefasst: `entry_card.dart` / Eintrags-Ansicht, kleine Teilen-Hilfe.

## Aufwand (grob)

- Feature 1: eine volle Session, evtl. kleiner Nachlauf.
- Feature 2: ~eine Session (Text/URL; Bilder danach klein).
- Feature 3: halbe bis eine Session.
- Gesamt: rund **3–4 fokussierte Sessions** je nach Politur und HMS-Teilen-Dialog-Iteration.

## Budget-Hinweis

Feature 1 und Feature 2 fassen grosse Dateien an (`journal_repository.dart`, Journal-Screen) und
werden nach der Komplett-Datei-Regel jeweils ganz geliefert — **nach dem Reset mit vollem Budget
starten**. Jedes Feature ist eine eigene Session (erst rein + auf dem MatePad testen, dann
weiter).

## Danach / weiterhin offen

- **Fable-Review** — Kohaerenz gegen `disponere_design_v2_0.md`, Robustheit,
  Flutter-Konventionen. Laeuft im Chat uebers Abo.
- Erster voller KW-Durchlauf der Wochenauswertung ueber eine echte Woche (Alltagsnutzen).
- Kleinkram: verwaister `native_text_test_screen.dart`; `InkData.width/height`-Feld-Aufraeumen.

---
