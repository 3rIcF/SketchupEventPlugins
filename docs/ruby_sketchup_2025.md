# Ruby in SketchUp 2025 (Windows)

Diese Notizen fassen wichtige Aspekte der Ruby-Umgebung in SketchUp 2025 zusammen.
Sie dienen als Leitfaden für Agenten, die Erweiterungen entwickeln oder warten.

## Laufzeit
- **Version:** Ruby 3.2.2 (64-bit) eingebettet in SketchUp.
- **Plattform:** Windows 11, Prozessarchitektur x64.
- **Gems:** Nur reine Ruby-Gems laufen ohne Weiteres. Native Erweiterungen müssen für
  MSVC kompiliert sein und sind in CI nicht verfügbar.

## SketchUp API Basics
- Einstiegspunkt ist `Sketchup.active_model`.
- UI-Elemente werden über `UI::HtmlDialog` bzw. klassische Menüs erstellt.
- Kommunikation Dialog ↔ Ruby via `add_action_callback` und
  `execute_script` (JSON-Daten).
- Beobachterklassen (`ModelObserver`, `SelectionObserver` etc.) melden
  Modelländerungen. Abmeldung erfolgt im `set_on_closed`-Hook.

## Syntax & Stil
- Moderne Ruby-Features wie Pattern Matching, endlose Methoden und
  nummerierte Parameter stehen zur Verfügung.
- Strings standardmäßig immutable machen: `# frozen_string_literal: true`.
- Module statt globale Variablen nutzen; Methoden mit `module_function`
  oder `extend self` bereitstellen.
- Fehlerbehandlung über spezifische Exception-Klassen (`rescue
  StandardError => e`).

## Datei & Pfade
- Temporäre Dateien unter `Sketchup.temp_dir` ablegen.
- Benutzerpfade über Dialoge wie `UI.savepanel` erfragen.
- Keine Netzwerkzugriffe ohne explizite Freigabe (siehe AGENTS.md).

## Test & Lint
- Unit-Tests mit `minitest`/`testup`.
- Linting via `rubocop` (Rails-Plugin geladen), HTML/CSS/JS-Lint für
  UI-Dateien.

Diese Datei dient als Ausgangspunkt; bei API-Änderungen von SketchUp oder
Ruby bitte aktualisieren.
