import Foundation

/// Extracts reusable terminal commands from a project folder.
/// Only lines whose program is on a known allowlist are accepted, so source code,
/// prose, comments and script-internal control flow never become snippets.
struct ProjectAnalyzer {
    struct Finding: Equatable {
        let category: String
        let title: String
        let text: String
    }

    static let ignoredDirectories: Set<String> = [
        "node_modules", "build", "dist", "DerivedData", "Pods", "Carthage", "vendor",
        "venv", "env", "site-packages", "dist-packages", "__pycache__", "target"
    ]
    private static let maxFileSize = 1_000_000
    private static let maxCommandLength = 400

    private static let toolCategories: [String: [String]] = [
        "Git": ["git", "gh", "git-lfs"],
        "Xcode": ["xcodebuild", "xcodegen", "xcrun", "swift", "swiftc", "xcode-select", "codesign", "plutil", "pod", "agvtool", "lipo", "otool", "install_name_tool", "notarytool", "simctl"],
        "Python": ["python", "python3", "pip", "pip3", "pipx", "uv", "poetry", "pytest", "pyenv", "conda", "ruff", "black", "mypy"],
        "Node.js": ["npm", "npx", "node", "yarn", "pnpm", "bun", "deno", "tsc"],
        "Homebrew": ["brew"],
        "Docker": ["docker", "docker-compose", "podman", "kubectl", "helm"],
        "Netzwerk": ["curl", "wget", "ssh", "scp", "sftp", "rsync", "ping", "lsof", "netstat", "nc", "dig", "nslookup", "networksetup", "ifconfig", "traceroute", "ssh-keygen", "ssh-add"],
        "macOS": ["defaults", "launchctl", "diskutil", "hdiutil", "mdfind", "mdls", "mdutil", "open", "pmset", "softwareupdate", "spctl", "xattr", "tccutil", "sw_vers", "system_profiler", "osascript", "caffeinate", "killall", "pkill", "csrutil", "scutil", "log", "sips", "screencapture", "pbcopy", "pbpaste", "ditto", "sysctl", "ioreg", "nvram", "fdesetup", "dscl", "security"],
        "Shell": ["ls", "grep", "rg", "sed", "awk", "find", "fd", "chmod", "chown", "rm", "cp", "mv", "mkdir", "tar", "zip", "unzip", "gzip", "du", "df", "cat", "head", "tail", "sort", "uniq", "wc", "xargs", "jq", "ln", "touch", "tree", "shasum", "md5", "base64", "openssl", "diff", "file", "stat", "tee", "cut", "tr", "ps", "kill", "which", "dd", "xxd", "strings"],
        "Build": ["make", "cmake", "ninja", "cargo", "rustc", "go", "gradle", "mvn"],
        "KI": ["ollama"]
    ]
    private static let categoryByTool: [String: String] = {
        var map: [String: String] = [:]
        for (category, tools) in toolCategories { for tool in tools { map[tool] = category } }
        return map
    }()

