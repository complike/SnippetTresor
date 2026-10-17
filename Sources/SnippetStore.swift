import Foundation
import AppKit
import Combine

@MainActor final class SnippetStore: ObservableObject {
 @Published private(set) var snippets: [Snippet] = []
 @Published var errorMessage: String?
 @Published var editorRequest: EditorRequest?
 @Published var pendingDelete: Snippet?
 struct EditorRequest: Identifiable { let id = UUID(); let snippet: Snippet? }
 private let fileURL: URL
 private let encoder: JSONEncoder
 private let decoder = JSONDecoder()
 private var loadFailed = false

 init(fileURL: URL? = nil) {
  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Snippet-Tresor", isDirectory: true)
  self.fileURL = fileURL ?? support.appendingPathComponent("prompts.json")
  encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  do { try load() } catch { loadFailed = true; errorMessage = "Die Bibliothek konnte nicht geladen werden. Die Datei wurde nicht überschrieben.\n\n\(error.localizedDescription)" }
 }
 var categories: [String] { Array(Set(snippets.map(\.category).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).sorted() }
 func requestNewSnippet() { editorRequest = EditorRequest(snippet: nil) }
 func requestEdit(_ snippet: Snippet) { editorRequest = EditorRequest(snippet: snippet) }
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
  do { try persist(next); snippets = next }
  catch { errorMessage = "Speichern fehlgeschlagen. Die bisherigen Daten bleiben erhalten.\n\n\(error.localizedDescription)" }
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