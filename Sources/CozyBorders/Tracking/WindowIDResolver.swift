import ApplicationServices
import CoreGraphics
import Foundation
import KnitCore

/// Maps an Accessibility window element to its `CGWindowID`. The two live in different
/// identifier spaces, and the only direct bridge is private API — so it sits behind this
/// protocol and can be swapped out if it ever breaks.
protocol WindowIDResolving {
    func windowID(for element: AXUIElement) -> CGWindowID?
}

/// `_AXUIElementGetWindow`: private, but widely used and stable for years. Looked up at
/// runtime so a missing symbol degrades to frame matching instead of failing to launch.
struct PrivateAXWindowIDResolver: WindowIDResolving {
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private let getWindow: GetWindow?

    init() {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        if let symbol = dlsym(rtldDefault, "_AXUIElementGetWindow") {
            getWindow = unsafeBitCast(symbol, to: GetWindow.self)
        } else {
            getWindow = nil
        }
    }

    var isAvailable: Bool { getWindow != nil }

    func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let getWindow else { return nil }
        var id: CGWindowID = 0
        guard getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }
}

/// Matches by (pid, frame) first and caches the association; falls back to the private
/// resolver only when the frame match is missing or ambiguous (e.g. two same-size windows
/// from one app at the same origin).
final class WindowMatcher {
    private let fallback: WindowIDResolving
    private var cache: [AXElementKey: CGWindowID] = [:]

    init(fallback: WindowIDResolving = PrivateAXWindowIDResolver()) {
        self.fallback = fallback
    }

    func windowID(for element: AXUIElement, pid: pid_t, candidates: [TrackedWindow]) -> CGWindowID? {
        let key = AXElementKey(element)
        let sameApp = candidates.filter { $0.pid == pid }
        if let cached = cache[key], sameApp.contains(where: { $0.id == cached }) {
            return cached
        }

        var resolved: CGWindowID?
        if let frame = AX.frame(of: element) {
            let matches = sameApp.filter { Self.framesMatch($0.frame, frame) }
            if matches.count == 1 { resolved = matches[0].id }
        }
        if resolved == nil {
            resolved = fallback.windowID(for: element)
        }
        if let resolved { cache[key] = resolved }
        return resolved
    }

    func forget(pid: pid_t) {
        cache = cache.filter { $0.key.pid != pid }
    }

    /// AX and CG frames can disagree by a point or so (and Electron apps can report stale
    /// AX frames), so allow a little slack.
    static func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }
}

/// Hashable wrapper so AX elements can key a dictionary (CFEqual / CFHash semantics).
struct AXElementKey: Hashable {
    let element: AXUIElement
    let pid: pid_t

    init(_ element: AXUIElement) {
        self.element = element
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        self.pid = pid
    }

    static func == (lhs: AXElementKey, rhs: AXElementKey) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Small typed wrappers over the AX C API.
enum AX {
    static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = copyValue(element, kAXPositionAttribute),
              let sizeValue = copyValue(element, kAXSizeAttribute)
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)  // Quartz coordinates, like CGWindowList.
    }

    static func focusedWindow(ofApplication app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    static func windows(ofApplication app: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let array = value as? [AXUIElement]
        else { return [] }
        return array
    }

    private static func copyValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        return (value as! AXValue)
    }
}