    private static let subcommandTitles: [String: [String: String]] = [
        "git": ["status": "Status prüfen", "add": "Änderungen vormerken", "commit": "Commit erstellen", "push": "Änderungen hochladen", "pull": "Änderungen holen", "fetch": "Remote abrufen", "checkout": "Branch wechseln", "switch": "Branch wechseln", "branch": "Branches verwalten", "diff": "Änderungen anzeigen", "log": "Verlauf anzeigen", "clone": "Repository klonen", "merge": "Branches zusammenführen", "rebase": "Rebase ausführen", "stash": "Änderungen parken", "reset": "Zurücksetzen", "restore": "Dateien wiederherstellen", "tag": "Tags verwalten", "remote": "Remotes verwalten", "init": "Repository anlegen", "worktree": "Worktree verwalten", "show": "Commit anzeigen", "rev-parse": "Referenz auflösen", "config": "Konfiguration ändern"],
        "gh": ["pr": "Pull Request verwalten", "repo": "Repository verwalten", "issue": "Issue verwalten", "auth": "Anmeldung verwalten", "run": "Workflow-Läufe anzeigen"],
        "brew": ["install": "Paket installieren", "uninstall": "Paket entfernen", "upgrade": "Pakete aktualisieren", "update": "Paketliste aktualisieren", "list": "Installierte Pakete anzeigen", "search": "Paket suchen", "services": "Dienste steuern", "info": "Paketinfo anzeigen", "doctor": "Installation prüfen", "cleanup": "Aufräumen"],
        "npm": ["install": "Abhängigkeiten installieren", "i": "Abhängigkeiten installieren", "ci": "Saubere Installation", "run": "Skript ausführen", "test": "Tests ausführen", "start": "App starten", "audit": "Sicherheitsprüfung", "ls": "Abhängigkeiten anzeigen", "update": "Pakete aktualisieren", "publish": "Paket veröffentlichen"],
        "pip": ["install": "Paket installieren", "uninstall": "Paket entfernen", "freeze": "Pakete einfrieren", "list": "Pakete anzeigen"],
        "pip3": ["install": "Paket installieren", "uninstall": "Paket entfernen", "freeze": "Pakete einfrieren", "list": "Pakete anzeigen"],
        "xcodebuild": ["test": "Tests ausführen", "build": "Projekt bauen", "archive": "Archiv erstellen", "clean": "Build bereinigen", "-version": "Version anzeigen", "-showsdks": "SDKs anzeigen", "-list": "Schemes anzeigen"],
        "xcrun": ["simctl": "Simulator steuern", "notarytool": "App notarisieren", "stapler": "Notarisierung anheften", "altool": "App hochladen"],
        "swift": ["build": "Paket bauen", "test": "Tests ausführen", "run": "Programm starten", "package": "Paket verwalten"],
        "docker": ["run": "Container starten", "build": "Image bauen", "ps": "Container anzeigen", "compose": "Compose ausführen", "exec": "Befehl im Container", "logs": "Logs anzeigen", "pull": "Image laden", "push": "Image hochladen", "stop": "Container stoppen", "images": "Images anzeigen"],
        "ollama": ["run": "Modell starten", "pull": "Modell laden", "list": "Modelle anzeigen", "serve": "Server starten", "rm": "Modell entfernen"],
        "launchctl": ["load": "Dienst laden", "unload": "Dienst entladen", "list": "Dienste anzeigen", "bootstrap": "Dienst starten", "bootout": "Dienst beenden", "kickstart": "Dienst neu starten"],
        "diskutil": ["list": "Datenträger anzeigen", "info": "Datenträgerinfo", "apfs": "APFS verwalten", "mount": "Volume einhängen", "unmount": "Volume auswerfen", "eraseDisk": "Datenträger löschen", "verifyVolume": "Volume prüfen", "repairVolume": "Volume reparieren"],
        "defaults": ["write": "Einstellung setzen", "read": "Einstellung lesen", "delete": "Einstellung löschen"]
    ]

