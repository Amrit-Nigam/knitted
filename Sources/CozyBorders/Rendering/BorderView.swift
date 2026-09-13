import AppKit
import QuartzCore
import KnitCore

/// Hosts the layers the knit is drawn into. Redraws only when its size, style or yarn
/// changes — never on a plain move.
///
/// The view's own layer has no backing store. The ring is drawn into four edge-strip
/// sublayers, so memory scales with the border's perimeter rather than the window's area —
/// a full-size backing store for a large Retina window is ~20MB of transparent pixels.
final class BorderView: NSView, CALayerDelegate {
    /// Returns (fabric, cuff) swatches for a backing scale. Asked at draw time so a border
    /// that moves to a display with a different scale picks up correctly sized swatches.
    var swatches: ((CGFloat) -> (fabric: Swatch, cuff: Swatch)?)? {
        didSet { redrawStrips() }
    }

    var style = BorderStyle() {
        didSet {
            guard style != oldValue else { return }
            layoutStrips()
            redrawStrips()
        }
    }

    private let strips: [CALayer] = (0..<4).map { _ in CALayer() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        for strip in strips {
            strip.delegate = self
            strip.isOpaque = false
            strip.actions = ["bounds": NSNull(), "position": NSNull(), "contents": NSNull()]
            layer?.addSublayer(strip)
        }
        layoutStrips()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {}

    override func setFrameSize(_ newSize: NSSize) {
        let resized = newSize != frame.size
        super.setFrameSize(newSize)
        if resized {
            layoutStrips()
            redrawStrips()
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        redrawStrips()
    }

    /// Top and bottom strips span the full width; left and right fill the gap between them.
    /// Each is deep enough to cover the fabric plus the rounded-corner fill.
    private func layoutStrips() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let w = bounds.width, h = bounds.height
        let depth = min(style.borderWidth + max(style.windowCornerRadius, 0) + style.holeOverlap + 1, h / 2, w / 2)
        // Sublayer frames are in the root layer's coordinates, which are not flipped.
        let frames = [
            CGRect(x: 0, y: h - depth, width: w, height: depth),                   // top
            CGRect(x: 0, y: 0, width: w, height: depth),                           // bottom
            CGRect(x: 0, y: depth, width: depth, height: max(h - 2 * depth, 0)),   // left
            CGRect(x: w - depth, y: depth, width: depth, height: max(h - 2 * depth, 0)),  // right
        ]
        for (strip, frame) in zip(strips, frames) {
            strip.frame = frame
        }
    }

    private func redrawStrips() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        for strip in strips {
            strip.contentsScale = scale
            strip.setNeedsDisplay()
        }
    }

    // MARK: CALayerDelegate

    func draw(_ layer: CALayer, in ctx: CGContext) {
        guard layer.bounds.width > 0, layer.bounds.height > 0,
              let swatches = swatches?(layer.contentsScale) else { return }
        // Map the strip into the border's y-down space, then paint the whole ring clipped to it.
        let frame = layer.frame
        let flippedMinY = bounds.height - frame.maxY
        ctx.translateBy(x: 0, y: frame.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: -frame.minX, y: -flippedMinY)
        ctx.clip(to: CGRect(x: frame.minX, y: flippedMinY, width: frame.width, height: frame.height))
        BorderPainter.paint(in: ctx, bounds: bounds, style: style, fabric: swatches.fabric, cuff: swatches.cuff)
    }
}
