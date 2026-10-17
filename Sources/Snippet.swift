import Foundation

enum JSONValue: Codable, Equatable {
 case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
 init(from decoder: Decoder) throws {
  let c = try decoder.singleValueContainer()
  if c.decodeNil() { self = .null }
  else if let v = try? c.decode(Bool.self) { self = .bool(v) }
  else if let v = try? c.decode(Double.self) { self = .number(v) }
  else if let v = try? c.decode(String.self) { self = .string(v) }
  else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
  else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
  else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Nicht unterstützter JSON-Wert") }
 }
 func encode(to encoder: Encoder) throws {
  var c = encoder.singleValueContainer()
  switch self {
  case .string(let v): try c.encode(v)
  case .number(let v): try c.encode(v)
  case .bool(let v): try c.encode(v)
  case .object(let v): try c.encode(v)
  case .array(let v): try c.encode(v)
  case .null: try c.encodeNil()
  }
 }
}
private struct AnyCodingKey: CodingKey, Hashable {
 let stringValue: String
 let intValue: Int? = nil
 init(_ value: String) { stringValue = value }
 init?(stringValue: String) { self.init(stringValue) }
 init?(intValue: Int) { return nil }
}
struct Snippet: Codable, Identifiable, Equatable {
 var id: UUID
 var title: String
 var category: String
 var text: String
 var extraFields: [String: JSONValue]
 init(id: UUID = UUID(), title: String, category: String, text: String, extraFields: [String: JSONValue] = [:]) {
  self.id=id; self.title=title; self.category=category; self.text=text
  self.extraFields = extraFields.filter { !["id", "title", "category", "text"].contains($0.key) }
 }
 init(from decoder: Decoder) throws {
  let c = try decoder.container(keyedBy: AnyCodingKey.self)
  id = try c.decodeIfPresent(UUID.self, forKey: AnyCodingKey("id")) ?? UUID()
  title = try c.decode(String.self, forKey: AnyCodingKey("title"))
  category = try c.decode(String.self, forKey: AnyCodingKey("category"))
  text = try c.decode(String.self, forKey: AnyCodingKey("text"))
  var extras: [String: JSONValue] = [:]
  for key in c.allKeys where !["id", "title", "category", "text"].contains(key.stringValue) {
   extras[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
  }
  extraFields = extras
 }
 func encode(to encoder: Encoder) throws {
  var c = encoder.container(keyedBy: AnyCodingKey.self)
  for (key, value) in extraFields where !["id", "title", "category", "text"].contains(key) {
   try c.encode(value, forKey: AnyCodingKey(key))
  }
  try c.encode(id, forKey: AnyCodingKey("id"))
  try c.encode(title, forKey: AnyCodingKey("title"))
  try c.encode(category, forKey: AnyCodingKey("category"))
  try c.encode(text, forKey: AnyCodingKey("text"))
 }
}
enum SnippetStoreError: LocalizedError {
 case invalidEntry, missingEntry, invalidData
 var errorDescription: String? {
  switch self {
  case .invalidEntry: return "Bitte Titel, Kategorie und Snippet ausfüllen."
  case .missingEntry: return "Der Eintrag wurde nicht gefunden."
  case .invalidData: return "Die JSON-Datei hat ein ungültiges Format."
  }
 }
}
