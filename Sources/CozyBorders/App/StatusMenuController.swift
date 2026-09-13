import AppKit

/// The menu bar item: on/off, stacking style, exclude the current app, preferences, quit.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private unowned let app: AppDelegate
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    /// The app that was frontmost when the menu opened (the status menu doesn't activate us).
    private var appUnderMenu: NSRunningApplication?

    init(app: AppDelegate) {
        self.app = app
        super.init()
        item.button?.image = YarnBallIcon.image(size: 18, template: true)
        item.button?.toolTip = "Cozy Borders"
        menu.delegate = self
        item.menu = menu
        refresh()
    }

    func refresh() {
        menu.removeAllItems()
        let prefs = app.store.preferences

        if !app.isAccessibilityTrusted {
            menu.addItem(withTitle: "Accessibility Access Needed…", action: #selector(showOnboarding), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }

        let toggle = menu.addItem(withTitle: "Knit Borders", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = prefs.enabled ? .on : .off

        menu.addItem(.separator())
        let header = menu.addItem(withTitle: "Stacking", action: nil, keyEquivalent: "")
        header.isEnabled = false
        for mode in OrderingMode.allCases {
            let entry = menu.addItem(withTitle: mode.displayName, action: #selector(chooseMode(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = mode.rawValue
            entry.state = prefs.ordering == mode ? .on : .off
            entry.indentationLevel = 1
        }
        if prefs.ordering == .skyLight, app.coordinator.activeMode != .skyLight {
            let note = menu.addItem(withTitle: "Exact stacking unavailable — using All Windows", action: nil, keyEquivalent: "")
            note.isEnabled = false
            note.indentationLevel = 1
        }

        menu.addItem(.separator())
        let exclude = menu.addItem(withTitle: "Exclude Current App", action: #selector(toggleExcludeCurrentApp), keyEquivalent: "")
        exclude.target = self
        exclude.tag = 1

        menu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",").target = self

        let log = menu.addItem(withTitle: "Log Windows to Console", action: #selector(toggleLogging), keyEquivalent: "")
        log.target = self
        log.state = app.tracker.logsChanges ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cozy Borders", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    // MARK: NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        appUnderMenu = NSWorkspace.shared.frontmostApplication
        guard let exclude = menu.item(withTag: 1) else { return }
        if let target = appUnderMenu, let bundleID = target.bundleIdentifier, target.processIdentifier != getpid() {
            let name = target.localizedName ?? bundleID
            let excluded = app.store.preferences.excludedBundleIDs.contains(bundleID)
            exclude.title = excluded ? "Knit Borders for \(name)" : "Don't Knit Borders for \(name)"
        } else {
            exclude.title = "Exclude Current App"
            exclude.action = nil  // auto-enabling greys out items without an action
        }
    }

    // MARK: Actions

    @objc private func toggleEnabled() {
        app.store.update { $0.enabled.toggle() }
    }

    @objc private func chooseMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = OrderingMode(rawValue: raw) else { return }
        app.store.update { $0.ordering = mode }
    }

    @objc private func toggleExcludeCurrentApp() {
        guard let bundleID = appUnderMenu?.bundleIdentifier else { return }
        app.store.update { prefs in
            if let index = prefs.excludedBundleIDs.firstIndex(of: bundleID) {
                prefs.excludedBundleIDs.remove(at: index)
            } else {
                prefs.excludedBundleIDs.append(bundleID)
            }
        }
    }

    @objc private func toggleLogging() {
        app.tracker.logsChanges.toggle()
        if app.tracker.logsChanges { app.tracker.refreshNow() }
        refresh()
    }

    @objc private func showPreferences() { app.showPreferences() }
    @objc private func showOnboarding() { app.showOnboarding() }
}
