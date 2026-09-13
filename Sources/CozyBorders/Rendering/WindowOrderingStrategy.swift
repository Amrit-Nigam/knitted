import AppKit
import KnitCore

/// How border windows are placed in the global stack. Public AppKit can't order our window
/// relative to another process's window, so each strategy trades fidelity for risk.
protocol WindowOrderingStrategy: AnyObject {
    var mode: OrderingMode { get }
    /// False for strategy (a), which only borders the focused window.
    var bordersAllWindows: Bool { get }
    var borderLevel: NSWindow.Level { get }
    /// Fabric reaching under the window. Only safe when borders sit beneath their window.
    var holeOverlap: CGFloat { get }
    /// `pairs` is front-to-back by target z-order.
    func order(_ pairs: [(border: BorderWindow, target: TrackedWindow)])
}

/// (a) Only the frontmost window, floating. Trivially correct stacking.
final class FocusedWindowStrategy: WindowOrderingStrategy {
    let mode = OrderingMode.focusedOnly
    let bordersAllWindows = false
    let borderLevel = NSWindow.Level.floating
    let holeOverlap: CGFloat = 0

    func order(_ pairs: [(border: BorderWindow, target: TrackedWindow)]) {
        for pair in pairs { pair.border.orderFrontRegardless() }
    }
}

/// (b) Every window, all borders one level below normal windows, so each window hides the
/// part of any border behind it. Borders are stacked among themselves in their windows'
/// order, so where two borders overlap the front window's wins. Public API only.
final class BelowNormalWindowsStrategy: WindowOrderingStrategy {
    let mode = OrderingMode.belowAll
    let bordersAllWindows = true
    let borderLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
    let holeOverlap: CGFloat = 3

    func order(_ pairs: [(border: BorderWindow, target: TrackedWindow)]) {
        // Back to front: each orderFront lands on top of the previous one.
        for pair in pairs.reversed() { pair.border.orderFrontRegardless() }
    }
}

/// (c) Private SkyLight: order each border directly beneath its own window. The only way to
/// get per-window correctness; can break on any macOS release.
final class SkyLightStrategy: WindowOrderingStrategy {
    let mode = OrderingMode.skyLight
    let bordersAllWindows = true
    let borderLevel = NSWindow.Level.normal
    let holeOverlap: CGFloat = 3

    /// Called once if ordering calls start failing at runtime, so the owner can fall back.
    var onFailure: (() -> Void)?

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias OrderWindow = @convention(c) (Int32, UInt32, Int32, UInt32) -> Int32
    private let connection: Int32
    private let orderWindow: OrderWindow
    private var failures = 0

    private static let orderBelow: Int32 = -1

    /// Nil when the symbols aren't present on this OS.
    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let mainSymbol = dlsym(handle, "SLSMainConnectionID"),
              let orderSymbol = dlsym(handle, "SLSOrderWindow")
        else { return nil }
        let mainConnection = unsafeBitCast(mainSymbol, to: MainConnectionID.self)
        orderWindow = unsafeBitCast(orderSymbol, to: OrderWindow.self)
        connection = mainConnection()
        guard connection != 0 else { return nil }
    }

    func order(_ pairs: [(border: BorderWindow, target: TrackedWindow)]) {
        for pair in pairs.reversed() {
            let border = pair.border
            if !border.isVisible {
                // Keep a brand-new border invisible until it's tucked under its window.
                border.alphaValue = 0
                border.orderFrontRegardless()
            }
            let result = orderWindow(connection, UInt32(border.windowNumber), Self.orderBelow, pair.target.id)
            if result == 0 {
                border.alphaValue = 1
            } else {
                failures += 1
                border.alphaValue = 1
            }
        }
        if failures > 20, let onFailure {
            self.onFailure = nil
            onFailure()
        }
    }
}

enum OrderingStrategies {
    /// Builds the strategy for a mode, falling back to (b) when SkyLight isn't available.
    static func make(_ mode: OrderingMode) -> WindowOrderingStrategy {
        switch mode {
        case .focusedOnly: return FocusedWindowStrategy()
        case .belowAll: return BelowNormalWindowsStrategy()
        case .skyLight: return SkyLightStrategy() ?? BelowNormalWindowsStrategy()
        }
    }
}
