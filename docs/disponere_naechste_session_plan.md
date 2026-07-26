# Disponere — Fahrplan naechste Session(en)

*Am Ende der Design-Session (26. Juli 2026) vereinbart. Grundlage der Umsetzung: `disponere_design_v1_0.md`.*

## Reihenfolge (nicht vertauschen)

1. **Theme umsetzen (hell)** — risikoarm, im Kern Umfaerben.
   Farben, Typografie (zweizeiliger Datumskopf), Tinte-auf-hell, Tagesinfo-Band oben, leerer Heute-Zustand, untere Icon-Leiste (Journal, Suche, Aufgaben, Neuer Eintrag; Funkel oben rechts).

2. **Tag-Ansicht (neuer Screen)** — eigener Schritt, kein blosses Umfaerben.
   - Repository: Abfrage „alles zu Tag X ueber alle Tage" (Eintraege, Aufgaben inkl. Status, Termine, Tagesinfo, Tinte).
   - Neuer Screen: Kopf = Tag im Akzentblau + Zaehler; Inhalt nach Tagen gruppiert, **neu nach alt**.
   - Tipp auf beliebiges `#Tag` → Navigation in diese Ansicht.

3. **Erst neu rein + auf dem MatePad testen, DANN Altes rauswerfen** (eigener Commit).
   Reihenfolge bewusst so — es bleibt immer ein funktionierender Rueckweg.

4. **Fable-Review** — erst *nach* Umsetzung und Aufraeumen, damit der echte Stand geprueft wird.
   Fokus vorgeben: „Design-Kohaerenz gegen `disponere_design_v1_0.md`, Robustheit, Flutter-Konventionen".
   Laeuft im Chat ueber das Abo — unabhaengig von der gesperrten API.

5. **Erstmals mit Disponere arbeiten.**

6. **Claude-API-Anbindung in der App** — erst wenn die Organisation wieder frei ist (Einspruch offen). Bis dahin nichts zu tun als warten.

## Budget-Hinweis

Theme und Tag-Ansicht fassen zwei der groessten Dateien an (`journal_repository.dart` ~1148 Zeilen, Journal-Screen groesser) und werden nach der Komplett-Datei-Regel jeweils ganz geliefert. Das sind zwei grosse Lieferungen plus ein neuer Screen — **nach dem Reset mit vollem Budget starten**. Reicht es nicht fuer beides: **Theme zuerst**, Tag-Ansicht als eigener Schritt danach.

---
