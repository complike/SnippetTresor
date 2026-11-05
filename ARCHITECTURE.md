# Architektur

- `Sources/Snippet.swift`: Codable-Datenmodell, rekursive JSON-Werte für unbekannte Legacy-Felder und lokalisierte Validierungsfehler.
- `Sources/SnippetStore.swift`: CRUD-Logik, Suche/Filter, Zwischenablage, deduplizierter Import und atomare Persistenz.
- `Sources/ProjectAnalyzer.swift`: rekursive Dateisuche, Regex-Klassifikation und Titelgenerierung ohne KI oder Netzwerk.
- `Sources/ContentView.swift`: native SwiftUI-Oberfläche, Ordnerauswahl per NSOpenPanel, Editor und Alerts.
- `Sources/SnippetTresorApp.swift`: App-Lifecycle und Tastenkürzel.
- `Tests/SnippetStoreTests.swift`: XCTest für CRUD, Legacy-Felder und Fehlerfälle.

## Projekt-Analyzer

„Projekt scannen“ (Toolbar-Button oder Menü „Ablage → Projekt scannen …“, ⇧⌘O) öffnet einen NSOpenPanel. Übernommen werden nur echte, eigenständig wiederverwendbare Terminal-Befehle:

| Quelle | Was übernommen wird |
| --- | --- |
| `.sh`, `.bash`, `.zsh`, `.command` | Befehlszeilen (Fortsetzungen mit `\` werden zusammengefügt) |
| `.md`, `.markdown` | nur Zeilen in Code-Blöcken (```` ```bash ````, `sh`, `zsh`, `shell`, ohne Sprache; bei `console` nur Zeilen mit `$ `-Prompt) – Fließtext wird ignoriert |
| `Makefile`, `*.mk` | Rezeptzeilen (Tab-eingerückt, `@`/`-` am Anfang entfernt) |
| `package.json` | `scripts` als `npm run <name>` |

Python-Quellcode (`.py`) wird nicht mehr gelesen. Ignoriert werden versteckte Ordner sowie `node_modules`, `build`, `dist`, `DerivedData`, `Pods`, `venv`, `site-packages`, `vendor`, `SNAPSHOT*` u. a.

Eine Zeile gilt nur als Snippet, wenn ihr Programm (nach `sudo`/`env`/Variablenzuweisungen) auf der Allowlist in `ProjectAnalyzer.toolCategories` steht. Daraus ergibt sich die Kategorie: Git, Xcode, Python, Node.js, Homebrew, Docker, Netzwerk, macOS, Shell, Build, KI. Verworfen werden Kommentare, Kontrollstrukturen (`if`, `for`, …), `echo`/`cd`, lokale Skripte (`./…`) und Zeilen mit skriptinternen Variablen (`$1`, `$DEVICE`, `${OUT}`; erlaubt sind `$HOME`, `$USER`, `$PWD`, `$PATH`, `$TMPDIR`, `$SHELL`). Titel werden auf Deutsch aus Programm und Unterbefehl erzeugt (z. B. „Git – Änderungen hochladen“).

Importierte Snippets erhalten das Zusatzfeld `"quelle": "Projekt-Scan"`. „Ablage → Importierte Snippets bereinigen …“ prüft alle gescannten Einträge (inkl. der Titel des alten Analyzers) erneut mit `ProjectAnalyzer.classify`, entfernt Nicht-Befehle, korrigiert Kategorie/Titel und legt vorher `prompts.backup-<Zeitstempel>.json` neben der Bibliothek an. Manuell angelegte Snippets bleiben unverändert.

Der Import vergleicht den exakten Befehlstext mit vorhandenen Snippets und dedupliziert auch Funde innerhalb desselben Scans. Speichern läuft über `Data.write(options: .atomic)`; unbekannte JSON-Felder bleiben erhalten.

## Online-Dashboard

Nach jedem Speichern startet `scripts/deploy_to_github_pages.sh` (nur auf `main`, serialisiert über eine Sperre in `.git/`, vorher `git pull --ff-only`) und veröffentlicht `web/prompts.json` auf https://complike.github.io/SnippetTresor/web/. Die Seitenleiste der App zeigt den Link und den Upload-Status; „Hilfe → Online-Dashboard öffnen“ und der Globus-Button öffnen die Seite.

## Persistenz und Sicherheit

Das JSON bleibt ein Array von Objekten mit `title`, `category` und `text`. Ein optionales `id`-Feld dient der stabilen SwiftUI-Identität. Weitere unbekannte JSON-Felder werden als rekursive `JSONValue` gespeichert und beim Bearbeiten/Schreiben erhalten. Bei Ladefehlern wird die vorhandene Datei nicht automatisch zurückgesetzt oder überschrieben.

## Python-Parität

Erhalten bleiben Standarddatensätze, Kategorien, Suche, Pflichtfeldvalidierung, CRUD und Kopierfunktion. Die Oberfläche ist nativ mit SwiftUI und SF Symbols.
