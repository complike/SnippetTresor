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

 func testFailedInitialWriteIsReportedAndNoCrash() {
  let store = SnippetStore(fileURL: URL(fileURLWithPath:"/dev/null/snippet-tresor/prompts.json"))
  XCTAssertNotNil(store.errorMessage)
  let originalCount = store.snippets.count
  store.save(title:"No",category:"A",text:"body",editing:nil)
  XCTAssertNotNil(store.errorMessage)
  XCTAssertEqual(store.snippets.count, originalCount)
 }
}