    private static let toolTitles: [String: String] = [
        "xcodebuild": "Build ausführen", "xcodegen": "Projekt generieren", "xcrun": "Entwicklerwerkzeug ausführen", "swiftc": "Swift kompilieren", "diff": "Dateien vergleichen", "cat": "Datei anzeigen", "head": "Dateianfang anzeigen", "sort": "Sortieren", "wc": "Zählen", "touch": "Datei anlegen", "tree": "Ordnerbaum anzeigen", "base64": "Base64 kodieren", "file": "Dateityp anzeigen", "stat": "Dateiinfo anzeigen", "which": "Programmpfad anzeigen", "mdls": "Metadaten anzeigen", "screencapture": "Bildschirmfoto", "pbcopy": "In Zwischenablage kopieren", "pbpaste": "Aus Zwischenablage einfügen", "ioreg": "Hardware-Registry anzeigen", "nvram": "NVRAM anzeigen", "scutil": "Netzwerkkonfiguration anzeigen", "xxd": "Hexdump anzeigen", "uniq": "Duplikate filtern", "cut": "Spalten ausschneiden", "tr": "Zeichen ersetzen", "tee": "Ausgabe mitschreiben", "dd": "Blockweise kopieren", "strings": "Texte im Binary anzeigen", "gzip": "Komprimieren", "git-lfs": "Große Dateien verwalten", "codesign": "Code signieren", "plutil": "Plist bearbeiten", "pod": "CocoaPods ausführen",
        "python": "Skript ausführen", "python3": "Skript ausführen", "pytest": "Tests ausführen", "pyenv": "Python-Version verwalten", "uv": "Python-Umgebung verwalten",
        "npx": "Paketbefehl ausführen", "node": "Skript ausführen", "yarn": "Paketmanager", "pnpm": "Paketmanager",
        "curl": "HTTP-Anfrage", "wget": "Datei herunterladen", "ssh": "Per SSH verbinden", "scp": "Datei per SSH kopieren", "rsync": "Dateien synchronisieren", "ping": "Erreichbarkeit prüfen", "lsof": "Offene Ports und Dateien anzeigen", "netstat": "Netzwerkverbindungen anzeigen", "dig": "DNS abfragen", "nslookup": "DNS abfragen", "networksetup": "Netzwerk konfigurieren", "ifconfig": "Netzwerkschnittstellen anzeigen", "ssh-keygen": "SSH-Schlüssel erzeugen", "ssh-add": "SSH-Schlüssel hinzufügen",
        "defaults": "Einstellungen ändern", "launchctl": "Dienste steuern", "diskutil": "Datenträger verwalten", "hdiutil": "Disk-Image verwalten", "mdfind": "Spotlight-Suche", "mdutil": "Spotlight-Index verwalten", "open": "Öffnen", "pmset": "Energieeinstellungen", "softwareupdate": "Softwareupdate", "spctl": "Gatekeeper prüfen", "xattr": "Dateiattribute ändern", "tccutil": "Datenschutzfreigaben zurücksetzen", "sw_vers": "macOS-Version anzeigen", "system_profiler": "Systeminfo anzeigen", "osascript": "AppleScript ausführen", "caffeinate": "Ruhezustand verhindern", "killall": "Prozesse beenden", "pkill": "Prozesse beenden", "csrutil": "SIP-Status", "log": "Systemlog anzeigen", "sips": "Bilder bearbeiten", "ditto": "Dateien kopieren", "sysctl": "Kernelwerte anzeigen", "security": "Schlüsselbund verwalten",
        "grep": "Text durchsuchen", "rg": "Text durchsuchen", "sed": "Text ersetzen", "awk": "Text auswerten", "find": "Dateien suchen", "fd": "Dateien suchen", "chmod": "Dateirechte ändern", "chown": "Besitzer ändern", "rm": "Löschen", "cp": "Kopieren", "mv": "Verschieben", "mkdir": "Ordner anlegen", "tar": "Archiv packen/entpacken", "zip": "ZIP erstellen", "unzip": "ZIP entpacken", "du": "Speicherverbrauch anzeigen", "df": "Freien Speicher anzeigen", "ls": "Dateien auflisten", "jq": "JSON auswerten", "ln": "Link anlegen", "shasum": "Prüfsumme berechnen", "openssl": "Kryptografie-Werkzeug", "ps": "Prozesse anzeigen", "kill": "Prozess beenden", "tail": "Dateiende anzeigen", "xargs": "Befehle verketten",
        "make": "Make-Ziel ausführen", "cmake": "CMake ausführen", "cargo": "Rust-Projekt", "go": "Go-Projekt",
        "ollama": "Modell verwalten"
    ]

