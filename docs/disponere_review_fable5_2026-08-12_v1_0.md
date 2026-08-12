# Disponere — Zweit-Review durch Claude Fable 5

**Datum:** 12. August 2026
**Reviewer:** Claude Fable 5 (unabhängiger Zweit-Blick; eigenes Urteil gebildet, **bevor** die Opus-Review gelesen wurde)
**Prüfstand:** HEAD `f8533a0` (docs, Session 49) · Feature-Stand `c979e91` (Session 48) — frischer `git clone --depth 1`, HEAD gegen Fortschrittsdokument v2.7 verifiziert ✓
**Lineal:** `disponere_design_v2_0.md` (Absicht/Seele) · `disponere_anforderungen_v6_1.md` (genehmigte Verfeinerungen) · Code = Realität
**Charakter:** reine Lese-Review — kein Code angefasst. Umfang bewusst breiter als die reine Design-Kohärenz: auch Robustheit, Zustands-/Fehlerpfade, Datenschicht, tote Enden.

---

## Gesamturteil

**Disponere v1.0 ist kohärent mit seinem Design und handwerklich in gutem Zustand.** Die Seele der App — „am richtigen Tag auftauchen", ein Journal mit Tags als Sicht, heute = freie Schreibfläche vs. Vergangenheit = fertige Tagesgeschichte, Claude spricht nie ungefragt — trägt sich sauber durch den Code. Die Datenschicht ist diszipliniert (normalisierte Tag-Tabellen, additive Migrationen v1→v7 mit geteilten Create-Helfern, transaktionale Upserts), die Fehlerpfade der Claude- und Kalender-Anbindung sind vorbildlich ehrlich (nichts wird halb gespeichert, Schlüssel taucht nie in Meldungen auf, UTF-8 über `bodyBytes`), und die bekannten Fallen des Projekts (Umlaute in SQLite, `ConflictAlgorithm.replace` vs. `ink_text`, DST-Datumsmathematik) sind fast überall aktiv umschifft.

**„Fast überall" ist das Stichwort:** Ich habe **einen mittleren Fund**, den die Opus-Review nicht hat (Tag-Umbenennen erfasst Kalender-Quellen nicht), und ich **verschärfe deren F1** — die `Duration`-Datumsmathematik im Kalender-Service ist nicht nur ein Disziplinbruch, sondern ein realer (sehr seltener) Off-by-one-Fehler. Kein Fund ist ein v1.0-Blocker.

---

## Funde nach Schweregrad

### M1 — Tag-Umbenennen erfasst Kalender-Quellen nicht · **mittel** · Code

`_renameTag` (`journal_screen.dart`) schreibt die neue Schreibweise durch **Einträge und Aufgaben** — aber nicht durch die **Kalender→Tag-Zuordnung** (`calendar_source_tags`) und damit auch nicht durch die gespiegelten Termine (`event_tags`). Seit Session 20 speisen Kalender-Tags aber das Tag-Register, und Termine hängen in der Tag-Ansicht.

**Konkretes Fehlerbild:** `#Wärme` hängt an Einträgen **und** am Kalender `harder-business`. Umbenennen in `#Heizung` →
1. Einträge/Aufgaben tragen `#Heizung`, der Kalender und alle seine Termine weiter `#Wärme`. Der Tag **zerfällt in zwei**: Die Tag-Ansicht `#Heizung` zeigt keine Termine mehr, `#Wärme` existiert weiter (gespeist aus dem Kalender) — genau die Zersplitterung, die das Register verhindern soll.
2. Beim nächsten Sync erben neue Termine weiter den alten Tag.
3. Sonderfall reiner Kalender-Tag: Das Umbenennen ist ein **stiller No-op** — die Anzeige-Kopie in `TagManagementScreen` bestätigt den Rename aber optisch (Zähler-Merge, Liste aktualisiert). Beim nächsten Öffnen steht der alte Tag wieder da. Die UI lügt kurzzeitig.
4. Kosmetisch daneben: `_subtitleFor` zeigt für reine Kalender-Tags „0 Einträge" — der Kalender als Nutzungsquelle fehlt im Zähler.

**Empfehlung:** `_renameTag` um die Kalender-Quellen erweitern — betroffene `CalendarSource` remappen, `upsertCalendarSource` + `reapplyCalendarSourceTags` (rein lokal, kein Sync nötig; die Bausteine existieren alle schon). Alternativ (defensiv): Umbenennen von kalender-gebundenen Tags mit Hinweis blockieren. Dazu in der Tag-Verwaltung einen dritten Zähler „· N Kalender". *Bewusst offen lassen kann man die Inline-`#Tags` in Tagesinfo-Texten — das ist Nutzertext; ihn still umzuschreiben wäre übergriffig. Aber die Entscheidung sollte dokumentiert sein.*

