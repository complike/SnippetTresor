import SwiftUI
@main struct SnippetTresorApp: App {
 @StateObject private var store = SnippetStore()
 var body: some Scene {
  WindowGroup { ContentView().environmentObject(store).frame(minWidth: 760, minHeight: 500) }
   .windowStyle(.titleBar)
   .commands { CommandGroup(replacing: .newItem) { Button("Neues Snippet") { store.requestNewSnippet() }.keyboardShortcut("n", modifiers: .command) } }
 }
}