    /// Tools whose first non-flag argument must be a real subcommand (filters prose like "pip also supports …").
    private static let extraSubcommands: [String: Set<String>] = [
        "git": ["diff-tree", "cherry-pick", "blame", "submodule", "lfs", "apply", "grep", "mv", "rm", "ls-files", "shortlog", "describe", "bisect", "gc", "clean", "am", "format-patch", "reflog", "revert", "notes", "sparse-checkout", "maintenance", "archive", "count-objects", "fsck", "help", "ls-remote", "update-index", "cat-file"],
        "gh": ["release", "gist", "workflow", "api", "browse", "codespace", "label", "secret", "search", "status"],
        "pip": ["show", "download", "wheel", "check", "cache", "config", "debug", "hash", "index", "inspect", "search"],
        "pip3": ["show", "download", "wheel", "check", "cache", "config", "debug", "hash", "index", "inspect", "search"],
        "brew": ["tap", "untap", "outdated", "reinstall", "link", "unlink", "pin", "unpin", "deps", "uses", "home", "config", "bundle", "autoremove", "leaves", "tap-info", "commands", "edit", "fetch", "desc"],
        "npm": ["uninstall", "exec", "init", "pack", "outdated", "version", "link", "cache", "config", "login", "whoami", "view", "fund", "dedupe", "prune", "rebuild", "x", "run-script", "create", "root", "prefix", "doctor", "stop", "restart"],
        "docker": ["rm", "rmi", "inspect", "network", "volume", "system", "tag", "login", "cp", "restart", "start", "kill", "container", "image", "buildx", "stats", "top", "context", "save", "load", "version", "info"],
        "ollama": ["show", "ps", "create", "cp", "push", "stop", "help"],
        "launchctl": ["print", "enable", "disable", "start", "stop", "remove", "submit", "setenv", "getenv", "limit", "asuser", "blame", "managername"],
        "diskutil": ["eject", "rename", "partitionDisk", "resizeVolume", "cs", "secureErase", "activity", "image", "mountDisk", "unmountDisk", "verifyDisk", "repairDisk", "eraseVolume", "enableOwnership"],
        "defaults": ["domains", "find", "export", "import", "read-type", "rename"]
    ]
    private static let knownSubcommands: [String: Set<String>] = {
        var map = extraSubcommands
        for (tool, titles) in subcommandTitles where extraSubcommands[tool] != nil || ["git", "gh", "pip", "pip3", "brew", "npm", "docker", "ollama", "launchctl", "diskutil", "defaults"].contains(tool) {
            map[tool, default: []].formUnion(titles.keys)
        }
        return map
    }()
    /// Common words that only appear in prose (log lines, review notes, docstrings), not in commands.
    private static let proseWords: Set<String> = ["ist", "ein", "eine", "der", "die", "das", "und", "nicht", "weil", "zeigt", "für", "mit", "noch", "dieses", "wird", "wurde", "sich", "auf", "oder", "kein", "keine", "lässt", "bleibt", "the", "and", "is", "are", "to", "of", "which", "should", "also", "that", "this", "will", "can", "be", "not", "was"]

    private static let commandPrefixes: Set<String> = ["sudo", "time", "env", "nohup", "command", "exec"]
    private static let allowedVariables: Set<String> = ["HOME", "USER", "PWD", "PATH", "TMPDIR", "SHELL"]

    // MARK: Line classification

