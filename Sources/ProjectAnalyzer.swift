import Foundation

struct ProjectAnalyzer {
    struct Finding {
        let category: String
        let title: String
        let text: String
    }

    private struct Rule {
        let category: String
        let pattern: String
        let title: (String) -> String
    }

    private let rules: [Rule] = [
        Rule(category: "Git", pattern: #"\bgit\s+status\b"#, title: { _ in "Git – Status prüfen" }),
        Rule(category: "Git", pattern: #"\bgit\s+add\b"#, title: { _ in "Git – Änderungen vormerken" }),
        Rule(category: "Git", pattern: #"\bgit\s+commit\b"#, title: { _ in "Git – Commit erstellen" }),
        Rule(category: "Git", pattern: #"\bgit\s+checkout\b"#, title: { _ in "Git – Branch wechseln" }),
        Rule(category: "Git", pattern: #"\bgit\s+push\b"#, title: { _ in "Git – Änderungen übertragen" }),
        Rule(category: "Git", pattern: #"\bgit\s+diff\b"#, title: { _ in "Git – Änderungen prüfen" }),
        Rule(category: "Xcode", pattern: #"\bxcodebuild\b"#, title: { _ in "Xcode – Build oder Tests ausführen" }),
        Rule(category: "Xcode", pattern: #"\bxcodegen\b"#, title: { _ in "Xcode – Projekt generieren" }),
        Rule(category: "Xcode", pattern: #"\bxcrun\b"#, title: { _ in "Xcode – Entwicklerwerkzeug ausführen" }),
        Rule(category: "Xcode", pattern: #"\bsimctl\b"#, title: { _ in "Xcode – Simulator steuern" }),
        Rule(category: "Python", pattern: #"\bpython3\b"#, title: { _ in "Python – Skript ausführen" }),
        Rule(category: "Python", pattern: #"\bpip3?\b"#, title: { _ in "Python – Pakete verwalten" }),
        Rule(category: "Python", pattern: #"urllib\.request"#, title: { _ in "Python – HTTP-Anfrage" }),
        Rule(category: "Shell", pattern: #"\bsed\b"#, title: { _ in "Shell – Text bearbeiten" }),
        Rule(category: "Shell", pattern: #"\bgrep\b"#, title: { _ in "Shell – Text durchsuchen" }),
        Rule(category: "Shell", pattern: #"\bchmod\b"#, title: { _ in "Shell – Dateirechte ändern" }),
        Rule(category: "Shell", pattern: #"rm\s+-rf"#, title: { _ in "Shell – Rekursiv löschen" })
    ]

    func scan(directory: URL) throws -> [Finding] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.cannotEnumerate(directory.path)
        }

        var findings: [Finding] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true, isCandidate(fileURL) else { continue }
            let data = try Data(contentsOf: fileURL)
            guard let source = String(data: data, encoding: .utf8) else {
                throw ScanError.invalidUTF8(fileURL.lastPathComponent)
            }
            for rawLine in source.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { continue }
                for rule in rules where line.range(of: rule.pattern, options: .regularExpression) != nil {
                    findings.append(Finding(category: rule.category, title: rule.title(line), text: line))
                    break
                }
            }
        }
        return findings
    }

    private func isCandidate(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if ["Makefile", "makefile", "GNUmakefile", "WORKFLOW.md"].contains(name) { return true }
        return ["sh", "py", "md"].contains(url.pathExtension.lowercased())
    }

    enum ScanError: LocalizedError {
        case cannotEnumerate(String)
        case invalidUTF8(String)

        var errorDescription: String? {
            switch self {
            case .cannotEnumerate(let path): return "Der Ordner konnte nicht durchsucht werden: \(path)"
            case .invalidUTF8(let name): return "Die Datei enthält keinen gültigen UTF-8-Text: \(name)"
            }
        }
    }
}
