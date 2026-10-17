# Entwicklungs-Workflow

1. Voraussetzungen: `xcodebuild -version`, `swift --version`, `xcodegen --version`.
2. Projekt generieren: `xcodegen generate --spec project.yml`.
3. Tests: `xcodebuild test -project SnippetTresor.xcodeproj -scheme SnippetTresor -destination 'platform=macOS' -derivedDataPath build/DerivedData test`.
4. Release-Build: `xcodebuild -project SnippetTresor.xcodeproj -scheme SnippetTresor -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData build`.
5. App-Bundle nach `dist/Snippet-Tresor.app` kopieren: `./scripts/build.sh`.
6. GUI manuell prüfen: Start, Suche, Kategorie, Hinzufügen, Bearbeiten, Kopieren, Löschen/Abbrechen, Neustart/Persistenz sowie beschädigte JSON-Datei.
7. Vor Commit: `git diff --check` und Build erneut ausführen.

Keine Nutzerdaten oder Geheimnisse in Testdaten aufnehmen. Generierte Build-Artefakte nicht committen.
