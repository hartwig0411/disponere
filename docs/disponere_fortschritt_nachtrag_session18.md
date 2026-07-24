### Nachtrag Juli 2026 — Hub-Konto & Business-Adresse (Entscheidung revidiert)

Die in Session 18 dokumentierte Entscheidung („zurückgestellt, Workspace zu teuer") ist
überholt. Ausserhalb der Disponere-Sessions wurde die Infrastruktur aufgebaut:

- **Google Workspace Business Starter** eingerichtet (6,80 €/Monat)
- **`steffen@harder-business.com`** ist jetzt vollwertige Google-Identität mit eigenem Gmail
  und eigenem Google-Kalender
- **Domain `harder-business.com`** bei IONOS, DNS auf Google umgestellt
- **Proton Unlimited** gekündigt (läuft bis 04.12.2026 aus, Adresse bleibt danach kostenlos)

**Konsequenz für Disponere:** `steffen@harder-business.com` hat eine eigene `calendarId`
in der Google Calendar API — wird in Coding-Session A/B als separater Kalender eingebunden
und per Tag-Mapping (`#Business` o. ä.) ins Journal gesurfaced. Genau die in Session 10
vorgesehene Architektur.
