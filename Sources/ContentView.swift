import SwiftUI

enum CategoryStyle {
 static func icon(for category: String) -> String {
  switch category {
  case "Alle": return "tray.full"
  case "Git": return "arrow.triangle.branch"
  case "Xcode": return "hammer"
  case "Python": return "chevron.left.forwardslash.chevron.right"
  case "Node.js": return "shippingbox"
  case "Homebrew": return "mug"
  case "Docker": return "cube.box"
  case "Netzwerk": return "network"
  case "macOS": return "desktopcomputer"
  case "Shell": return "terminal"
  case "Build": return "gearshape.2"
  case "KI": return "sparkles"
  case "Prompts": return "text.bubble"
  case "Wetter": return "cloud.sun"
  default: return "folder"
  }
 }
}

struct ContentView: View {
 @EnvironmentObject private var store: SnippetStore
 @State private var selectedCategory = "Alle"
 @State private var searchText = ""
 @State private var copiedID: UUID?
 private var visible: [Snippet] { store.filtered(category: selectedCategory, query: searchText) }
 var body: some View {
  NavigationSplitView {
   List(selection: $selectedCategory) {
    CategoryRow(name: "Alle", count: store.count(in: "Alle")).tag("Alle")
    Section("Kategorien") {
     ForEach(store.categories, id: \.self) { CategoryRow(name: $0, count: store.count(in: $0)).tag($0) }
    }
   }
   .listStyle(.sidebar)
   .navigationSplitViewColumnWidth(min: 200, ideal: 230)
   .safeAreaInset(edge: .bottom) { DashboardFooter() }
  } detail: {
   VStack(spacing: 0) {
    HStack(alignment: .firstTextBaseline) {
     Label(selectedCategory == "Alle" ? "Alle Snippets" : selectedCategory, systemImage: CategoryStyle.icon(for: selectedCategory))
      .font(.title.bold())
     Spacer()
     Text("\(visible.count) \(visible.count == 1 ? "Eintrag" : "Einträge")").foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 12)
    Divider()
    if visible.isEmpty {
     ContentUnavailableView {
      Label("Keine passenden Einträge", systemImage: "doc.text.magnifyingglass")
     } description: {
      Text("Passe die Suche an, scanne einen Projektordner oder füge ein Snippet hinzu.")
     } actions: {
      Button("Projekt scannen …", action: store.scanProject)
     }
     .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
     ScrollView {
      LazyVStack(spacing: 10) {
       ForEach(visible) { item in
        SnippetCard(snippet: item, showCategory: selectedCategory == "Alle", copied: copiedID == item.id,
                    copy: { store.copy(item); copiedID = item.id },
                    edit: { store.requestEdit(item) },
                    delete: { store.pendingDelete = item })
       }
      }
      .padding(20)
     }
    }
   }
   .background(Color(nsColor: .windowBackgroundColor))
   .navigationTitle("Snippet-Tresor")
   .searchable(text: $searchText, placement: .toolbar, prompt: "Snippets durchsuchen")
   .toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
     Button(action: store.scanProject) { Label("Projekt scannen", systemImage: "doc.text.magnifyingglass") }
      .help("Projektordner auswählen und Befehle automatisch als Snippets übernehmen (⇧⌘O)")
      .disabled(store.isScanning)
     Button(action: store.openDashboard) { Label("Online-Dashboard", systemImage: "globe") }
      .help("Online-Dashboard öffnen: \(SnippetStore.dashboardURL.absoluteString)")
     Button(action: store.requestNewSnippet) { Label("Snippet hinzufügen", systemImage: "plus") }
      .help("Neues Snippet (⌘N)")
    }
   }
   .alert("Snippet-Tresor", isPresented: Binding(get: { store.noticeMessage != nil }, set: { if !$0 { store.noticeMessage = nil } })) {
    Button("OK", role: .cancel) { store.noticeMessage = nil }
   } message: { Text(store.noticeMessage ?? "") }
  }
  .sheet(item: $store.editorRequest) { request in
   SnippetEditor(snippet: request.snippet, categories: store.categories) { title, category, text in
    store.errorMessage = nil
    store.save(title: title, category: category, text: text, editing: request.snippet)
    if store.errorMessage == nil { store.editorRequest = nil }
   }.environmentObject(store)
  }
  .alert("Snippet-Tresor", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
   Button("OK", role: .cancel) { store.errorMessage = nil }
  } message: { Text(store.errorMessage ?? "") }
  .confirmationDialog("Snippet löschen?", isPresented: Binding(get: { store.pendingDelete != nil }, set: { if !$0 { store.pendingDelete = nil } }), titleVisibility: .visible) {
   Button("Löschen", role: .destructive) { if let item = store.pendingDelete { store.delete(item) } }
   Button("Abbrechen", role: .cancel) { store.pendingDelete = nil }
  } message: { Text("„\(store.pendingDelete?.title ?? "")“ wird dauerhaft entfernt.") }
  .confirmationDialog("Importierte Snippets bereinigen?", isPresented: Binding(get: { store.pendingCleanup != nil }, set: { if !$0 { store.pendingCleanup = nil } }), titleVisibility: .visible) {
   Button("Bereinigen", role: .destructive) { if let plan = store.pendingCleanup { store.performCleanup(plan) } }
   Button("Abbrechen", role: .cancel) { store.pendingCleanup = nil }
  } message: {
   Text("\(store.pendingCleanup?.removals ?? 0) gescannte Einträge sind keine echten Befehle und werden entfernt, \(store.pendingCleanup?.updates ?? 0) werden neu kategorisiert. Manuell angelegte Snippets bleiben unverändert. Vorher wird ein Backup angelegt.")
  }
  .onChange(of: store.categories) { _, categories in
   if selectedCategory != "Alle" && !categories.contains(selectedCategory) { selectedCategory = "Alle" }
  }
 }
}

