# SketchupEventPlugins
SketchupPlugins für Eventmanagement, Lieferanten, Baupläne etc Mangement

## Smoke Checks

Lokale Basisprüfungen lassen sich mit folgendem Befehl ausführen:

```bash
ruby tools/smoke.rb
```

Das Skript führt RuboCop, alle Unit-Tests, den Build-Prozess sowie ein HTML-Lint für `ElementaroInfoDev/ui` aus. Fehlen benötigte Ordner oder Dateien, bricht es mit einer verständlichen Meldung ab.
