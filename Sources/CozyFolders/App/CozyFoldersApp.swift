import SwiftUI

@main
struct CozyFoldersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Cozy Folders", id: "main") {
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
                Button("Knit Sweaters") { appDelegate.studio.apply() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(appDelegate.studio.staged.isEmpty)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Cozy Folders") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: "Knitted sweaters for your folders."),
                    ])
                }
            }
        }
    }
}
