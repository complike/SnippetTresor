import XCTest
@testable import SnippetTresor

@MainActor final class SnippetStoreTests: XCTestCase {
 private func temporaryURL() throws -> URL {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir.appendingPathComponent("prompts.json")
 }
 private func temporaryProject(_ files: [String: String]) throws -> URL {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  for (path, content) in files {
   let url = root.appendingPathComponent(path)
   try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
   try content.write(to: url, atomically: true, encoding: .utf8)
  }
  addTeardownBlock { try? FileManager.default.removeItem(at: root) }
  return root
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

 // MARK: Analyzer – line classification

 func testClassifyAcceptsRealCommandsWithCategoryAndTitle() throws {
  let cases: [(String, String, String)] = [
   ("git push origin main", "Git", "Git – Änderungen hochladen"),
   ("sudo xcodebuild -scheme App test", "Xcode", "Xcode – Tests ausführen"),
   ("brew install wget", "Homebrew", "Homebrew – Paket installieren"),
   ("python3 -m venv .venv", "Python", "Python – Virtuelle Umgebung anlegen"),
   ("pip install -r requirements.txt", "Python", "pip – Paket installieren"),
   ("npm ci", "Node.js", "npm – Saubere Installation"),
   ("lsof -i -P -n | grep ESTABLISHED", "Netzwerk", "lsof – Offene Ports und Dateien anzeigen"),
   ("defaults write com.apple.finder AppleShowAllFiles -bool true", "macOS", "defaults – Einstellung setzen"),
   ("chmod +x run.sh", "Shell", "chmod – Dateirechte ändern"),
   ("$ docker compose up -d", "Docker", "Docker – Compose ausführen"),
   ("ollama pull llama3", "KI", "Ollama – Modell laden"),
   ("FOO=1 make build", "Build", "make – Make-Ziel ausführen"),
   ("rm -rf ~/Library/Caches/MyApp", "Shell", "rm – Löschen"),
   ("ls $HOME/Library", "Shell", "ls – Dateien auflisten")
  ]
  for (line, category, title) in cases {
   let finding = try XCTUnwrap(ProjectAnalyzer.classify(line), line)
   XCTAssertEqual(finding.category, category, line)
   XCTAssertEqual(finding.title, title, line)
  }
  XCTAssertEqual(ProjectAnalyzer.classify("$ docker compose up -d")?.text, "docker compose up -d")
 }

 func testClassifyRejectsCodeProseAndScriptInternals() {
  let junk = [
   "from pip import __file__ as pip_location",
   "# portable across different pip versions.",
   "class _CookieCompatRequest(urllib.request.Request):",
   "os.chmod(outfile, (zinfo.external_attr >> 16) & 0x1FF)",
   "log.debug(\"chmod failed: %s\", e)",
   "if [[ -f \"$HISTORY_FILE\" ]] && command -v python3 &>/dev/null; then",
   "git diff --check: keine gemeldeten Fehler.",
   "F-4 [MITTEL]: FIXED – git status zeigt ein sauberes Arbeitsverzeichnis (main).",
   "sudo ./ghostapfs_recovery $DEV 0 / 2>&1 | sed -n -e '/x/p' >> $OUT",
   "version=$(\"$cmd\" --version 2>&1 | grep -oE '[0-9]+')",
   "python3 -m py_compile snippet_tresor.py tests/test_storage.py – erfolgreich.",
   "echo hello",
   "cd build",
   "./scripts/build.sh",
   "git checkout \"$1\"",
   "grep foo |",
   "python3 -c '",
   "python3 = get_bool_opt(options, 'python3', True)",
   "python -m pip ...",
   "pip also supports installing from \"requirements files\"",
   "help=\"Run pip with the specified Python interpreter.\",",
   "ACTUAL=$(git diff --unified=0 -- TODO.md)",
   "pip install openai[{extra}]",
   "rm -rf",
   ""
  ]
  for line in junk { XCTAssertNil(ProjectAnalyzer.classify(line), line) }
 }

 // MARK: Analyzer – folder scan

 func testScanExtractsCommandsFromScriptsMarkdownMakefilesAndPackageJSON() throws {
  let root = try temporaryProject([
   "run.sh": "#!/bin/bash\nset -e\n# Kommentar\necho start\nbrew install jq\nxcodebuild -scheme App \\\n  -configuration Release build\nif [ -f x ]; then\n  git status --short\nfi\ncp \"$1\" out\n",
   "README.md": "Prosa mit git diff --check im Text.\n\n```bash\ngit clone https://github.com/a/b.git\nnpm install\n```\n\n```swift\nlet x = \"git push\"\n```\n\n```console\n$ docker ps\nCONTAINER ID   IMAGE\n```\n",
   "Makefile": "build:\n\t@xcodegen generate\n\tswift build -c release\nVAR = git status\n",
   "package.json": #"{"name":"demo","scripts":{"test":"jest","build":"tsc"}}"#,
   "tool.py": "import os\nos.system('git push')\n",
   "notes.txt": "git commit -m ignored",
   "node_modules/dep/install.sh": "npm publish",
   "build/out.sh": "git push --force"
  ])
  let texts = Set(try ProjectAnalyzer().scan(directory: root).map(\.text))
  XCTAssertEqual(texts, [
   "brew install jq",
   "xcodebuild -scheme App -configuration Release build",
   "git status --short",
   "git clone https://github.com/a/b.git",
   "npm install",
   "docker ps",
   "xcodegen generate",
   "swift build -c release",
   "npm run build",
   "npm run test"
  ])
 }

 func testRepeatedScanAndImportCreateNoDuplicatesAndMarkSource() throws {
  let root = try temporaryProject(["a/run.sh": "git status\nbrew update", "b/run.sh": "git status"])
  let analyzer = ProjectAnalyzer()
  let first = try analyzer.scan(directory: root)
  XCTAssertEqual(first.count, 2)
  let url = try temporaryURL()
  try Data("[]".utf8).write(to: url)
  let store = SnippetStore(fileURL: url)
  XCTAssertEqual(store.importFindings(first).count, 2)
  XCTAssertEqual(store.importFindings(try analyzer.scan(directory: root)).count, 0)
  XCTAssertEqual(store.snippets.count, 2)
  XCTAssertTrue(store.snippets.allSatisfy(store.isScanImport))
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

 // MARK: Cleanup

 func testCleanupRemovesLegacyJunkRecategorizesRealCommandsAndKeepsManualSnippets() throws {
  let url = try temporaryURL()
  let json = """
  [
   {"title":"Python – Pakete verwalten","category":"Python","text":"from pip._internal.utils import misc"},
   {"title":"Python – Pakete verwalten","category":"Python","text":"pip install requests"},
   {"title":"Shell – Text durchsuchen","category":"Shell","text":"lsof -i -P -n | grep LISTEN"},
   {"title":"Git – Änderungen prüfen","category":"Git","text":"git diff --check: keine Fehler."},
   {"title":"Offline Scan über Defender","category":"Windows 11","text":"some manual text"},
   {"title":"Git – Status","category":"Git","text":"git status --short --branch"}
  ]
  """
  try Data(json.utf8).write(to: url)
  let store = SnippetStore(fileURL: url)
  let plan = store.makeCleanupPlan()
  XCTAssertEqual(plan.removals, 2)
  XCTAssertEqual(plan.updates, 2)
  store.performCleanup(plan)
  XCTAssertNil(store.errorMessage)
  XCTAssertEqual(store.snippets.map(\.text), ["pip install requests", "lsof -i -P -n | grep LISTEN", "some manual text", "git status --short --branch"])
  XCTAssertEqual(store.snippets[1].category, "Netzwerk")
  XCTAssertEqual(store.snippets[3].title, "Git – Status")
  let backups = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path).filter { $0.hasPrefix("prompts.backup-") }
  XCTAssertEqual(backups.count, 1)
  let backup = try JSONDecoder().decode([Snippet].self, from: Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent(backups[0])))
  XCTAssertEqual(backup.count, 6)
  XCTAssertEqual(store.makeCleanupPlan().removals, 0)
  XCTAssertEqual(store.makeCleanupPlan().updates, 0)
 }

