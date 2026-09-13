import AppKit

/// App launch / terminate / activate, space changes and display reconfiguration.
final class WorkspaceObserver {
    var onLaunch: ((NSRunningApplication) -> Void)?
    var onTerminate: ((NSRunningApplication) -> Void)?
    var onActivate: ((NSRunningApplication) -> Void)?
    var onSpaceChange: (() -> Void)?
    var onScreensChange: (() -> Void)?

    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        func app(_ note: Notification) -> NSRunningApplication? {
            note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        }
        add(workspace, NSWorkspace.didLaunchApplicationNotification) { [weak self] in
            if let a = app($0) { self?.onLaunch?(a) }
        }
        add(workspace, NSWorkspace.didTerminateApplicationNotification) { [weak self] in
            if let a = app($0) { self?.onTerminate?(a) }
        }
        add(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in
            if let a = app($0) { self?.onActivate?(a) }
        }
        add(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] _ in
            self?.onSpaceChange?()
        }
        add(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { [weak self] _ in
            self?.onScreensChange?()
        }
    }

    func stop() {
        for (center, token) in tokens { center.removeObserver(token) }
        tokens.removeAll()
    }

    private func add(_ center: NotificationCenter, _ name: Notification.Name, _ block: @escaping (Notification) -> Void) {
        tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main, using: block)))
    }
}