---

### N1 — Kalender-Datumsmathematik über `Duration` (= Opus F1, **verschärft**) · niedrig · Code

`google_calendar_service.dart` Z. 221 (Mitternachts-Korrektur) und Z. 259–263 (`_dayBefore`) rechnen Tages-Keys per `subtract(Duration(days: 1))` — gegen die Konstruktor-Regel aus `week_context.dart`/`journal_repository.dart`.

Die Opus-Review stuft das als „praktisch harmlos — kippt hier keinen Tages-Key". **Dem widerspreche ich: Der Key kippt, einmal im Jahr.** Dart rechnet `subtract` auf der absoluten Zeit; am Montag nach dem **Frühjahrs**-DST-Sonntag (23-Stunden-Tag) landet „Mitternacht minus 24 h" auf **23:00 zwei Tage davor**. Nachgerechnet für Europe/Berlin (Dart-Semantik emuliert: → UTC, −24 h, → lokal):

```
_dayBefore("2026-03-30") → 2026-03-28T23:00 lokal → Key "2026-03-28"   (richtig: 2026-03-29)
_dayBefore("2026-10-26") → 2026-10-25T01:00 lokal → Key "2026-10-25"   (Herbst: korrekt)
```

**Konkretes Fehlerbild:** Ein **mehrtägiger ganztägiger Termin, der am DST-Frühjahrs-Sonntag endet** (z. B. Wochenend-Termin 28.–29.03.2026; Google liefert exklusives `end.date` 2026-03-30), bekommt `endDay = 2026-03-28` — der Sonntag fehlt im Journal. Eintägige Termine an diesem Sonntag rettet zufällig die `endDay < startDay`-Klammer (Zeile 204). Der Herbst-Fall ist korrekt, weil die 25-Stunden-Richtung glimpflich ausgeht. Analog kann die Mitternachts-Korrektur (Z. 221) bei einem zeitgebundenen Termin, der exakt um Mitternacht des DST-Montags endet und ≥2 Tage überspannt, den letzten Tag verlieren.