 func testNestedPackageScriptsKeepTheirDirectoryAndNamesAreQuoted() throws {
  let root = try temporaryProject([
   "package.json": #"{"scripts":{"build":"tsc"}}"#,
   "frontend/package.json": #"{"scripts":{"build":"vite build","build; touch /tmp/pwned":"x"}}"#,
   "my app/package.json": #"{"scripts":{"start":"node ."}}"#
  ])
  let texts = Set(try ProjectAnalyzer().scan(directory: root).map(\.text))
  XCTAssertEqual(texts, [
   "npm run build",
   "npm --prefix frontend run build",
   "npm --prefix frontend run 'build; touch /tmp/pwned'",
   "npm --prefix 'my app' run start"
  ])
  XCTAssertEqual(ProjectAnalyzer.shellQuoted("it's"), #"'it'\''s'"#)
  XCTAssertEqual(ProjectAnalyzer.shellQuoted(""), "''")
 }

 func testUnreadableCandidateFilesAreReported() throws {
  let root = try temporaryProject(["ok.sh": "git status", "locked/deploy.sh": "git push", "binary.sh": "x", "notes.txt": "ignored"])
  try Data([0xFF, 0xFE, 0x00, 0xC3]).write(to: root.appendingPathComponent("binary.sh"))
  let locked = root.appendingPathComponent("locked/deploy.sh")
  try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
  addTeardownBlock { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
  let report = try ProjectAnalyzer().scanReport(directory: root)
  XCTAssertEqual(report.findings.map(\.text), ["git status"])
  XCTAssertEqual(Set(report.unreadableFiles), ["binary.sh", "locked/deploy.sh"])
  let summary = SnippetStore.scanSummary(folder: "demo", found: 1, added: [], unreadable: report.unreadableFiles)
  XCTAssertTrue(summary.contains("2 Datei(en) konnten nicht gelesen werden"))
 }

 func testCleanupKeepsManualSnippetsThatOnlyShareALegacyTitle() throws {
  let url = try temporaryURL()
  let json = """
  [
   {"title":"Git – Status prüfen","category":"Git","text":"Notiz: vor dem Status-Check das Repo sichern"},
   {"title":"Git – Status prüfen","category":"Notizen","text":"git status ist kaputt, siehe Ticket"},
   {"title":"Git – Status prüfen","category":"Git","text":"git status zeigt main; der Ordner ist noch unversioniert."}
  ]
  """
  try Data(json.utf8).write(to: url)
  let store = SnippetStore(fileURL: url)
  XCTAssertFalse(store.isScanImport(store.snippets[0]))
  XCTAssertFalse(store.isScanImport(store.snippets[1]))
  XCTAssertTrue(store.isScanImport(store.snippets[2]))
  let plan = store.makeCleanupPlan()
  XCTAssertEqual(plan.removals, 1)
  XCTAssertEqual(plan.result.map(\.text), ["Notiz: vor dem Status-Check das Repo sichern", "git status ist kaputt, siehe Ticket"])
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
