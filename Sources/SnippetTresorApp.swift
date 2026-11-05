import SwiftUI
@main struct SnippetTresorApp: App {
 @StateObject private var store = SnippetStore()
 var body: some Scene {
  WindowGroup { ContentView().environmentObject(store).frame(minWidth: 820, minHeight: 520) }
   .windowStyle(.titleBar)
   .commands {
    CommandGroup(replacing: .newItem) {
     Button("Neues Snippet") { store.requestNewSnippet() }.keyboardShortcut("n", modifiers: .command)
     Button("Projekt scannen …") { store.scanProject() }.keyboardShortcut("o", modifiers: [.command, .shift])
     Divider()
     Button("Importierte Snippets bereinigen …") { store.requestCleanup() }
    }
    CommandGroup(replacing: .help) {
     Button("Online-Dashboard öffnen") { store.openDashboard() }
    }
   }
 }
}
