# Architektur

- `Sources/Snippet.swift`: Codable-Datenmodell, rekursive JSON-Werte für unbekannte Legacy-Felder und lokalisierte Validierungsfehler.
- `Sources/SnippetStore.swift`: CRUD-Logik, Suche/Filter, Zwischenablage, deduplizierter Import und atomare Persistenz.
- `Sources/ProjectAnalyzer.swift`: rekursive Dateisuche, Regex-Klassifikation und Titelgenerierung ohne KI oder Netzwerk.
- `Sources/ContentView.swift`: native SwiftUI-Oberfläche, Ordnerauswahl per NSOpenPanel, Editor und Alerts.
- `Sources/SnippetTresorApp.swift`: App-Lifecycle und Tastenkürzel.
- `Tests/SnippetStoreTests.swift`: XCTest für CRUD, Legacy-Felder und Fehlerfälle.

## Projekt-Analyzer

Der Button „Projekt scannen“ öffnet einen NSOpenPanel als asynchrones Sheet am aktiven `NSApp.keyWindow`. Durchsucht werden rekursiv `.sh`, `.py`, `.md`, `WORKFLOW.md` und Makefiles. Jede nichtleere Zeile wird anhand dieser Matrix klassifiziert:

| Kategorie | Regex-Muster |
| --- | --- |
| Git | `git status`, `git add`, `git commit`, `git checkout`, `git push`, `git diff` |
| Xcode | `xcodebuild`, `xcodegen`, `xcrun`, `simctl` |
| Python | `python3`, `pip`/`pip3`, `urllib.request` |
| Shell | `sed`, `grep`, `chmod`, `rm -rf` |

Pro Zeile wird die erste passende Regel übernommen. Die Titel werden anhand der Regel automatisch auf Deutsch erzeugt. Der Import vergleicht den exakten Befehlstext mit vorhandenen Snippets und dedupliziert auch Funde innerhalb desselben Scans. Speichern läuft weiterhin über `Data.write(options: .atomic)`; unbekannte JSON-Felder vorhandener Einträge bleiben erhalten. Scan- und Speicherfehler werden über `store.errorMessage` im SwiftUI-Alert angezeigt.

## Persistenz und Sicherheit

Das JSON bleibt ein Array von Objekten mit `title`, `category` und `text`. Ein optionales `id`-Feld dient der stabilen SwiftUI-Identität. Weitere unbekannte JSON-Felder werden als rekursive `JSONValue` gespeichert und beim Bearbeiten/Schreiben erhalten. Bei Ladefehlern wird die vorhandene Datei nicht automatisch zurückgesetzt oder überschrieben.

## Python-Parität

Erhalten bleiben Standarddatensätze, Kategorien, Suche, Pflichtfeldvalidierung, CRUD und Kopierfunktion. Die Oberfläche ist nativ mit SwiftUI und SF Symbols.
