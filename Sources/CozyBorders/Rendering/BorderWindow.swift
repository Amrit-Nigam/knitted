import AppKit
import KnitCore

/// One borderless, click-through window per tracked window, sized to the target outset by
/// the border width.
final class BorderWindow: NSWindow {
    let targetID: CGWindowID
    let borderView: BorderView

    init(targetID: CGWindowID) {
        self.targetID = targetID
        borderView = BorderView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        super.init(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: .borderless, backing: .buffered, defer: false)
        styleMask = .borderless
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenNone]
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        setAccessibilityElement(false)
        contentView = borderView
    }

    /// Without this, AppKit nudges the border back on-screen when its window hangs off an edge.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(around target: TrackedWindow, borderWidth: CGFloat) {
        let outset = target.frame.insetBy(dx: -borderWidth, dy: -borderWidth)
        let rect = CoordinateSpace.appKitRect(fromQuartz: outset)
        guard rect != frame else { return }
        // Pure moves don't need a redraw; the fabric only changes shape on resize.
        setFrame(rect, display: rect.size != frame.size)
    }
}
