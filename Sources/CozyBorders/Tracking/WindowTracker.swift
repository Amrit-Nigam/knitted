import AppKit
import KnitCore

protocol WindowTrackerDelegate: AnyObject {
    /// `windows` is front-to-back. `stackingChanged` is true when z-order or focus may have
    /// moved, i.e. when borders need re-stacking rather than just re-positioning.
    func windowTracker(_ tracker: WindowTracker, didUpdate windows: [TrackedWindow], focusedWindowID: CGWindowID?, stackingChanged: Bool)
    func windowTracker(_ tracker: WindowTracker, appDidTerminate bundleID: String?)
}

/// Keeps a live, de-duplicated list of on-screen windows.
///
/// `CGWindowListCopyWindowInfo` is the authoritative list (discovery, frames, z-order) and
/// needs no permission. Accessibility notifications, workspace notifications and global
/// mouse events tell us *when* to look again — nothing polls.
final class WindowTracker {
    weak var delegate: WindowTrackerDelegate?

    var excludedBundleIDs: Set<String> = [] {
        didSet { if excludedBundleIDs != oldValue { setNeedsRefresh(restack: true) } }
    }

    /// Print window list changes to stdout (M2 acceptance). Toggle from the status menu or
    /// launch with COZY_LOG_WINDOWS=1.
    var logsChanges = ProcessInfo.processInfo.environment["COZY_LOG_WINDOWS"] == "1"

    private(set) var windows: [TrackedWindow] = []
    private(set) var focusedWindowID: CGWindowID?

    private let workspace = WorkspaceObserver()
    private let matcher = WindowMatcher()
    private var appObservers: [pid_t: AppObserver] = [:]
    private var bundleIDs: [pid_t: String] = [:]
    private var focusedByPID: [pid_t: CGWindowID] = [:]
    private var displayBounds = WindowFilter.activeDisplayBounds()
    private var mouseMonitors: [Any] = []
    private var refreshScheduled = false
    private var restackPending = false
    private var running = false

    /// Move/resize events are coalesced over this window. Longer, and borders visibly lag.
    private let coalescing = DispatchTimeInterval.milliseconds(8)

