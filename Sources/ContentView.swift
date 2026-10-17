import SwiftUI
struct ContentView: View {
 @EnvironmentObject private var store: SnippetStore
 @State private var selectedCategory = "Alle"
 @State private var searchText = ""
 @State private var copiedID: UUID?
 private var visible: [Snippet] { store.filtered(category: selectedCategory, query: searchText) }
 var body: some View {
  NavigationSplitView {
   List(selection: $selectedCategory) {
    Label("Alle", systemImage:"tray.full").tag("Alle")
    Section("Kategorien") { ForEach(store.categories,id:\.self) { Label($0,systemImage:"folder").tag($0) } }
   }.listStyle(.sidebar).navigationTitle("Snippet-Tresor")
    .safeAreaInset(edge:.bottom) { Label("Lokal gespeichert",systemImage:"lock.shield").font(.caption).foregroundStyle(.secondary).padding().frame(maxWidth:.infinity,alignment:.leading) }
  } detail: {
   VStack(spacing:0) {
    HStack {
     VStack(alignment:.leading,spacing:3) {
      Text(selectedCategory == "Alle" ? "Deine Snippets" : selectedCategory).font(.largeTitle.bold())
      Text("\(visible.count) Einträge").foregroundStyle(.secondary)
     }
     Spacer()
     Button(action:store.requestNewSnippet) { Label("Snippet hinzufügen",systemImage:"plus") }.buttonStyle(.borderedProminent)
    }.padding(.horizontal,24).padding(.top,22).padding(.bottom,16)
    HStack { Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
     TextField("Snippets durchsuchen",text:$searchText).textFieldStyle(.plain)
     if !searchText.isEmpty { Button { searchText="" } label:{ Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
    }.padding(10).background(.quaternary.opacity(0.65),in:RoundedRectangle(cornerRadius:10)).padding(.horizontal,24).padding(.bottom,16)
    if visible.isEmpty {
     ContentUnavailableView("Keine passenden Einträge",systemImage:"doc.text.magnifyingglass",description:Text("Passe die Suche an oder füge ein Snippet hinzu.")).frame(maxWidth:.infinity,maxHeight:.infinity)
    } else {
     ScrollView { LazyVStack(spacing:12) {
      ForEach(visible) { item in
       SnippetCard(snippet:item,copied:copiedID == item.id,copy:{store.copy(item);copiedID=item.id},edit:{store.requestEdit(item)},delete:{store.pendingDelete=item})
      }
     }.padding(.horizontal,24).padding(.bottom,24) }
    }
   }.background(Color(nsColor:.windowBackgroundColor)).navigationTitle("")
  }
  .sheet(item:$store.editorRequest) { request in
   SnippetEditor(snippet:request.snippet,categories:store.categories) { title,category,text in
    store.errorMessage = nil
    store.save(title:title,category:category,text:text,editing:request.snippet)
    if store.errorMessage == nil { store.editorRequest=nil }
   }.environmentObject(store)
  }
  .alert("Snippet-Tresor",isPresented:Binding(get:{store.errorMessage != nil},set:{if !$0 {store.errorMessage=nil}})) {
   Button("OK",role:.cancel){store.errorMessage=nil}
  } message:{Text(store.errorMessage ?? "")}
  .confirmationDialog("Snippet löschen?",isPresented:Binding(get:{store.pendingDelete != nil},set:{if !$0 {store.pendingDelete=nil}}),titleVisibility:.visible) {
   Button("Löschen",role:.destructive){if let item=store.pendingDelete {store.delete(item)}}
   Button("Abbrechen",role:.cancel){store.pendingDelete=nil}
  } message:{Text("„\(store.pendingDelete?.title ?? "")“ wird dauerhaft entfernt.")}
 }
}
private struct SnippetCard: View {
 let snippet:Snippet; let copied:Bool; let copy:()->Void; let edit:()->Void; let delete:()->Void
 var body:some View {
  VStack(alignment:.leading,spacing:12) {
   HStack(alignment:.firstTextBaseline,spacing:12) {
    Text(snippet.title).font(.headline).lineLimit(2); Spacer(minLength:8)
    Button(action:copy){Label(copied ? "Kopiert":"Kopieren",systemImage:copied ? "checkmark":"doc.on.doc")}.buttonStyle(.bordered)
    Button(action:edit){Image(systemName:"square.and.pencil")}.help("Bearbeiten").buttonStyle(.bordered)
    Menu { Button("Bearbeiten",systemImage:"square.and.pencil",action:edit); Button("Löschen",systemImage:"trash",role:.destructive,action:delete) } label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton)
   }
   Text(snippet.category.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
   Text(snippet.text).font(.system(.body,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(12).background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:8))
  }.padding(16).background(.regularMaterial,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).strokeBorder(Color.primary.opacity(0.08)))
 }
}
private struct SnippetEditor: View {
 @EnvironmentObject private var store:SnippetStore
 @Environment(\.dismiss) private var dismiss
 let snippet:Snippet?; let categories:[String]; let onSave:(String,String,String)->Void
 @State private var title:String; @State private var category:String; @State private var text:String
 init(snippet:Snippet?,categories:[String],onSave:@escaping(String,String,String)->Void) {
  self.snippet=snippet;self.categories=categories;self.onSave=onSave
  _title=State(initialValue:snippet?.title ?? "");_category=State(initialValue:snippet?.category ?? "");_text=State(initialValue:snippet?.text ?? "")
 }
 var body:some View {
  VStack(alignment:.leading,spacing:16) {
   HStack { Text(snippet == nil ? "Snippet hinzufügen":"Snippet bearbeiten").font(.title2.bold());Spacer();Button("Abbrechen"){dismiss()}.keyboardShortcut(.cancelAction);Button("Speichern"){onSave(title,category,text)}.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent) }
   Form {
    TextField("Titel",text:$title)
    TextField("Kategorie wählen oder neu eingeben",text:$category)
    if !categories.isEmpty { HStack {Text("Vorhandene Kategorien").foregroundStyle(.secondary);Spacer();Menu("Auswählen"){ForEach(categories,id:\.self){item in Button(item){category=item}}} } }
    VStack(alignment:.leading,spacing:6){Text("Snippet / Befehl");TextEditor(text:$text).font(.system(.body,design:.monospaced)).frame(minHeight:180).overlay(RoundedRectangle(cornerRadius:6).stroke(Color.secondary.opacity(0.25)))}
   }
  }.padding(22).frame(minWidth:520,minHeight:420)
 }
}