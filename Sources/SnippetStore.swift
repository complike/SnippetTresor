import Foundation
import AppKit
import Combine

@MainActor final class SnippetStore: ObservableObject {
 static let dashboardURL = URL(string: "https://complike.github.io/SnippetTresor/web/")!
 static let scanSourceKey = "quelle"
 static let scanSourceValue = "Projekt-Scan"

 enum SyncState: Equatable {
  case idle, running, success(Date), failed(String), disabled
 }
 struct CleanupPlan: Identifiable {
  let id = UUID()
  let removals: Int
  let updates: Int
  let result: [Snippet]
 }

 @Published private(set) var snippets: [Snippet] = []
 @Published var errorMessage: String?
 @Published var noticeMessage: String?
 @Published var editorRequest: EditorRequest?
 @Published var pendingDelete: Snippet?
 @Published var pendingCleanup: CleanupPlan?
 @Published private(set) var isScanning = false
 @Published private(set) var syncState: SyncState = .idle
 struct EditorRequest: Identifiable { let id = UUID(); let snippet: Snippet? }
 private let fileURL: URL
 private let encoder: JSONEncoder
 private let decoder = JSONDecoder()
 private var loadFailed = false

 /// Title → (category, regex) of the first analyzer version. Its imports carry no source marker,
 /// so an entry only counts as one if title, category and single-line text all match the rule that produced it.
 static let legacyScanRules: [String: (category: String, pattern: String)] = [
  "Git – Status prüfen": ("Git", #"\bgit\s+status\b"#), "Git – Änderungen vormerken": ("Git", #"\bgit\s+add\b"#),
  "Git – Commit erstellen": ("Git", #"\bgit\s+commit\b"#), "Git – Branch wechseln": ("Git", #"\bgit\s+checkout\b"#),
  "Git – Änderungen übertragen": ("Git", #"\bgit\s+push\b"#), "Git – Änderungen prüfen": ("Git", #"\bgit\s+diff\b"#),
  "Xcode – Build oder Tests ausführen": ("Xcode", #"\bxcodebuild\b"#), "Xcode – Projekt generieren": ("Xcode", #"\bxcodegen\b"#),
  "Xcode – Entwicklerwerkzeug ausführen": ("Xcode", #"\bxcrun\b"#), "Xcode – Simulator steuern": ("Xcode", #"\bsimctl\b"#),
  "Python – Skript ausführen": ("Python", #"\bpython3\b"#), "Python – Pakete verwalten": ("Python", #"\bpip3?\b"#),
  "Python – HTTP-Anfrage": ("Python", #"urllib\.request"#),
  "Shell – Text bearbeiten": ("Shell", #"\bsed\b"#), "Shell – Text durchsuchen": ("Shell", #"\bgrep\b"#),
  "Shell – Dateirechte ändern": ("Shell", #"\bchmod\b"#), "Shell – Rekursiv löschen": ("Shell", #"rm\s+-rf"#)
 ]

 init(fileURL: URL? = nil) {
  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Snippet-Tresor", isDirectory: true)
  self.fileURL = fileURL ?? support.appendingPathComponent("prompts.json")
  encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  if !isDefaultLibrary { syncState = .disabled }
  do { try load() } catch { loadFailed = true; errorMessage = "Die Bibliothek konnte nicht geladen werden. Die Datei wurde nicht überschrieben.\n\n\(error.localizedDescription)" }
 }
 var categories: [String] { Array(Set(snippets.map(\.category).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).sorted() }
 func count(in category: String) -> Int { category == "Alle" ? snippets.count : snippets.filter { $0.category == category }.count }
 func requestNewSnippet() { editorRequest = EditorRequest(snippet: nil) }
 func requestEdit(_ snippet: Snippet) { editorRequest = EditorRequest(snippet: snippet) }
 func openDashboard() { NSWorkspace.shared.open(Self.dashboardURL) }
 func filtered(category: String, query: String) -> [Snippet] {
  let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  return snippets.filter { item in
   (category == "Alle" || item.category == category) && (needle.isEmpty || "\(item.title) \(item.category) \(item.text)".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle))
  }
 }
 func save(title: String, category: String, text: String, editing: Snippet?) {
  let item = Snippet(id: editing?.id ?? UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines), category: category.trimmingCharacters(in: .whitespacesAndNewlines), text: text.trimmingCharacters(in: .whitespacesAndNewlines), extraFields: editing?.extraFields ?? [:])
  guard !item.title.isEmpty, !item.category.isEmpty, !item.text.isEmpty else { errorMessage = SnippetStoreError.invalidEntry.localizedDescription; return }
  var next = snippets
  if let editing {
   guard let index = next.firstIndex(where: { $0.id == editing.id }) else { errorMessage = SnippetStoreError.missingEntry.localizedDescription; return }
   next[index] = item
  } else { next.append(item) }
  commit(next)
 }

 /// Adds findings that are not yet in the library. Returns the snippets that were added.
 @discardableResult
 func importFindings(_ findings: [ProjectAnalyzer.Finding]) -> [Snippet] {
  guard !loadFailed else { errorMessage = "Import nicht möglich, weil die vorhandene JSON-Datei nicht geladen werden konnte."; return [] }
  var seen = Set(snippets.map(\.text))
  var additions: [Snippet] = []
  for finding in findings where seen.insert(finding.text).inserted {
   additions.append(Snippet(title: finding.title, category: finding.category, text: finding.text, extraFields: [Self.scanSourceKey: .string(Self.scanSourceValue)]))
  }
  guard !additions.isEmpty else { return [] }
  commit(snippets + additions)
  return errorMessage == nil ? additions : []
 }

 func scanProject() {
  guard !isScanning else { return }
  let panel = NSOpenPanel()
  panel.title = "Projektordner auswählen"
  panel.message = "Wähle einen Projektordner. Echte Terminal-Befehle werden erkannt und nach Kategorien sortiert übernommen."
  panel.prompt = "Scannen"
  panel.canChooseDirectories = true
  panel.canChooseFiles = false
  panel.allowsMultipleSelection = false
  panel.canCreateDirectories = false
  isScanning = true
  panel.begin { [weak self] response in
   Task { @MainActor in
    guard let self else { return }
    defer { self.isScanning = false }
    guard response == .OK, let directory = panel.url else { return }
    let didAccess = directory.startAccessingSecurityScopedResource()
    defer { if didAccess { directory.stopAccessingSecurityScopedResource() } }
    do {
     let report = try ProjectAnalyzer().scanReport(directory: directory)
     self.errorMessage = nil
     let added = self.importFindings(report.findings)
     guard self.errorMessage == nil else { return }
     self.noticeMessage = Self.scanSummary(folder: directory.lastPathComponent, found: report.findings.count, added: added, unreadable: report.unreadableFiles)
    } catch {
     self.errorMessage = "Der Projektordner konnte nicht vollständig analysiert werden.\n\n\(error.localizedDescription)"
    }
   }
  }
 }

 static func scanSummary(folder: String, found: Int, added: [Snippet], unreadable: [String] = []) -> String {
  var summary: String
  if added.isEmpty {
   summary = found == 0 ? "In „\(folder)“ wurden keine Terminal-Befehle gefunden." : "In „\(folder)“ wurden \(found) Befehle gefunden – alle sind bereits im Tresor."
  } else {
   let perCategory = Dictionary(grouping: added, by: \.category).map { "\($0.key): \($0.value.count)" }.sorted().joined(separator: "\n")
   summary = "\(added.count) neue Snippets aus „\(folder)“ übernommen.\n\n\(perCategory)"
  }
  if !unreadable.isEmpty {
   let shown = unreadable.prefix(5).joined(separator: "\n")
   let more = unreadable.count > 5 ? "\n… und \(unreadable.count - 5) weitere" : ""
   summary += "\n\nAchtung: \(unreadable.count) Datei(en) konnten nicht gelesen werden (keine Berechtigung oder kein UTF-8-Text) und fehlen im Ergebnis:\n\(shown)\(more)"
  }
  return summary
 }

 // MARK: Cleanup of earlier scan imports

 func isScanImport(_ snippet: Snippet) -> Bool {
  if snippet.extraFields[Self.scanSourceKey] == .string(Self.scanSourceValue) { return true }
  guard let rule = Self.legacyScanRules[snippet.title], rule.category == snippet.category,
        !snippet.text.contains("\n"), snippet.text == snippet.text.trimmingCharacters(in: .whitespaces) else { return false }
  return snippet.text.range(of: rule.pattern, options: .regularExpression) != nil
 }

 /// Re-checks every scanned snippet with the current analyzer; manual snippets stay untouched.
 func makeCleanupPlan() -> CleanupPlan {
  var result: [Snippet] = []
  var seen = Set<String>()
  var removals = 0, updates = 0
  for item in snippets {
   guard isScanImport(item) else { result.append(item); seen.insert(item.text); continue }
   guard let finding = ProjectAnalyzer.classify(item.text), seen.insert(item.text).inserted else { removals += 1; continue }
   var updated = item
   updated.title = finding.title
   updated.category = finding.category
   updated.extraFields[Self.scanSourceKey] = .string(Self.scanSourceValue)
   if updated != item { updates += 1 }
   result.append(updated)
  }
  return CleanupPlan(removals: removals, updates: updates, result: result)
 }

 func requestCleanup() {
  let plan = makeCleanupPlan()
  if plan.removals == 0 && plan.updates == 0 { noticeMessage = "Alle importierten Snippets sind bereits sauber." }
  else { pendingCleanup = plan }
 }

 func performCleanup(_ plan: CleanupPlan) {
  pendingCleanup = nil
  guard !loadFailed else { errorMessage = "Bereinigen nicht möglich, weil die vorhandene JSON-Datei nicht geladen werden konnte."; return }
  do {
   let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"
   let backup = fileURL.deletingLastPathComponent().appendingPathComponent("prompts.backup-\(formatter.string(from: Date())).json")
   try encoder.encode(snippets).write(to: backup, options: .atomic)
   errorMessage = nil
   commit(plan.result)
   if errorMessage == nil {
    noticeMessage = "\(plan.removals) Einträge entfernt, \(plan.updates) neu kategorisiert.\n\nBackup: \(backup.lastPathComponent)"
   }
  } catch {
   errorMessage = "Backup konnte nicht angelegt werden – es wurde nichts verändert.\n\n\(error.localizedDescription)"
  }
 }

 func delete(_ snippet: Snippet) {
  guard snippets.contains(where: { $0.id == snippet.id }) else { errorMessage = SnippetStoreError.missingEntry.localizedDescription; return }
  commit(snippets.filter { $0.id != snippet.id }); pendingDelete = nil
 }
 func copy(_ snippet: Snippet) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(snippet.text, forType: .string) }
 private func load() throws {
  guard FileManager.default.fileExists(atPath: fileURL.path) else { snippets = Self.defaults; try persist(snippets); return }
  let data = try Data(contentsOf: fileURL)
  let raw = try JSONSerialization.jsonObject(with: data)
  guard let objects = raw as? [[String: Any]], objects.allSatisfy({ $0["title"] is String && $0["category"] is String && $0["text"] is String }) else { throw SnippetStoreError.invalidData }
  snippets = try decoder.decode([Snippet].self, from: data)
 }
 private func commit(_ next: [Snippet]) {
  guard !loadFailed else { errorMessage = "Speichern ist gesperrt, weil die vorhandene JSON-Datei nicht geladen werden konnte. Sichere oder repariere die Datei zuerst."; return }
  do {
   try persist(next)
   snippets = next
   launchDashboardDeploymentIfConfigured()
  } catch {
   errorMessage = "Speichern fehlgeschlagen. Die bisherigen Daten bleiben erhalten.\n\n\(error.localizedDescription)"
  }
 }
 private var isDefaultLibrary: Bool {
  let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
   .appendingPathComponent("Snippet-Tresor", isDirectory: true)
   .appendingPathComponent("prompts.json")
  return fileURL.standardizedFileURL == supportURL.standardizedFileURL
 }
 private func launchDashboardDeploymentIfConfigured() {
  guard isDefaultLibrary else { return }

  let environment = ProcessInfo.processInfo.environment
  let scriptURL: URL
  if let configuredPath = environment["SNIPPET_TRESOR_DEPLOY_SCRIPT"], !configuredPath.isEmpty {
   scriptURL = URL(fileURLWithPath: configuredPath)
  } else {
   scriptURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Downloads/Eigene Apps/SnippetTresor/scripts/deploy_to_github_pages.sh")
  }
  guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
   syncState = .failed("Deployment-Skript fehlt")
   errorMessage = "Snippet gespeichert, aber Dashboard-Deployment-Skript fehlt oder ist nicht ausführbar: \(scriptURL.path)"
   return
  }

  syncState = .running
  DispatchQueue.global(qos: .utility).async { [weak self] in
   let process = Process()
   let errorPipe = Pipe()
   process.executableURL = URL(fileURLWithPath: "/bin/bash")
   process.arguments = [scriptURL.path]
   process.standardOutput = FileHandle.nullDevice
   process.standardError = errorPipe
   process.terminationHandler = { [weak self] process in
    let status = process.terminationStatus
    let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
     .split(separator: "\n").last.map(String.init) ?? ""
    DispatchQueue.main.async {
     guard let self else { return }
     if status == 0 {
      self.syncState = .success(Date())
     } else {
      self.syncState = .failed(stderr.isEmpty ? "Exit-Code \(status)" : stderr)
      self.errorMessage = "Snippet gespeichert, aber Dashboard-Deployment fehlgeschlagen (Exit-Code \(status)).\(stderr.isEmpty ? "" : "\n\n\(stderr)")"
     }
    }
   }
   do {
    try process.run()
   } catch {
    DispatchQueue.main.async {
     self?.syncState = .failed(error.localizedDescription)
     self?.errorMessage = "Snippet gespeichert, Dashboard-Deployment konnte nicht gestartet werden: \(error.localizedDescription)"
    }
   }
  }
 }
 private func persist(_ values: [Snippet]) throws {
  try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
  try encoder.encode(values).write(to: fileURL, options: .atomic)
 }
 static let defaults: [Snippet] = [
  .init(title:"Xcode – Debug Build",category:"Xcode",text:"xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug build"),
  .init(title:"Xcode – Tests",category:"Xcode",text:"xcodebuild test -project MyApp.xcodeproj -scheme MyApp -destination 'platform=macOS'"),
  .init(title:"Git – Status",category:"Git",text:"git status --short --branch"),
  .init(title:"Git – Diff prüfen",category:"Git",text:"git diff --check && git diff"),
  .init(title:"Prompt – Fehleranalyse",category:"Prompts",text:"Diagnostiziere zuerst den Fehler. Belege Befunde anhand konkreter Dateien und Tests. Ändere nur, was zur Behebung nötig ist."),
  .init(title:"Wetter – Open-Meteo",category:"Wetter",text:"https://open-meteo.com")
 ]
}
