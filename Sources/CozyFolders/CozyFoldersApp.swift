import AppKit
import KnitCore
import SwiftUI

@main
struct CozyFoldersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Cozy Folders", id: "main") {
            ContentView()
                .environmentObject(appDelegate.studio)
                .frame(minWidth: 800, minHeight: 700)
        }
        .defaultSize(width: 840, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Folders to Knit…") { appDelegate.studio.chooseFolders() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Cozy Folders") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: "Knitted folder icons."),
                    ])
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let studio = KnitStudio()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When run outside the app bundle (swift run) there's no Info.plist to make us a
        // regular app, so do it here; also give the Dock a knitted icon.
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = FolderIconRenderer.icon(for: FolderSweater(pattern: .fairIsle, palette: YarnPreset.named("finder")!.palette))
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Folders dropped on the Dock icon (or opened with the app) get knitted straight away.
    func application(_ application: NSApplication, open urls: [URL]) {
        studio.knit(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
