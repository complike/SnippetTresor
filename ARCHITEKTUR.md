# Architektur

Diese Datei ist der deutsche Einstieg zur Architektur-Dokumentation. Die verbindliche technische Übersicht, Datenflüsse, Persistenzstrategie und Python-Parität stehen in [ARCHITECTURE.md](ARCHITECTURE.md).

Die App besteht aus dem Codable-Modell `Snippet`, dem `SnippetStore` für CRUD und JSON-Persistenz, der SwiftUI-Oberfläche und dem App-Einstiegspunkt. Zusätzliche unbekannte JSON-Felder werden als JSON-Werte erhalten, damit bestehende Python-Datensätze bei Änderungen nicht stillschweigend Informationen verlieren.
