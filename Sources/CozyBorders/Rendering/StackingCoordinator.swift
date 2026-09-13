import AppKit
import KnitCore

/// Owns the border windows: creates, positions and removes them as the tracker reports, and
/// asks the ordering strategy to re-stack only when z-order or focus actually changed.
final class StackingCoordinator: WindowTrackerDelegate {
    private let store: PreferencesStore
    private(set) var strategy: WindowOrderingStrategy
    private var borders: [CGWindowID: BorderWindow] = [:]
    private let palettes = PaletteCache()
    private let swatches = SwatchCache()
    private var lastWindows: [TrackedWindow] = []
    private var lastFocused: CGWindowID?
    private var preferences: Preferences

    /// Fired when SkyLight ordering fails at runtime and we've fallen back to (b).
    var onStrategyFallback: (() -> Void)?

    init(store: PreferencesStore) {
        self.store = store
        preferences = store.preferences
        strategy = OrderingStrategies.make(store.preferences.ordering)
        wireFallback()
    }

    var activeMode: OrderingMode { strategy.mode }

    func preferencesDidChange() {
        let old = preferences
        preferences = store.preferences
        if preferences.ordering != strategy.mode || preferences.ordering != old.ordering {
            removeAllBorders()
            strategy = OrderingStrategies.make(preferences.ordering)
            wireFallback()
        }
        if preferences.stitch != old.stitch || preferences.paletteOverrides != old.paletteOverrides {
            swatches.removeAll()
        }
        rebuild(stackingChanged: true)
    }

    func removeAllBorders() {
        for border in borders.values { border.orderOut(nil) }
        borders.removeAll()
    }

    // MARK: WindowTrackerDelegate

    func windowTracker(_ tracker: WindowTracker, didUpdate windows: [TrackedWindow], focusedWindowID: CGWindowID?, stackingChanged: Bool) {
        lastWindows = windows
        lastFocused = focusedWindowID
        rebuild(stackingChanged: stackingChanged)
    }

    func windowTracker(_ tracker: WindowTracker, appDidTerminate bundleID: String?) {
        // Icons change rarely; relaunch is when we pick up a new one.
        palettes.invalidate(bundleID: bundleID)
    }

    // MARK: Layout

    private func rebuild(stackingChanged: Bool) {
        guard preferences.enabled else {
            removeAllBorders()
            return
        }

        let targets = strategy.bordersAllWindows ? lastWindows : lastWindows.filter { $0.id == lastFocused }
        let wanted = Set(targets.map(\.id))
        for (id, border) in borders where !wanted.contains(id) {
            border.orderOut(nil)
            borders[id] = nil
        }

        let style = BorderStyle(borderWidth: preferences.borderWidth, windowCornerRadius: preferences.windowCornerRadius,
                                holeOverlap: strategy.holeOverlap, stitch: preferences.stitch)
        var needsOrdering = stackingChanged
        var pairs: [(border: BorderWindow, target: TrackedWindow)] = []
        for target in targets {
            let border: BorderWindow
            if let existing = borders[target.id] {
                border = existing
            } else {
                border = BorderWindow(targetID: target.id)
                borders[target.id] = border
                needsOrdering = true
            }
            if border.level != strategy.borderLevel { border.level = strategy.borderLevel }
            configure(border.borderView, for: target, style: style)
            border.place(around: target, borderWidth: style.borderWidth)
            pairs.append((border, target))
        }

        if needsOrdering {
            strategy.order(pairs)
        }
    }

    private func configure(_ view: BorderView, for target: TrackedWindow, style: BorderStyle) {
        view.style = style
        if view.swatches == nil || view.identifier?.rawValue != swatchIdentity(for: target) {
            view.identifier = NSUserInterfaceItemIdentifier(swatchIdentity(for: target))
            let bundleID = target.bundleID ?? "pid:\(target.pid)"
            let pid = target.pid
            view.swatches = { [weak self] scale in
                guard let self else { return nil }
                let prefs = preferences
                let palette = prefs.paletteOverride(forBundleID: target.bundleID) ?? palettes.palette(bundleID: target.bundleID, pid: pid)
                let pattern = KnitPattern.named(prefs.pattern(forBundleID: target.bundleID))
                guard let fabric = swatches.swatch(bundleID: bundleID, pattern: pattern, palette: palette, stitch: prefs.stitch, scale: scale),
                      let cuff = swatches.swatch(bundleID: bundleID, pattern: .ribbing, palette: YarnPalette(colors: Array(repeating: palette.darkest, count: 4)),
                                                 stitch: prefs.stitch, scale: scale)
                else { return nil }
                return (fabric, cuff)
            }
        }
    }

    /// Changes whenever a preference that affects this window's yarn changes, so the view
    /// is handed a fresh swatch provider (and redraws) exactly then.
    private func swatchIdentity(for target: TrackedWindow) -> String {
        let id = target.bundleID
        let pattern = preferences.pattern(forBundleID: id).rawValue
        let palette = preferences.paletteOverrides[id ?? ""]?.joined() ?? "icon"
        return "\(id ?? "pid:\(target.pid)")|\(pattern)|\(palette)|\(preferences.stitchWidth)x\(preferences.stitchHeight)"
    }

    private func wireFallback() {
        guard let skyLight = strategy as? SkyLightStrategy else { return }
        skyLight.onFailure = { [weak self] in
            guard let self else { return }
            removeAllBorders()
            strategy = BelowNormalWindowsStrategy()
            rebuild(stackingChanged: true)
            onStrategyFallback?()
        }
    }
}
