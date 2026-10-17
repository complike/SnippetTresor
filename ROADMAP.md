# Status und offene Punkte

- [x] SwiftUI CRUD-Oberfläche und Kategorien
- [x] JSON Codable-Modell mit Legacy-Datei-Kompatibilität
- [x] Atomare JSON-Schreibvorgänge
- [x] Native Zwischenablage und Fehler-/Löschdialoge
- [x] XcodeGen-Konfiguration, App-Icon und Build-Skript
- [x] Automatisierte Swift-Tests für CRUD, JSON-Felder, Fehlerfälle, alle Analyzer-Dateitypen und idempotenten erneuten Scan/Import
- [x] Projekt-Analyzer mit NSOpenPanel, Regex-Klassifikation und Deduplizierung
- [x] GUI-Manuelltest auf dem Ziel-Mac (vom Nutzer bestätigt: Projektordner gewählt und Snippet-Import erfolgreich)
- [ ] Codesigning/Notarisierung für Verteilung außerhalb des lokalen Rechners

## Reviewer Runde 5

- F-2 [NIEDRIG] FIXED: `Tests/SnippetStoreTests.swift` prüft `.sh`, `.py`, `.md`, `WORKFLOW.md`, `Makefile`, `makefile` und `GNUmakefile` jeweils in getrennten Unterordnern (auch auf case-insensitiven Dateisystemen), ignorierte Dateitypen sowie wiederholten Scan und Import ohne Duplikate.
- F-3 [NIEDRIG] ABGELEHNT (nicht-blockierender Metadatenunterschied): XcodeGen regeneriert `BuildableName` als `SnippetTresor.app` anhand des Targetnamens. Der reale Produktpfad wird über `PRODUCT_NAME: Snippet-Tresor` festgelegt; `scripts/build.sh` prüft und kopiert genau `Snippet-Tresor.app`, und Test-Host sowie Release-Build verwenden diesen Pfad erfolgreich. Eine manuelle Änderung der generierten Scheme-Datei wird beim nächsten `xcodegen generate` überschrieben. Keine funktionale Beeinträchtigung nachgewiesen.
