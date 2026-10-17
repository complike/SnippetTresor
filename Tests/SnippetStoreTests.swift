import XCTest
@testable import SnippetTresor

@MainActor final class SnippetStoreTests: XCTestCase {
 private func temporaryURL() throws -> URL {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir.appendingPathComponent("prompts.json")
 }

 func testLegacyExtraFieldsSurviveDecodeEditAndSave() throws {
  let url = try temporaryURL()
  let json = """
  [{"title":"Alt","category":"Tools","text":"echo ok","author":"legacy","metadata":{"rank":3,"enabled":true},"tags":["a","b"]}]
  """
  try Data(json.utf8).write(to: url)
  let store = SnippetStore(fileURL: url)
  XCTAssertEqual(store.snippets.count, 1)
  store.save(title:"Neu", category:"Tools", text:"echo changed", editing:store.snippets[0])
  XCTAssertNil(store.errorMessage)
  let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf:url)) as? [[String:Any]])
  XCTAssertEqual(saved[0]["author"] as? String, "legacy")
  XCTAssertEqual((saved[0]["metadata"] as? [String:Any])?["rank"] as? Double, 3)
  XCTAssertEqual(saved[0]["tags"] as? [String], ["a","b"])
  XCTAssertEqual(saved[0]["title"] as? String, "Neu")
 }

 func testCreateEditDeleteAndValidation() throws {
  let url = try temporaryURL()
  try JSONEncoder().encode([Snippet(title:"A",category:"One",text:"body")]).write(to:url)
  let store = SnippetStore(fileURL:url)
  let original = try XCTUnwrap(store.snippets.first)
  store.save(title:" ",category:"One",text:"body",editing:nil)
  XCTAssertNotNil(store.errorMessage)
  XCTAssertEqual(store.snippets.count,1)
  store.errorMessage=nil
  store.save(title:"B",category:"Two",text:"new body",editing:original)
  XCTAssertEqual(store.snippets.first?.title,"B")
  XCTAssertNil(store.errorMessage)
  store.delete(try XCTUnwrap(store.snippets.first))
  XCTAssertTrue(store.snippets.isEmpty)
  XCTAssertEqual(try JSONDecoder().decode([Snippet].self,from:Data(contentsOf:url)),[])
 }

 func testMalformedJSONIsNotOverwritten() throws {
  let url = try temporaryURL()
  let broken = Data("{ not-json".utf8)
  try broken.write(to:url)
  let store = SnippetStore(fileURL:url)
  XCTAssertNotNil(store.errorMessage)
  store.save(title:"Should not save",category:"A",text:"body",editing:nil)
  XCTAssertEqual(try Data(contentsOf:url),broken)
  XCTAssertTrue(store.snippets.isEmpty)
 }

 func testProjectAnalyzerClassifiesSupportedCommandsAndIgnoresOtherFiles() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  try "git status --short\nxcodebuild build\npython3 tool.py\nrm -rf old\necho hello".write(to: root.appendingPathComponent("WORKFLOW.md"), atomically: true, encoding: .utf8)
  try "git commit -m test".write(to: root.appendingPathComponent("ignored.txt"), atomically: true, encoding: .utf8)
  let findings = try ProjectAnalyzer().scan(directory: root)
  XCTAssertEqual(findings.map(\.category), ["Git", "Xcode", "Python", "Shell"])
  XCTAssertEqual(findings.first?.title, "Git – Status prüfen")
  XCTAssertFalse(findings.contains { $0.text == "echo hello" })
 }

 func testProjectAnalyzerScansEverySupportedFileTypeAndIgnoresUnsupportedFiles() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }

  let fixtures: [(String, String)] = [
   ("run.sh", "chmod +x run.sh"),
   ("tool.py", "python3 tool.py"),
   ("notes.md", "git status --porcelain"),
   ("Makefile", "xcodebuild build"),
   ("makefile", "git add notes.md"),
   ("GNUmakefile", "git diff --stat"),
   ("WORKFLOW.md", "git push origin main")
  ]
  for (index, fixture) in fixtures.enumerated() {
   let fileDirectory = root.appendingPathComponent("fixture-\(index)", isDirectory: true)
   try FileManager.default.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
   try fixture.1.write(to: fileDirectory.appendingPathComponent(fixture.0), atomically: true, encoding: .utf8)
  }
  try "git commit -m ignored".write(to: root.appendingPathComponent("ignored.txt"), atomically: true, encoding: .utf8)

  let analyzer = ProjectAnalyzer()
  let firstScan = try analyzer.scan(directory: root)
  let secondScan = try analyzer.scan(directory: root)
  XCTAssertEqual(firstScan.count, fixtures.count)
  for (_, expectedText) in fixtures {
   XCTAssertTrue(firstScan.contains { $0.text == expectedText }, "Expected to scan supported fixture content: \(expectedText)")
  }
  XCTAssertEqual(Set(secondScan.map(\.text)), Set(firstScan.map(\.text)))
  XCTAssertFalse(firstScan.contains { $0.text == "git commit -m ignored" })

  let storeURL = try temporaryURL()
  try Data("[]".utf8).write(to: storeURL)
  let store = SnippetStore(fileURL: storeURL)
  store.importFindings(firstScan)
  let countAfterFirstImport = store.snippets.count
  store.importFindings(secondScan)
  XCTAssertEqual(countAfterFirstImport, fixtures.count)
  XCTAssertEqual(store.snippets.count, countAfterFirstImport, "A complete repeated scan/import must not create duplicate snippets")
 }

 func testAnalyzerImportIsIdempotentAndPreservesExistingLegacyFields() throws {
  let url = try temporaryURL()
  try Data(#"[{"title":"Existing","category":"Git","text":"git status","legacy":"keep"}]"#.utf8).write(to: url)
  let store = SnippetStore(fileURL: url)
  store.importFindings([
   .init(category: "Git", title: "Git – Status prüfen", text: "git status"),
   .init(category: "Git", title: "Git – Commit erstellen", text: "git commit -m test"),
   .init(category: "Git", title: "Git – Commit erstellen", text: "git commit -m test")
  ])
  XCTAssertEqual(store.snippets.count, 2)
  let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
  XCTAssertEqual(saved[0]["legacy"] as? String, "keep")
  XCTAssertEqual(saved[1]["text"] as? String, "git commit -m test")
 }

 func testFailedInitialWriteIsReportedAndNoCrash() {
  let store = SnippetStore(fileURL: URL(fileURLWithPath:"/dev/null/snippet-tresor/prompts.json"))
  XCTAssertNotNil(store.errorMessage)
  let originalCount = store.snippets.count
  store.save(title:"No",category:"A",text:"body",editing:nil)
  XCTAssertNotNil(store.errorMessage)
  XCTAssertEqual(store.snippets.count, originalCount)
 }
}
