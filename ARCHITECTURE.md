# Architektur

- `Sources/Snippet.swift`: Codable-Datenmodell, rekursive JSON-Werte für unbekannte Legacy-Felder und lokalisierte Validierungsfehler.
- `Sources/SnippetStore.swift`: zentrale CRUD-Logik, JSON-Validierung, Suche/Filter, Zwischenablage und atomare Persistenz.
- `Sources/ContentView.swift`: NavigationSplitView, Kategorien, Suche, Karten, Editor-Sheet und native Alerts.
- `Sources/SnippetTresorApp.swift`: App-Lifecycle und Tastenkürzel.
- `Resources/Assets.xcassets`: App-Icon.
- `Tests/SnippetStoreTests.swift`: XCTest für CRUD/Validierung, unbekannte JSON-Felder, fehlerhafte JSON und fehlgeschlagenes initiales Schreiben.

## Persistenz und Sicherheit
Das JSON bleibt ein Array von Objekten mit `title`, `category` und `text`. Ein optionales `id`-Feld dient der stabilen SwiftUI-Identität. Weitere unbekannte JSON-Felder werden als rekursive `JSONValue` gespeichert und bei Bearbeitung/Schreiben erhalten. Kodierte Daten werden mit `Data.write(options: .atomic)` ersetzt. Bei Ladefehlern wird die vorhandene Datei nicht automatisch zurückgesetzt oder überschrieben.

## Python-Parität
Erhalten bleiben Standarddatensätze, Kategorien, Teilstringsuche über Titel/Kategorie/Text, Pflichtfeldvalidierung, CRUD und Kopierfunktion. Die Oberfläche ist vollständig nativ mit SwiftUI und SF Symbols.