**Empfehlung:** Wie von Opus vorgeschlagen — gemeinsamer Helfer `dayBefore(DateTime d) → DateTime(y, m, d − 1)`, beide Stellen darüber führen. Zusätzlich für `_dayBefore(String)`: gar nicht erst über `DateTime` gehen müssen — parsen, `DateTime(y, m, d − 1)`, formatieren. (`timeMin`/`timeMax` Z. 94/95 sind Abfragegrenzen, dort ist `Duration` in Ordnung — d'accord mit Opus.)

---

### N2 — `huawei_ml_text` ist eine tote Abhängigkeit mit Build-Kosten · niedrig · Build-Hygiene

Das Paket steht in `pubspec.yaml`, wird aber **nirgends in `lib/` importiert** (der ML-Kit-Pfad ist seit Session 13 aus dem Code). Es ist nicht gratis: Es erzwingt `android.uniquePackageNames=false` in `gradle.properties` und den **manuellen pub-cache-Patch** (`compileSdkVersion` in dessen `build.gradle`), der laut Session 6 **nach jedem `flutter pub get` wiederholt** werden muss — eine wiederkehrende Stolperfalle für exakt ein Feature (Dokument-Import), das 🟢 und ungebaut ist.

**Empfehlung:** Raus aus `pubspec.yaml` (plus die beiden Workarounds zurückbauen), wieder rein, wenn der Dokument-Import tatsächlich gebaut wird — und dann prüfen, ob Plaud ohnehin Text statt Scan liefert (Session 22, Entscheidung 5: dann braucht es ML Kit nie).

---

### N3 — Status-Drift im Anforderungsdokument v6.1 · niedrig · Doku

Das Lineal ist an mehreren Stellen hinter der Realität (Stand des Docs: 05.08., gebaut wurde 09.–11.08.):

- Feature-Tabelle: **„Bild als Eintragsinhalt" ⏳, beide Teilen-Wege ⏳** — alle drei sind seit Session 43/44/45 (+ Bild-Empfang S47) gebaut und auf dem MatePad abgenommen.
- Technologie-Tabelle und Fundament: **„SQLite, Schema v6"** — der Code steht auf **v7** (attachments).
- Paketliste: `image_picker`, `share_plus`, `sqflite` fehlen bzw. sind unvollständig aufgeführt.
- `disponere_design_v2_0.md`, Status-Kopf: **„Noch nicht in Flutter umgesetzt (reine Design-Session, kein Code)"** — seit Session 33–36 umgesetzt; die Zeile liest sich in einem Jahr als falsche Auskunft.

Die Sessions 43–48 vermerkten jeweils „Neu gesammelt: nichts" — die Status-Häkchen sind dabei durchgerutscht. Das ist genau die Diskrepanz-Klasse, die Session 14 strukturell schließen wollte.

**Empfehlung:** Ein `docs:`-Durchgang v6.1 → v6.2: die drei Teilen-&-Bilder-Zeilen auf ✅, Schema v7, Paketliste; im Design-Doc den Status-Kopf nachziehen (dorthin passt auch Opus' F2 und die Dunkel-Chrome-Ausnahme — ein Commit für alles).

---

### N4 — Tag-Ansicht: mehrtägige Elemente nur am Starttag · niedrig · Kohärenz

Im Journal erscheinen mehrtägige Termine an **jedem berührten Tag** (`past_day.dart`, Schleife über `startDay…endDay`) und Zeitspannen-Tagesinfos an jedem abgedeckten Tag — „Auftauchen am richtigen Tag" als Seele. Die **Tag-Ansicht** (`tag_view_screen.dart`, `_groupByDay`) hängt dieselben Elemente dagegen **nur an ihren Starttag** (`event.startDay`, `info.startDate`). Ein einwöchiger `#Urlaub` ist in der Tag-Ansicht ein einzelner Tag, im Journal sieben.

Vertretbar (die Tag-Ansicht ist eine Chronik, keine Tagessicht — Dubletten wären dort eher Rauschen), aber es ist eine **unentschiedene** Abweichung von der Mechanik, die das Design als durchgängig beschreibt. **Empfehlung:** bewusst entscheiden und einen Satz dazu ins Design/die Anforderungen — vermutlich „Starttag genügt", dann ist es ab sofort Absicht statt Zufall.

---

### N5 — Kaltstart-Share-Race gegen `_init()` · niedrig · Randfall

Beim Kaltstart über den Teilen-Dialog öffnet der Post-Frame-Callback das Eintrags-Sheet, **bevor** `_init()` (DB laden, Tag-Register aufbauen) zwingend fertig ist. Folgen im Rennfall: leeres Tag-Autocomplete, und `canonicalizeAll` läuft gegen ein leeres Register — ein schnell gespeichertes `#wärme` landet in abweichender Schreibweise am Eintrag (der `tag_key` bleibt korrekt, aber der Chip zeigt die Variante; das Register zeigt danach wieder die alte kanonische Form, der Eintrag nicht). Praktisch schmal — der Nutzer tippt länger als die DB lädt — aber der Fix ist billig: das Kaltstart-Abholen ans Ende von `_init()` hängen statt an den ersten Frame.

---

### Trivia (Ermessen, beim nächsten Anfassen mitnehmen)

- **T1:** Der `max_tokens`-Hinweis (`_truncationNote`, Session 48) wird an den erkannten Text **angehängt und mitgespeichert** — er landet damit in `ink_text`, ist **durchsuchbar** („Hinweis", „Laengenlimit" werden Suchtreffer) und geht beim Teilen eines Tinten-Eintrags als Begleittext mit hinaus. Sauberer wäre, die Kürzung als eigenes Flag/nur in der Vorschau zu führen — oder das bewusst so zu lassen und zu wissen.
- **T2:** `_renameTag` persistiert fire-and-forget (`upsertAll`/`upsertTask` ohne `await`). Bei sofortigem App-Tod wäre die UI dem Datenbestand voraus. Ein `await` kostet nichts.
- **T3:** Der `<queries>`-Block mit `PROCESS_TEXT` im Manifest ist ein Flutter-Template-Rest ohne Funktion in Disponere.
- **T4 (= Opus F6):** `thumbPath` schlafend und unkommentiert — Ein-Zeilen-Doc genügt. *(Anmerkung: Das Modell in `attachment.dart` trägt den Kommentar inzwischen; die Schema-Doku im Repository ebenso — der Fund ist strenggenommen halb erledigt.)*
- Bekannt und richtig im Backlog belassen: 3× `withOpacity` in `task_overview_screen.dart`, KGP-Warnung `share_plus`.

---

## Gegenprobe: die Opus-Review (`disponere_fable_review_2026-08-12_v1_0.md`)

**Ich bestätige das Gesamturteil** („v1.0 ist kohärent mit seinem Design") und alle sechs Funde — mit einem Widerspruch im Detail und einer Ergänzungsliste:

| Opus-Fund | Mein Verdikt |
|---|---|
| **F1** `Duration`-Datumsmathematik | **Bestätigt, aber verschärft.** Nicht „praktisch harmlos" — am DST-Frühjahrs-Sonntag kippt der Tages-Key real (Beleg oben, N1). Die empfohlene Fix-Form (Konstruktor-Helfer) ist exakt richtig; sie behebt damit einen echten Bug, nicht nur einen Stilbruch. Priorität dadurch eher „kleine Fix-Session bald" als „irgendwann". |
| **F2** Design §4a vs. HEUTE-FÄLLIG | Bestätigt. Geht im selben `docs:`-Durchgang wie mein N3 auf. |
| **F3** `app_colors`-Kommentar auf v1.0 | Bestätigt (trivial). |
| **F4** Tag-Ansicht ohne Recency-Zeile | Bestätigt (Ermessen). |
| **F5** Pinsel-Icon als „Deko" | Bestätigt (Ermessen; ich würde es behalten — es unterscheidet Tinte auch in der Trefferliste der Suche, wo keine Striche zu sehen sind). |
| **F6** `thumbPath` vestigial | Bestätigt; Modell-Kommentar existiert bereits, Rest-Aufwand minimal. |

**Was ich zusätzlich finde:** M1 (Tag-Rename ↔ Kalender-Quellen — der gewichtigste Fund dieser Review), N2 (tote `huawei_ml_text`-Dependency), N3 (Status-Drift v6.1/Design-Kopf), N4 (Tag-Ansicht Starttag-only), N5 (Kaltstart-Race) und die Trivia T1–T3. Die Opus-Review hat eng am Design-Lineal geprüft und das sehr gründlich; die Zusatzfunde liegen fast alle in dem Bereich, den sie ausdrücklich nicht beackert hat (Datenfluss-Invarianten über Feature-Grenzen, Build-Hygiene, Doc-Status).

---

## Was ausdrücklich gut ist (Auswahl)

- **`_upsertInTxn` führt `ink_text`/`ink_text_at` und die Attachments beim Replace mit** — die in Session 24 gefürchtete stille Löschfalle ist geschlossen und kommentiert; `_saveInkText` zieht zusätzlich das Listen-Objekt nach, damit ein anschließendes Speichern aus dem Editor die frische Auswertung nicht überschreibt. Die Kette hält.
- **Suche filtert in Dart** (Umlaut-Falle), Snippet um die Fundstelle, veraltete Antworten werden verworfen, „erkannter Text"-Badge trennt Maschine von Mensch.
- **Migrationskette v1→v7** stufenweise ohne `else`, Create-Helfer von `onCreate` und `onUpgrade` geteilt — kein Schema-Drift möglich.
- **Sync-Robustheit:** Kalender einzeln, Fehler benannt statt Durchlauf verworfen; `replaceCalendarEvents` in einer Transaktion; Kalender-Ausschalten räumt sofort.
- **Consume-once-Share-Kanal** (Kotlin + Dart) sauber symmetrisch für Text und Bild; `content://` wird nativ aufgelöst, der Flutter-Importweg bleibt einer.
- **Heute-Panel/Tageswechsel:** `WidgetsBindingObserver` + idempotenter Datumswächter in `build` — Bug 1 aus Session 32 ist wirklich zu.

---

## Konsolidierte offene To-do-Liste (nach dieser Review)

1. **Fix-Session (klein):** N1/F1 — `dayBefore`-Helfer über den Konstruktor, beide Stellen in `google_calendar_service.dart`. *(einziger Punkt aus der Opus-Review mit echtem Bug dahinter)*
2. **Fix-Session (mittel):** M1 — Tag-Umbenennen auf Kalender-Quellen ausweiten (`upsertCalendarSource` + `reapplyCalendarSourceTags`), Kalender-Zähler in der Tag-Verwaltung; dabei T2 (`await` beim Rename) mitnehmen.
3. **`docs:`-Durchgang:** N3 + Opus F2/F3 — Anforderungen v6.2 (Teilen & Bilder ✅, Schema v7, Pakete), Design v2.0 Status-Kopf + §4a-Satz + Dunkel-Chrome-Ausnahme, `app_colors`-Kommentar.
4. **Kleinkram nach Ermessen:** N2 (`huawei_ml_text` raus), N4 (Starttag-Entscheidung dokumentieren), N5 (Kaltstart-Abholen hinter `_init()`), T1 (Trunkierungs-Flag statt Text-Anhang), T3 (Manifest-Query), Opus F4/F5/F6.

Punkte 1 und 2 passen zusammen in eine fokussierte Session (beide fassen je eine Datei an, keine Schema-Änderung). Danach ist v1.0 auch aus Sicht dieses Zweit-Blicks sauber durch.

---

*Review erstellt von Claude Fable 5 · Session 50 · eigenes Urteil vor Lektüre der Opus-Review gebildet, Gegenprobe danach.*
