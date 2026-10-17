# Entwicklungs-Workflow

1. Voraussetzungen prüfen: `xcodebuild -version`, `swift --version`, `xcodegen --version`.
2. Projekt generieren: `xcodegen generate --spec project.yml`.
3. Unit-Tests: `xcodebuild test -project SnippetTresor.xcodeproj -scheme SnippetTresor -destination 'platform=macOS' -derivedDataPath build/DerivedData test`.
4. Release-Build und App-Bundle: `./scripts/build.sh`.
5. GUI-Manuelltest: Start, Suche, Kategorie, CRUD, Neustart/Persistenz sowie „Projekt scannen“ mit Testordner, allen vier Kategorien, erneutem Scan und fehlenden Leserechten prüfen.
6. Vor Commit: `git diff --check` und Release-Build erneut ausführen.

Analyzer-Dateien: `Sources/ProjectAnalyzer.swift`; Import und Deduplizierung: `Sources/SnippetStore.swift`; UI/NSOpenPanel: `Sources/ContentView.swift`. Keine Nutzerdaten oder Geheimnisse in Testdaten aufnehmen. Generierte Build-Artefakte nicht committen.