    /// Returns a finding when the line is a standalone, reusable command; otherwise nil.
    static func classify(_ rawLine: String, requirePrompt: Bool = false) -> Finding? {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        var hadPrompt = false
        for prompt in ["$ ", "% ", "❯ ", "> "] where line.hasPrefix(prompt) {
            line = String(line.dropFirst(prompt.count)).trimmingCharacters(in: .whitespaces)
            hadPrompt = true
            break
        }
        if requirePrompt && !hadPrompt { return nil }
        guard !line.isEmpty, !line.hasPrefix("#"), line.count <= maxCommandLength, !line.hasSuffix("\\") else { return nil }
        for ending in [" then", " do", "{", "(", "|", ",", ":"] where line.hasSuffix(ending) { return nil }
        if line.hasSuffix("."), line.dropLast().last?.isLetter == true { return nil }
        guard !usesScriptVariables(line), !looksLikeProse(line),
              line.range(of: #"\{[A-Za-z_][A-Za-z0-9_]*\}"#, options: .regularExpression) == nil else { return nil }

        guard hasBalancedQuotes(line) else { return nil }
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard !tokens.contains("..."), !tokens.contains("="), !tokens.contains("…") else { return nil }
        var index = 0
        while index < tokens.count, commandPrefixes.contains(tokens[index]) || isAssignment(tokens[index]) || (index > 0 && tokens[index - 1] == "sudo" && tokens[index].hasPrefix("-")) {
            if isAssignment(tokens[index]) {
                let value = tokens[index].drop(while: { $0 != "=" }).dropFirst()
                if value.contains("$(") || value.contains("`") || value.hasPrefix("\"") || value.hasPrefix("'") { return nil }
            }
            index += 1
        }
        guard index < tokens.count else { return nil }
        let program = tokens[index].split(separator: "/").last.map(String.init) ?? tokens[index]
        guard !tokens[index].hasPrefix("./"), let category = categoryByTool[program] else { return nil }
        let arguments = Array(tokens[(index + 1)...])
        if let valid = knownSubcommands[program], let sub = arguments.first(where: { !$0.hasPrefix("-") }), !valid.contains(sub) { return nil }
        if ["open", "cat", "rm", "cp", "mv", "chmod", "chown", "ln"].contains(program) { guard arguments.contains(where: { !$0.hasPrefix("-") }) else { return nil } }
        return Finding(category: category, title: title(program: program, arguments: arguments), text: line)
    }

    private static func title(program: String, arguments: [String]) -> String {
        let subcommand = knownSubcommands[program] != nil
            ? arguments.first { !$0.hasPrefix("-") }
            : (arguments.first { subcommandTitles[program]?[$0] != nil } ?? arguments.first { !$0.hasPrefix("-") })
        if program == "python3" || program == "python", arguments.starts(with: ["-m", "venv"]) { return "Python – Virtuelle Umgebung anlegen" }
        if program == "python3" || program == "python", arguments.first == "-m", let module = arguments.dropFirst().first { return "Python – Modul \(module) ausführen" }
        let description = subcommand.flatMap { subcommandTitles[program]?[$0] }
            ?? toolTitles[program]
            ?? subcommand.flatMap { $0.range(of: #"^[A-Za-z][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil ? "\(program) \($0)" : nil }
            ?? "\(program) ausführen"
        return "\(displayName(program)) – \(description)"
    }

    private static func displayName(_ program: String) -> String {
        switch program {
        case "git": return "Git"
        case "gh": return "GitHub CLI"
        case "brew": return "Homebrew"
        case "docker", "docker-compose": return "Docker"
        case "python", "python3": return "Python"
        case "pip", "pip3": return "pip"
        case "xcodebuild", "xcodegen", "xcrun": return "Xcode"
        case "swift", "swiftc": return "Swift"
        case "ollama": return "Ollama"
        default: return program
        }
    }

    private static func looksLikeProse(_ line: String) -> Bool {
        if line.contains(" – ") || line.contains(" — ") || line.contains("…") || line.contains(" ... ") { return true }
        let unquoted = line.replacingOccurrences(of: #""[^"]*"|'[^']*'"#, with: " ", options: .regularExpression)
        let words = unquoted.split(separator: " ").map { $0.lowercased() }
        if words.contains(where: { $0.count > 1 && $0.hasSuffix(":") && !$0.contains("/") && !$0.contains("@") }) { return true }
        return words.filter { proseWords.contains($0) }.count >= 2
    }

    private static func hasBalancedQuotes(_ line: String) -> Bool {
        var single = false, double = false, escaped = false
        for char in line {
            if escaped { escaped = false; continue }
            switch char {
            case "\\" where !single: escaped = true
            case "'" where !double: single.toggle()
            case "\"" where !single: double.toggle()
            default: break
            }
        }
        return !single && !double
    }

    private static func isAssignment(_ token: String) -> Bool {
        token.range(of: #"^[A-Za-z_][A-Za-z0-9_]*=.*$"#, options: .regularExpression) != nil
    }

    /// Lines referencing script-local variables ($1, $DEVICE, ${OUT}) are not reusable on their own.
    private static func usesScriptVariables(_ line: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"\$\{?([A-Za-z_][A-Za-z0-9_]*|[0-9@*#?!])"#) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).contains { match in
            guard let nameRange = Range(match.range(at: 1), in: line) else { return true }
            return !allowedVariables.contains(String(line[nameRange]))
        }
    }

    // MARK: Folder scan

    func scan(directory: URL) throws -> [Finding] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.cannotEnumerate(directory.path)
        }

        var findings: [Finding] = []
        var seen = Set<String>()
        while let fileURL = enumerator.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true {
                let name = fileURL.lastPathComponent
                if Self.ignoredDirectories.contains(name) || name.hasPrefix("SNAPSHOT") { enumerator.skipDescendants() }
                continue
            }
            guard values?.isRegularFile == true, values?.isSymbolicLink != true,
                  (values?.fileSize ?? 0) <= Self.maxFileSize,
                  let kind = FileKind(url: fileURL),
                  let data = try? Data(contentsOf: fileURL),
                  let source = String(data: data, encoding: .utf8) else { continue }
            for finding in Self.extract(from: source, kind: kind) where seen.insert(finding.text).inserted {
                findings.append(finding)
            }
        }
        return findings
    }

    enum FileKind {
        case shell, markdown, makefile, packageJSON

        init?(url: URL) {
            let name = url.lastPathComponent
            if ["Makefile", "makefile", "GNUmakefile"].contains(name) { self = .makefile; return }
            if name == "package.json" { self = .packageJSON; return }
            switch url.pathExtension.lowercased() {
            case "sh", "bash", "zsh", "command": self = .shell
            case "md", "markdown": self = .markdown
            case "mk": self = .makefile
            default: return nil
            }
        }
    }

    static func extract(from source: String, kind: FileKind) -> [Finding] {
        switch kind {
        case .shell:
            return joinedLines(source.components(separatedBy: .newlines)).compactMap { classify($0) }
        case .makefile:
            let recipes = source.components(separatedBy: .newlines).filter { $0.hasPrefix("\t") }.map { line -> String in
                var trimmed = line.trimmingCharacters(in: .whitespaces)
                while let first = trimmed.first, "@-+".contains(first) { trimmed.removeFirst() }
                return trimmed
            }
            return joinedLines(recipes).compactMap { classify($0) }
        case .markdown:
            return markdownCommands(source)
        case .packageJSON:
            guard let object = try? JSONSerialization.jsonObject(with: Data(source.utf8)) as? [String: Any],
                  let scripts = object["scripts"] as? [String: Any] else { return [] }
            return scripts.keys.sorted().map { name in
                Finding(category: "Node.js", title: "npm – Skript „\(name)“ ausführen", text: "npm run \(name)")
            }
        }
    }

    private static let shellFenceLanguages: Set<String> = ["", "bash", "sh", "zsh", "shell", "console", "terminal", "shell-session"]

    private static func markdownCommands(_ source: String) -> [Finding] {
        var findings: [Finding] = []
        var block: [String]?
        var language = ""
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if let lines = block {
                    if shellFenceLanguages.contains(language) {
                        let requirePrompt = language == "console" || language == "terminal" || language == "shell-session"
                        findings += joinedLines(lines).compactMap { classify($0, requirePrompt: requirePrompt) }
                    }
                    block = nil
                } else {
                    language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    block = []
                }
            } else if block != nil {
                block?.append(line)
            }
        }
        return findings
    }

    /// Joins lines that end with a backslash continuation into one command.
    private static func joinedLines(_ lines: [String]) -> [String] {
        var result: [String] = []
        var pending = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("\\") {
                pending += String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces) + " "
            } else {
                result.append(pending + trimmed)
                pending = ""
            }
        }
        if !pending.isEmpty { result.append(pending.trimmingCharacters(in: .whitespaces)) }
        return result
    }

    enum ScanError: LocalizedError {
        case cannotEnumerate(String)

        var errorDescription: String? {
            switch self {
            case .cannotEnumerate(let path): return "Der Ordner konnte nicht durchsucht werden: \(path)"
            }
        }
    }
}
