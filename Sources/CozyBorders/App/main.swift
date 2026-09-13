import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement in Info.plist hides the Dock icon for the bundled app; this covers `swift run`.
app.setActivationPolicy(.accessory)
app.run()
