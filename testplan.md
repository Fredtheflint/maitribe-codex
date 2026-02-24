# MaiTribe Deploy-Testplan

## Pre-Deploy
- [ ] JS Syntax Check bestanden
- [ ] `git status` clean
- [ ] Keine `console.log` Debug-Statements mehr drin (ausser `[MaiTribe]` prefix)

## Auth
- [ ] Magic Link Login funktioniert
- [ ] Session bleibt nach Page Reload
- [ ] Logout funktioniert
- [ ] Rate Limit zeigt freundliche Nachricht

## Home Screen
- [ ] Korrekter Name (nicht Email-Prefix)
- [ ] Korrekte Tageszeit-Begruessung
- [ ] Identity wird angezeigt (wenn vorhanden)
- [ ] Letzter Impuls wird angezeigt (wenn vorhanden)

## Chat
- [ ] Opening Message auf Deutsch (wenn Sprache DE)
- [ ] Nachricht senden -> Antwort kommt
- [ ] Antwort ist vollstaendig (nicht abgeschnitten)
- [ ] Antwort ist auf der richtigen Sprache
- [ ] Keine generischen Atemuebungen als alleiniger Tipp
- [ ] Bei Themenwechsel: Mai wechselt mit
- [ ] Kein Tipp wird doppelt vorgeschlagen

## Check-in
- [ ] Slider funktionieren (Body, Mind, Soul, Energy)
- [ ] Reflexion wird generiert nach Submit
- [ ] Low Battery Protocol bei Energy 1-2

## Identity
- [ ] Neue Identity erstellen
- [ ] Bestehende Identity aendern
- [ ] Identity wird auf Home Screen angezeigt

## Profil
- [ ] Name aendern funktioniert
- [ ] Sprache aendern funktioniert
- [ ] Gemini API Key speichern funktioniert

## Performance
- [ ] Seite laedt in < 3 Sekunden
- [ ] Keine Console Errors (ausser erwartete Warnungen)
- [ ] Service Worker updated korrekt
