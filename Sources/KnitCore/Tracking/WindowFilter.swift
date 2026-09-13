import CoreGraphics
import Foundation

/// A window as described by `CGWindowListCopyWindowInfo`, reduced to what filtering needs.
public struct WindowDescription: Equatable, Sendable {
    public var id: CGWindowID
    public var frame: CGRect
    public var pid: pid_t
    public var layer: Int
    public var alpha: Double
    public var isOnscreen: Bool

    public init(id: CGWindowID, frame: CGRect, pid: pid_t, layer: Int, alpha: Double = 1, isOnscreen: Bool = true) {
        self.id = id
        self.frame = frame
        self.pid = pid
        self.layer = layer
        self.alpha = alpha
        self.isOnscreen = isOnscreen
    }

    /// Parses one entry of the `CGWindowListCopyWindowInfo` array.
    public init?(info: [String: Any]) {
        guard let number = info[kCGWindowNumber as String] as? NSNumber,
              let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
              let layer = info[kCGWindowLayer as String] as? NSNumber,
              let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: boundsDict)
        else { return nil }
        self.id = number.uint32Value
        self.pid = pid.int32Value
        self.layer = layer.intValue
        self.frame = frame
        self.alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        self.isOnscreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? true
    }
}

public struct WindowFilter: Sendable {
    public var ownPID: pid_t
    public var minimumSize: CGFloat = 80
    public var excludedBundleIDs: Set<String> = []
    /// Quartz bounds of every active display, used to recognise fullscreen windows.
    public var displayBounds: [CGRect] = []

    public init(ownPID: pid_t, excludedBundleIDs: Set<String> = [], displayBounds: [CGRect] = []) {
        self.ownPID = ownPID
        self.excludedBundleIDs = excludedBundleIDs
        self.displayBounds = displayBounds
    }

    public func accepts(_ window: WindowDescription, bundleID: String?) -> Bool {
        guard window.layer == 0 else { return false }
        guard window.isOnscreen, window.alpha > 0.01 else { return false }
        guard window.frame.width >= minimumSize, window.frame.height >= minimumSize else { return false }
        guard window.pid != ownPID else { return false }
        if let bundleID, excludedBundleIDs.contains(bundleID) { return false }
        if isFullscreen(window.frame) { return false }
        return true
    }

    func isFullscreen(_ frame: CGRect) -> Bool {
        displayBounds.contains { display in
            abs(display.minX - frame.minX) < 1 && abs(display.minY - frame.minY) < 1
                && abs(display.width - frame.width) < 1 && abs(display.height - frame.height) < 1
        }
    }

    public static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
}
