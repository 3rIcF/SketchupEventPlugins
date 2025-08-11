# agents.md

## Zweck

Diese Datei beschreibt Setup, Regeln, Teststrategie und Releaseprozess, damit (auch autonome) KI-Agenten Änderungen sicher, deterministisch und review-tauglich liefern.

---

## Projektkontext

* **App:** SketchUp-Erweiterung „Elementaro AutoInfo Dev“
* **Ziel:** Modellscan, Tabellen-/Karten-UI, Exportfunktionen, responsive UI in `UI::HtmlDialog`
* **Referenzumgebung:** Windows 11, SketchUp 2025 (Ruby 3.2.2)

---

## Repo-Struktur (Soll)

```
/ (Root)
├─ ElementaroInfoDev/        # Ruby-Code der Dev-Erweiterung
│  ├─ main.rb
│  ├─ ui/                    # HTML/CSS/JS für HtmlDialog
│  ├─ lib/                   # Hilfsklassen (Scanning, Caching, Export)
│  └─ assets/                # Icons, statische Dateien
├─ tests/
│  ├─ unit/                  # Ruby-Unit-Tests (TestUp/Minitest)
│  └─ ui/                    # UI-Snapshots & HTML-Lint
├─ tools/
│  ├─ build.rb               # RBZ-Packaging
│  └─ smoke.rb               # lokale Smoke-Checks
├─ .rubocop.yml
├─ .editorconfig
├─ .github/workflows/ci.yml
├─ CHANGELOG.md
├─ VERSION
└─ agents.md                 # diese Datei
```

---

## Quickstart für Agenten (Checkliste)

1. **Repo einlesen:** Erzeuge Repo-Karte (Dateiliste, Abhängigkeiten, TODO-Hotspots).
2. **Lokal prüfen:** `ruby -v` (3.2.x), RuboCop, HTML/CSS/JS-Lint laufen lassen.
3. **Unit-Tests:** mit TestUp (Minitest) ausführen.
4. **Smoke-Run:** SketchUp starten → Erweiterung laden → HtmlDialog öffnen → Basisflows testen.
5. **Issue wählen:** kleinster *ready* Task aus dem Backlog.
6. **Branch:** `feat/…`, `fix/…` oder `chore/…`.
7. **Implementieren:** Styleguide & DoD beachten (siehe unten).
8. **PR öffnen:** Template ausfüllen, Checks müssen grün sein.
9. **Reviewerhinweise:** Was wurde gemessen? (Zeit, Speicher, UI-Layoutdiffs)

---

## Entwicklungsumgebung

* **SketchUp 2025** (Ruby 3.2.2) – Zielplattform; optional Smoke auf 2024.
* **Ruby-Tools lokal:**

  * `rubocop`, `minitest`, `testup-2` (Trimble TestUp)
  * HTML/CSS Lint (z. B. `htmlhint`, `stylelint`) – via Node optional
