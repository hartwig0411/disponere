# Disponere — Fable-Review (Kohärenzprüfung Code ↔ Design)

**Datum:** 12. August 2026
**Prüfstand:** HEAD `b9ca9c2` (docs), Feature-Stand `c979e91` (Session 48)
**Lineal:** `disponere_design_v2_0.md`
**Charakter:** reine Chat-/Lese-Session — **kein Code angefasst.** Die Funde speisen
entweder eine spätere kleine Fix-Session oder eine Doku-Nachführung.

---

## Maßstab

- **`disponere_design_v2_0.md` = die Absicht/Seele** (Leitprinzip, Farben, Tag-Ansicht als Kick, „taucht am richtigen Tag auf", heute = freie Schreibfläche vs. Vergangenheit = fertige Tagesgeschichte).
- **`disponere_anforderungen_v6_1.md` = genehmigte Verfeinerungen** (erklären, warum der Code über v2.0 hinauswächst).
- **Code = Realität.**

Geprüft wurde: *Verkörpert der Code die Absicht — und wo er abweicht, ist das eine dokumentierte Verfeinerung (in Ordnung) oder unbemerkte Drift (Fund)?* Nur echte, unbemerkte Drift zählt als Befund.

---

## Gesamturteil

**v1.0 ist kohärent mit seinem Design.** Die Seele der App trägt sich sauber durch den Code: die Perlenkette („am richtigen Tag auftauchen"), die harte Trennung heute/Vergangenheit, die Tag-Ansicht als Kick, das ruhige helle Papier-Theme. Das Farbsystem sitzt Hex-genau. Kein toter Code, keine verwaisten Dateien, keine halb-verdrahteten Screens.

Die Funde sind durchweg **klein**: fünf davon sind Doku-Nachführung oder Kosmetik, **genau einer** ist ein echter (niedrig-riskanter) Code-Disziplin-Bruch. Keiner ist ein v1.0-Blocker.

---

## Verdikt je Design-Abschnitt

| § | Thema | Verdikt | Beleg / Bemerkung |
|---|---|---|---|
| 1 | Leitprinzip (hell, dunkle Tinte, kein Dark-Theme) | **kohärent** | `app_colors` hell; Tinte `#2A2B48` dunkel; kein Dark-Theme. Eine bewusste Ausnahme: Foto-Oberflächen (Vollbild-Viewer, Scrim-Button) nutzen Dunkel-Chrome. |
| 2 | Farben | **kohärent** | Alle 18 Tabellenwerte exakt (`app_colors.dart`). Abgeleitete Töne (`fieldFill`, `tagChipBg`, `danger`) ehrlich als „nicht in der Tabelle" markiert. → F3 (trivialer Doku-Nit). |
| 3 | Typografie | **kohärent** | Datumskopf zweizeilig (Wochentag 12 px/2.5, Datum 30 px/w500); `#Tag`-Kopf im Akzent, kleiner; Tinte als echte Vektorstriche. Getippt 16 px vs. „ca. 15" — in Toleranz. → F5 (Pinsel-Icon). |
| 4a | Heute — freie Schreibfläche | **kohärent (genehmigte Verfeinerung)** | Datumskopf, Tagesinfo-`Wrap` (3 Spalten, 4. bricht um), Einträge chronologisch. Heute fällige Aufgaben stehen jetzt im Block (v6.1 §2) — widerspricht dem Wortlaut von §4a. Code korrekt. → F2 (Doku nachziehen). |
| 4b | Vergangene Tage — Tagesgeschichte | **kohärent (vorbildlich)** | `past_day.dart`: tag-lose Notizen oben, Cluster nach erster Uhrzeit, Mehrfach-Auftauchen unter jedem Tag, Führungslinien links, Neuaufbau aus dem Repository beim Abhaken (keine Sync-Logik). |
| 5 | Seiten-Panel (Heute-Agenda) | **kohärent** | Fest auf heute; Overlay-`endDrawer` von rechts in beiden Lagen; Standard geschlossen; Badge = Termine + offene Aufgaben; nur Abhaken (kein Öffnen); Leerfall „Heute nichts geplant"; Reload bei Resume **und** Mitternachts-Datumswächter. |
| 6 | Auftauchende Elemente & Marker | **kohärent** | Termin (blaues Kalender-Icon + Uhrzeit), Aufgabe offen (Kästchen `taskOpenBox`), erledigt (gefüllt, durchgestrichen, grau), Tagesinfo (Info-Icon im Band), getippt/handschriftlich — alle sechs Marker sitzen. |
| 7 | Leerer Heute-Zustand | **kohärent** | `EmptyEntryInvitation`: wartender Punkt (`bullet`), blauer Cursor (2 px, `accent`), Platzhalter „Tippen oder mit dem Stift schreiben …" — exakt wie §7. |
| 8 | Tag-Ansicht (der Kick) | **kohärent (kleine Notiz)** | Akzent-Kopf, alle vier Quellen nach Tagen gruppiert, neu nach alt, Zurück-Pfeil, reine Lese-Ansicht. Zähler zeigt Typ-Aufschlüsselung, lässt aber den „zuletzt <heute>"-Recency-Hinweis des §8-Beispiels weg. → F4. |
| 9 | Navigation & Icon-Leiste | **kohärent** | Untere Leiste: Journal (Buch, aktiv/Akzent), Suche (Lupe), Aufgaben (Kästchen), Neuer Eintrag (Stift). Oben rechts: Funkel (`auto_awesome`) + Panel-Umschalter mit Badge. Oben links: Menü. |
| 10 | Offene Punkte (der Praxis überlassen) | **kohärent** | Aktuelle „vorerst"-Wahl überall eingehalten: Navigation unten, Tagesinfo oben, Platzhalter behalten, Cluster-Reihenfolge chronologisch. |
| 11 | Spätere Versionen (nicht v1.0) | **kohärent** | `iCalUID` als Feld reserviert und vorhanden, Dedup **nicht** implementiert (korrekt für v1.0); Tag-Kategorien nicht implementiert (korrekt). |

---

## Querschnittliche Disziplin-Checks

- **Farb-Disziplin:** sauber. Rohe `Colors.white`-Stellen sind durchweg Weiß-auf-Akzent (Badge, gefüllte Buttons, erledigtes Häkchen) — legitim, da die Tabelle keinen „on-accent"-Token führt. Dunkel-Chrome nur auf Foto-Oberflächen (Vollbild-Viewer `image_viewer_screen`, Scrim-Button im Eintrags-Sheet `journal_screen:490`). → als bewusste Ausnahme zu §1 notieren.
- **Datumsarithmetik:** **ein Fund.** Die Konstruktor-Regel („nie `Duration` für Tages-Mathematik, DST-Drift") ist in `week_context.dart:9` und `journal_repository.dart:1191` festgeschrieben — aber `google_calendar_service.dart` rechnet Tage über `Duration` (Z. 221 Mitternachts-Korrektur, Z. 262 `_dayBefore`). → F1.
- **Toter Code / Verwaiste Dateien:** keine. Jeder Screen/Service wird importiert; Session 48 hat den letzten Test-Screen entfernt.
- **`thumbPath`:** reserviertes Feld, nirgends befüllt; nur der Lösch-Cleanup liest es. → F6.
- **Handschrift/FreeScript-Trennung:** intakt. `native_text_entry_screen` (FreeScript-PlatformView) ist verdrahtet und **nicht** mit Tastatur-Handschrift vermengt. (Außerhalb des Design-Skopus, aber gesund.)

---

## Fund-Liste (nach Schweregrad)

**F1 — Kalender-Datumsmathematik über `Duration` · niedrig · Code**
`google_calendar_service.dart` Z. 221 und 262 berechnen Tages-Keys per `subtract(Duration(days: 1))`, entgegen der Konstruktor-Regel aus `week_context.dart`/`journal_repository.dart`. In genau diesen Fällen praktisch harmlos (die ±1 h DST-Verschiebung kippt hier keinen Tages-Key), aber es ist der Bruch der Disziplin, die genau diese Fallprüfung überflüssig machen soll.
*Empfehlung:* gemeinsamer Helfer `dayBefore(DateTime) → DateTime(y, m, d-1)` und beide Stellen darüber führen. (Die `timeMin`/`timeMax`-Fensterränder Z. 94/95 sind Abfragegrenzen, kein Tages-Key — dort ist `Duration` in Ordnung.)

**F2 — §4a widerspricht dem Shipping-Verhalten · niedrig · Doku**
Design §4a: „Termine und Aufgaben von heute stehen nicht in der Spalte." Seit v6.1 §2 steht der **HEUTE-FÄLLIG**-Block aber genau dort. Der Code ist korrekt (genehmigte Verfeinerung); das Lineal ist veraltet.
*Empfehlung:* in `disponere_design_v2_0.md` §4a einen Satz ergänzen (Verweis auf v6.1 §2), damit Design und Realität wieder deckungsgleich sind.

**F3 — `app_colors.dart` referenziert `design_v1_0` · trivial · Doku**
Der Doc-Kommentar nennt „`docs/disponere_design_v1_0.md` §2" und „Design v1.0"; aktuell ist v2.0. Die Farbtabelle ist zwischen v1.0 und v2.0 unverändert, also stimmen die **Werte** — nur der Verweis ist alt.
*Empfehlung:* Kommentar auf v2.0 ziehen.

**F4 — Tag-Ansicht-Zähler ohne Recency · niedrig · Design-Intent**
§8 nennt als Beispiel „4 Einträge · zuletzt heute". Der Code zeigt stattdessen eine Typ-Aufschlüsselung („N Einträge · M Aufgaben · …") **ohne** den „zuletzt <…>"-Teil. Das Beispiel war mit „z. B." weich formuliert.
*Empfehlung:* entscheiden — Recency-Hinweis ergänzen **oder** das §8-Beispiel an die (reichere) Typ-Aufschlüsselung anpassen.

**F5 — Pinsel-Icon an Tinten-Einträgen · trivial · Kosmetik**
§3: der Unterschied getippt/handschriftlich „trägt sich von selbst, ganz ohne zusätzliche Deko". `entry_card` setzt neben die Uhrzeit zusätzlich ein kleines `Icons.brush`. Hilfreich, aber streng genommen die eine „Deko", die §3 für unnötig hielt.
*Empfehlung:* bewusst behalten (dann §3 nicht dogmatisch lesen) oder streichen — Ermessen.

**F6 — `thumbPath` vestigial · trivial · Aufräumen**
Feld in Schema + Modell + Lösch-Cleanup vorhanden, aber **nie befüllt**; die Anzeige nutzt überall `filePath` + `cacheWidth`. Für einen Leser nicht als „absichtlich schlafend" erkennbar (anders als das dokumentierte `iCalUID`).
*Empfehlung:* Ein-Zeilen-Doc „reserviert, aktuell ungenutzt" am Modellfeld — oder in einem späteren Schema-Aufräumer entfernen.

**Bewusste Ausnahme (kein Fund):** Foto-Oberflächen nutzen Dunkel-Chrome (Vollbild-Viewer, Scrim-Button). Konventionell für Fotos, aber die einzige Abweichung vom Hell-Prinzip §1 — als bewusste Ausnahme festhalten, damit sie nicht später als Versehen gelesen wird.

---

## Fazit & Empfehlung

Der Code steht kohärent zu `disponere_design_v2_0.md`. Für v1.0 ist inhaltlich nichts offen; die Funde sind Feinschliff.

Vorschlag zur Abarbeitung (kein Zwang, alles reversibel):
- **Eine kleine Fix-Session** für **F1** (Datumsmathematik-Helfer) — der einzige echte Code-Punkt.
- **Ein `docs:`-Durchgang** für **F2 + F3** (Lineal und Farb-Kommentar nachziehen) und die bewusste Dunkel-Chrome-Ausnahme.
- **F4, F5, F6** sind Ermessen — beim nächsten Anfassen der jeweiligen Datei mitnehmen oder bewusst so lassen.

Danach ist Disponere v1.0 sauber durch.