    func start() {
        guard !running else { return }
        running = true

        workspace.onLaunch = { [weak self] app in
            self?.observe(app)
            self?.setNeedsRefresh(restack: true)
        }
        workspace.onTerminate = { [weak self] app in
            guard let self else { return }
            let pid = app.processIdentifier
            appObservers.removeValue(forKey: pid)?.invalidate()
            matcher.forget(pid: pid)
            focusedByPID[pid] = nil
            bundleIDs[pid] = nil
            delegate?.windowTracker(self, appDidTerminate: app.bundleIdentifier)
            setNeedsRefresh(restack: true)
        }
        workspace.onActivate = { [weak self] app in
            self?.updateFocus(pid: app.processIdentifier)
            self?.setNeedsRefresh(restack: true)
        }
        workspace.onSpaceChange = { [weak self] in
            self?.refreshNow(restack: true)
        }
        workspace.onScreensChange = { [weak self] in
            self?.displayBounds = WindowFilter.activeDisplayBounds()
            self?.setNeedsRefresh(restack: true)
        }
        workspace.start()

        for app in NSWorkspace.shared.runningApplications {
            observe(app)
        }

        // Window drags: AX move notifications are sparse for some apps mid-drag, so follow the
        // mouse too. Mouse-up/down catch windows raised by a click without a focus change.
        mouseMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.setNeedsRefresh()
        } as Any)
        mouseMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] _ in
            self?.setNeedsRefresh(restack: true)
        } as Any)

        refreshNow(restack: true)
    }

    func stop() {
        guard running else { return }
        running = false
        workspace.stop()
        for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
        mouseMonitors.removeAll()
        for observer in appObservers.values { observer.invalidate() }
        appObservers.removeAll()
        windows = []
        focusedWindowID = nil
    }

    func setNeedsRefresh(restack: Bool = false) {
        if restack { restackPending = true }
        guard running, !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + coalescing) { [weak self] in
            guard let self else { return }
            refreshScheduled = false
            refreshNow()
        }
    }

    // MARK: Enumeration

    func refreshNow(restack: Bool = false) {
        guard running else { return }
        if restack { restackPending = true }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }

        let filter = WindowFilter(ownPID: getpid(), excludedBundleIDs: excludedBundleIDs, displayBounds: displayBounds)
        var seen = Set<CGWindowID>()
        var current: [TrackedWindow] = []
        for entry in info {
            guard let description = WindowDescription(info: entry), !seen.contains(description.id) else { continue }
            let bundleID = bundleID(for: description.pid)
            guard filter.accepts(description, bundleID: bundleID) else { continue }
            seen.insert(description.id)
            current.append(TrackedWindow(id: description.id, frame: description.frame, pid: description.pid,
                                         bundleID: bundleID, level: description.layer))
        }

        let focused = resolveFocusedWindow(in: current)
        let orderChanged = current.map(\.id) != windows.map(\.id) || focused != focusedWindowID
        let changed = orderChanged || current != windows
        let previous = windows
        windows = current
        focusedWindowID = focused

        if logsChanges, changed { log(previous: previous) }
        if changed || restackPending {
            let stackingChanged = orderChanged || restackPending
            restackPending = false
            delegate?.windowTracker(self, didUpdate: current, focusedWindowID: focused, stackingChanged: stackingChanged)
        }
    }

    private func bundleID(for pid: pid_t) -> String? {
        if let cached = bundleIDs[pid] { return cached }
        let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        if let id { bundleIDs[pid] = id }
        return id
    }

    // MARK: Focus

    /// The frontmost app's focused window. Prefer the Accessibility answer (resolved on focus
    /// changes); if it's stale or unavailable, the frontmost app's first window in CG order is
    /// by definition its topmost.
    private func resolveFocusedWindow(in windows: [TrackedWindow]) -> CGWindowID? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return windows.first?.id }
        if let id = focusedByPID[pid], windows.contains(where: { $0.id == id }) {
            return id
        }
        return windows.first(where: { $0.pid == pid })?.id
    }

    private func updateFocus(pid: pid_t) {
        guard let observer = appObservers[pid] ?? makeObserver(pid: pid),
              let element = AX.focusedWindow(ofApplication: observer.application)
        else { return }
        // Cross-check against a fresh CG list: apps (Electron especially) can report stale
        // AX frames, and the matcher only trusts a frame match when it's unambiguous.
        let fresh = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = fresh.compactMap(WindowDescription.init(info:))
            .filter { $0.pid == pid && $0.layer == 0 }
            .map { TrackedWindow(id: $0.id, frame: $0.frame, pid: $0.pid, bundleID: nil, level: $0.layer) }
        focusedByPID[pid] = matcher.windowID(for: element, pid: pid, candidates: candidates)
    }

    // MARK: Observers

    private func observe(_ app: NSRunningApplication) {
        guard app.processIdentifier != getpid(),
              app.activationPolicy != .prohibited,
              appObservers[app.processIdentifier] == nil
        else { return }
        _ = makeObserver(pid: app.processIdentifier)
    }

    private func makeObserver(pid: pid_t) -> AppObserver? {
        guard pid != getpid() else { return nil }
        let observer = AppObserver(pid: pid) { [weak self] observer, event in
            guard let self else { return }
            switch event {
            case .windowsChanged:
                setNeedsRefresh()
            case .focusChanged:
                updateFocus(pid: observer.pid)
                setNeedsRefresh(restack: true)
            }
        }
        appObservers[pid] = observer
        return observer
    }

    // MARK: Logging

    private func log(previous: [TrackedWindow]) {
        let before = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let now = Set(windows.map(\.id))
        var lines: [String] = []
        for window in windows {
            let tag: String
            if let old = before[window.id] {
                guard old != window else { continue }
                tag = "~"
            } else {
                tag = "+"
            }
            lines.append("\(tag) \(describe(window))")
        }
        for window in previous where !now.contains(window.id) {
            lines.append("- \(describe(window))")
        }
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("[\(timestamp)] \(windows.count) windows, focused \(focusedWindowID.map(String.init) ?? "none")")
        for line in lines { print("  \(line)") }
        fflush(stdout)
    }

    private func describe(_ w: TrackedWindow) -> String {
        let f = w.frame
        return "#\(w.id) pid \(w.pid) \(w.bundleID ?? "?") (\(Int(f.minX)), \(Int(f.minY))) \(Int(f.width))×\(Int(f.height))"
    }
}