* **Pfad für Dev-Load:**

  * `%APPDATA%\SketchUp\SketchUp 2025\SketchUp\Plugins\`
  * Loader-Datei `elementaro_autoinfo_dev.rb` lädt `ElementaroInfoDev/main.rb`.

---

## Build & Run

* **RBZ bauen (offline):**

  ```bash
  # Ruby
  ruby tools/build.rb  # erzeugt dist/elementaro_autoinfo_dev.rbz
  ```
* **Manuell laden:** SketchUp → Erweiterungs-Manager → „Erweiterung installieren…“ → RBZ.
* **Dev-Modus:** Dateien direkt im Plugins-Ordner austauschen → SketchUp neu starten.

---

## Tests

### 1) Unit (Ruby, Logik)

* Framework: **Minitest** (über **TestUp**).
* Fokus: Parser, Scanner, Caches, Export, Observer-Lifecycle.
* Start (Beispiel):

  ```ruby
  # in SketchUp via TestUp: Window → TestUp → Run All
  ```

### 2) Lint/Static

* **RuboCop**: Style & Komplexität (CI-gate).
* **HTML/CSS/JS-Lint**: Struktur, Barrierefreiheit-Basis (Tabbability, Kontraste).

### 3) UI-Snap & Verhalten

* **Snapshots**: HTML gerendert (Puppeteer/Playwright headless) gegen `ui/` (ohne SketchUp-APIs).
* **Heuristiken:** Minimalbreite Tabelle, Sticky-Header vorhanden, Sidebar kollabiert < 1100 px.

### 4) Smoke-Plan (manuell/halbautomatisiert)

* Öffnen/Schließen des Panels ohne Exceptions.
* Scan großer Modelle (≥100k Entities) → keine UI-Blockade > 1 s auf UI-Thread.
* Filter an/aus, Sortierung, Paging.
* Export CSV/JSON erzeugt, Pfade gültig.
* Observer korrekt deregistriert nach Dialog-Close.

---

## Qualitäts-Gates (Definition of Done)

* **CI grün:** RuboCop, Unit-Tests, HTML/CSS/JS-Lint, Build artefakt vorhanden.
* **Performance:** Keine UI-Blockade > 100 ms für UI-Interaktionen; lange Jobs asynchron.
* **Stabilität:** Keine offenen Observer nach Schließen; keine globalen Leaks.
* **UX:** Responsive (≥800 px), Tastatur-Fokus sichtbar, lesbare Tabellen (min-width + Scroll).
* **Docs:** CHANGELOG.md & PR-Beschreibung aktualisiert, User-Facing Änderungen dokumentiert.

---

## Coding-Konventionen

* **Ruby:** RuboCop (Rails-frei), Frozen-String-Literals, `Module.method` statt Globals.
* **UI:** Keine Inline-Styles außer für SketchUp-spezifische Workarounds; BEM-Klassen.
* **Threads/Timer:** Lange Operationen → `UI.start_timer(0, false)` + Batch/Chunking; Dialog über `execute_script` progress-updates liefern.
* **Observer:** Registrierung zentral, **Abmeldung garantiert** (`set_on_closed`-Hook).

---

## Architektur-Notizen (Kurz)

* **`ElementaroInfoDev::App`** – Einstieg, Dialog-Lifecycle, Observer-Mgmt.
* **`lib/scanner.rb`** – Traversal, Chunking, Caches.
* **`lib/exporter.rb`** – CSV/JSON.
* **`ui/`** – HtmlDialog (responsive Layout, Sticky-Header-Tabelle, Sidebar-Toggle).
* **Kommunikation:** `dialog.add_action_callback` ⇄ `execute_script` (nur JSON-Serialisierung).

---

## Sicherheits- & Datenschutzregeln

* **Keine externen HTTP-Requests** ohne Freigabe.
* **Dateizugriffe** nur unter `Sketchup.temp_dir` oder vom Benutzer gewählten Pfaden.
* **Crash-Logs** ohne Modellinhalte; PII vermeiden.

---

## Releaseprozess

1. `VERSION` anheben, CHANGELOG pflegen.
2. Build: `ruby tools/build.rb` → `dist/*.rbz`.
3. Tag: `vX.Y.Z`, Release-Notes (Highlights, Fixes, Migrationshinweise).
4. Smoke auf „clean“ SketchUp-Profil (ohne weitere Plugins).

---

## CI (Beispiel)

`.github/workflows/ci.yml` (Ausschnitt)

```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.2' }
      - run: gem install rubocop
      - run: rubocop
      - run: ruby tools/build.rb
      - name: Archive RBZ
        uses: actions/upload-artifact@v4
        with: { name: rbz, path: dist/*.rbz }
```

---

## PR-Template (Kurz)

```
### Zweck
Fix/Feature in einem Satz.

### Änderungen
- …

### Tests
- Unit: …
- UI: …
- Smoke: …

### Risiken & Rollback
- Risiko …
- Rollback: Vorversion RBZ einspielen.
```

---

## Issue-Labels (Vorschlag)

* `type:bug`, `type:feature`, `type:chore`, `area:ui`, `area:scanner`, `perf`, `good first issue`, `needs design`, `blocked`.

---

## Start-Backlog (für Agenten)

* **UI:** Tabellen-Minbreite + horizontales Scrollen im List-Container, Sidebar-Auto-Kollaps < 1100 px.
* **Stabilität:** Einheitliche `detach_observers`-Routine & Tests.
* **Performance:** Scanner-Chunking konfigurieren (`CHUNK_SIZE`), Progress-Events.
* **DX:** `tools/smoke.rb` implementieren (Basischecks), `tools/build.rb` robust gegen fehlende Ordner.
* **Tests:** TestUp-Suite für Exportformate & Edgecases (leere Attribute, sehr tiefe Verschachtelung).
* **Docs:** Screenshots der UI-Breakpoints, kurze Nutzerhilfe.

---

## Artefakt-Namen

* RBZ: `elementaro_autoinfo_dev-v<version>.rbz`
* Logs: `elementaro_autoinfo_dev-YYYYMMDD-HHMM.log`

---

## Kontaktpunkte

* Code-Owner: `@maintainer`
* Sicherheitsmeldungen: `security@domain.tld` (privat)

---

> Hinweis für autonome Agenten: Halte dich strikt an DoD & Sicherheitsregeln. Erzeuge kleine, überprüfbare PRs; dokumentiere Messwerte (Zeit/MB) und UI-Änderungen mit Snapshots.
