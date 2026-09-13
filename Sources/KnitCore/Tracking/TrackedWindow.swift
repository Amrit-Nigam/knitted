import CoreGraphics
import Foundation

/// A snapshot of one on-screen window owned by another app.
///
/// `frame` is always in Quartz global coordinates (origin at the top-left of the primary
/// display, y increasing downward) — the space `CGWindowListCopyWindowInfo` and the
/// Accessibility API both report in. Convert with `CoordinateSpace` before handing a rect
/// to AppKit.
public struct TrackedWindow: Equatable, Sendable {
    public let id: CGWindowID
    public var frame: CGRect
    public let pid: pid_t
    public let bundleID: String?
    public let level: Int

    public init(id: CGWindowID, frame: CGRect, pid: pid_t, bundleID: String?, level: Int) {
        self.id = id
        self.frame = frame
        self.pid = pid
        self.bundleID = bundleID
        self.level = level
    }
}

/// The one place Quartz <-> AppKit rect conversion happens. Never do this arithmetic inline.
///
/// Quartz: origin top-left of the primary display, y down.
/// AppKit: origin bottom-left of the primary display, y up.
/// Both are in points, so display scale factors do not enter into it; only the height of
/// the primary display (the one whose Quartz origin is 0,0) matters. Displays above the
/// primary have negative Quartz y and AppKit y greater than the primary height.
public enum CoordinateSpace {
    public static func appKitRect(fromQuartz rect: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryDisplayHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    /// The transform is its own inverse; named separately so call sites read correctly.
    public static func quartzRect(fromAppKit rect: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        appKitRect(fromQuartz: rect, primaryDisplayHeight: primaryDisplayHeight)
    }

    /// Height of the display with the menu bar, which anchors both coordinate systems.
    public static var primaryDisplayHeight: CGFloat {
        CGDisplayBounds(CGMainDisplayID()).height
    }

    public static func appKitRect(fromQuartz rect: CGRect) -> CGRect {
        appKitRect(fromQuartz: rect, primaryDisplayHeight: primaryDisplayHeight)
    }
}
