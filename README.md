# Snippet-Tresor (SwiftUI)

Native macOS-App zum lokalen Verwalten, Suchen und Bearbeiten von Snippets. Der integrierte Projekt-Analyzer importiert passende Befehlszeilen aus einem ausgewählten Quellprojekt – ohne KI und ohne Netzwerkzugriff.

## Voraussetzungen

- macOS 14 oder neuer
- Xcode 27.1 / Swift 6.4 und Apple Silicon
- XcodeGen (`brew install xcodegen`)

## Build und Tests

- Projekt generieren: `xcodegen generate --spec project.yml`
- Release-App bauen und bereitstellen: `./scripts/build.sh`
- Tests: `xcodebuild test -project SnippetTresor.xcodeproj -scheme SnippetTresor -destination 'platform=macOS' -derivedDataPath build/DerivedData test`

Das Build-Skript legt `dist/Snippet-Tresor.app` an.

## Projekt scannen

„Projekt scannen“ öffnet einen nativen Ordnerdialog. Der Analyzer durchsucht rekursiv `.sh`, `.py`, `.md`, `WORKFLOW.md` und Makefiles und klassifiziert erkannte Befehle als Git, Xcode, Python oder Shell. Bereits vorhandene identische Befehlstexte werden übersprungen. Einzelheiten zur Regex-Matrix stehen in `ARCHITECTURE.md`.

## Daten

Die App speichert `prompts.json` unter `~/Library/Application Support/Snippet-Tresor/`. Bestehende Python-Datensätze sind kompatibel. Unbekannte JSON-Felder bleiben erhalten und Schreibvorgänge sind atomar. Fehlerhafte oder unlesbare Dateien werden nicht automatisch überschrieben; Fehler erscheinen in der App.

## Manueller GUI-Test

Vor Freigabe den Start, CRUD, Neustart/Persistenz, den Projektordnerdialog, Klassifikation, erneuten Scan ohne Duplikate und Fehlerfälle manuell prüfen.
