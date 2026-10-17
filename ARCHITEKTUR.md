# Architektur

Die maßgebliche Architekturübersicht steht in `ARCHITECTURE.md`. Der Projekt-Analyzer ist in `Sources/ProjectAnalyzer.swift` implementiert und wird über die SwiftUI-Oberfläche und `SnippetStore` integriert. Er klassifiziert Zeilen aus Shell-, Python-, Markdown-, Workflow- und Makefile-Dateien anhand einer festen Regex-Matrix; KI und Netzwerk werden nicht verwendet. Importierte Befehle werden dedupliziert und atomar gespeichert. Legacy-Zusatzfelder bleiben erhalten.
