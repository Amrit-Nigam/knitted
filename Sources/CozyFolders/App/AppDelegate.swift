import AppKit
import KnitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let studio = Studio()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Outside the app bundle (swift run) there's no Info.plist to make us a regular app.
        NSApp.setActivationPolicy(.regular)
        if let icon = AppIconRenderer.image(pixelSize: 1024) {
            NSApp.applicationIconImage = NSImage(cgImage: icon, size: NSSize(width: 512, height: 512))
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Folders dropped on the Dock icon are staged, ready for a design to be picked.
    func application(_ application: NSApplication, open urls: [URL]) {
        studio.stage(urls)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