private struct CategoryRow: View {
 let name: String
 let count: Int
 var body: some View {
  Label(name, systemImage: CategoryStyle.icon(for: name)).badge(count)
 }
}

private struct DashboardFooter: View {
 @EnvironmentObject private var store: SnippetStore
 var body: some View {
  VStack(alignment: .leading, spacing: 6) {
   Divider().padding(.bottom, 4)
   Link(destination: SnippetStore.dashboardURL) {
    Label("Online-Dashboard", systemImage: "globe").font(.callout.weight(.semibold))
   }
   .help(SnippetStore.dashboardURL.absoluteString)
   Text("complike.github.io/SnippetTresor").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
   status.font(.caption)
  }
  .padding(.horizontal, 14).padding(.bottom, 12)
  .frame(maxWidth: .infinity, alignment: .leading)
 }
 @ViewBuilder private var status: some View {
  switch store.syncState {
  case .idle:
   Label("Änderungen werden automatisch auf GitHub hochgeladen", systemImage: "icloud").foregroundStyle(.secondary)
  case .running:
   HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Wird auf GitHub hochgeladen …") }.foregroundStyle(.secondary)
  case .success(let date):
   Label("Hochgeladen um \(date.formatted(date: .omitted, time: .shortened)) – online in ca. 1–2 Min.", systemImage: "checkmark.icloud").foregroundStyle(.green)
  case .failed(let reason):
   Label("Upload fehlgeschlagen: \(reason)", systemImage: "exclamationmark.icloud").foregroundStyle(.red).lineLimit(3)
  case .disabled:
   Label("Lokal gespeichert", systemImage: "lock.shield").foregroundStyle(.secondary)
  }
 }
}

private struct SnippetCard: View {
 let snippet: Snippet; let showCategory: Bool; let copied: Bool; let copy: () -> Void; let edit: () -> Void; let delete: () -> Void
 var body: some View {
  VStack(alignment: .leading, spacing: 8) {
   HStack(alignment: .center, spacing: 10) {
    Text(snippet.title).font(.headline).lineLimit(1)
    if showCategory {
     Label(snippet.category, systemImage: CategoryStyle.icon(for: snippet.category))
      .font(.caption.weight(.medium)).foregroundStyle(.secondary)
      .padding(.horizontal, 7).padding(.vertical, 2)
      .background(.quaternary.opacity(0.6), in: Capsule())
    }
    Spacer(minLength: 8)
    Button(action: copy) { Label(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc") }
     .buttonStyle(.bordered).controlSize(.small)
    Menu {
     Button("Bearbeiten", systemImage: "square.and.pencil", action: edit)
     Button("Löschen", systemImage: "trash", role: .destructive, action: delete)
    } label: { Image(systemName: "ellipsis.circle") }
     .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
   }
   Text(snippet.text)
    .font(.system(.callout, design: .monospaced)).lineLimit(6).textSelection(.enabled)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
  }
  .padding(14)
  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
  .contextMenu {
   Button("Kopieren", systemImage: "doc.on.doc", action: copy)
   Button("Bearbeiten", systemImage: "square.and.pencil", action: edit)
   Divider()
   Button("Löschen", systemImage: "trash", role: .destructive, action: delete)
  }
 }
}

private struct SnippetEditor: View {
 @EnvironmentObject private var store: SnippetStore
 @Environment(\.dismiss) private var dismiss
 let snippet: Snippet?; let categories: [String]; let onSave: (String, String, String) -> Void
 @State private var title: String; @State private var category: String; @State private var text: String
 init(snippet: Snippet?, categories: [String], onSave: @escaping (String, String, String) -> Void) {
  self.snippet = snippet; self.categories = categories; self.onSave = onSave
  _title = State(initialValue: snippet?.title ?? ""); _category = State(initialValue: snippet?.category ?? ""); _text = State(initialValue: snippet?.text ?? "")
 }
 var body: some View {
  VStack(alignment: .leading, spacing: 16) {
   HStack {
    Text(snippet == nil ? "Snippet hinzufügen" : "Snippet bearbeiten").font(.title2.bold())
    Spacer()
    Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
    Button("Speichern") { onSave(title, category, text) }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
   }

   Form {
    TextField("Titel", text: $title)
    TextField("Kategorie wählen oder neu eingeben", text: $category)
    if !categories.isEmpty {
     HStack {
      Text("Vorhandene Kategorien").foregroundStyle(.secondary)
      Spacer()
      Menu("Auswählen") { ForEach(categories, id: \.self) { item in Button(item) { category = item } } }
     }
    }
   }

   Divider()

   VStack(alignment: .leading, spacing: 6) {
    Text("Snippet / Befehl").font(.subheadline.bold())
    TextEditor(text: $text)
     .font(.system(.body, design: .monospaced))
     .frame(minHeight: 220)
     .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
   }
  }
  .padding(22)
  .frame(minWidth: 640, minHeight: 480)
 }
}
