import SwiftUI

@main
struct KnittedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Knitted", id: "main") {
            RootView()
                .environment(appDelegate.studio)
                .frame(minWidth: 940, minHeight: 700)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1020, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Folders…") { appDelegate.studio.chooseFolders() }
                    .keyboardShortcut("o")
                Button("Knit Sweaters") { Task { await appDelegate.studio.apply() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(appDelegate.studio.staged.isEmpty || appDelegate.studio.isKnitting)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Knitted") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: "Knitted sweaters for your folders."),
                    ])
                }
            }
        }
    }
}
