import CoreGraphics
import Foundation

/// The shape a single cell of fabric is knitted with.
public enum StitchGlyph: UInt8, Sendable {
    /// Stockinette knit face: a V.
    case knit
    /// Reverse face: a horizontal bump.
    case purl
    /// A knit V leaning left, for the stitches passing behind a cable crossing.
    case cableLeft
    /// A knit V leaning right, for the stitches crossing in front.
    case cableRight

    /// Within a row, glyphs are drawn in this order so front-crossing stitches land on top.
    var drawOrder: Int {
        switch self {
        case .purl: return 0
        case .cableLeft: return 1
        case .knit: return 2
        case .cableRight: return 3
        }
    }
}

/// Draws single stitches. All functions expect a y-down context in points (origin top-left
/// of the swatch) and a `cell` of `stitchWidth × stitchHeight`.
public enum StitchGeometry {
    /// Colour of the shadowed gaps between stitches.
    public static func gapColor(for yarn: YarnColor) -> YarnColor {
        yarn.shaded(-0.55)
    }

    public static func draw(_ glyph: StitchGlyph, in cell: CGRect, yarn: YarnColor, pixel: CGFloat, context ctx: CGContext) {
        switch glyph {
        case .knit:
            drawV(in: cell, lean: 0, yarn: yarn, pixel: pixel, context: ctx)
        case .cableLeft:
            drawV(in: cell, lean: -1, yarn: yarn.shaded(-0.1), pixel: pixel, context: ctx)
        case .cableRight:
            drawV(in: cell, lean: 1, yarn: yarn.shaded(0.04), pixel: pixel, context: ctx)
        case .purl:
            drawPurl(in: cell, yarn: yarn, pixel: pixel, context: ctx)
        }
    }

    // MARK: Paths

    /// The two legs of a knit V. Each leg is a tapered strand bounded by quadratic curves,
    /// running from a top corner of the cell down to a shared point at ~85% of its height.
    /// The tips reach up past the cell so they tuck behind the row above, and stay apart from
    /// the neighbouring column so a dark gap shows between stitches.
    public static func vLegs(in cell: CGRect, lean: CGFloat = 0) -> (left: CGPath, right: CGPath) {
        let w = cell.width, h = cell.height
        let shift = lean * w * 0.25
        let top = cell.minY - h * 0.3
        let bottom = CGPoint(x: cell.minX + w * 0.5 + shift, y: cell.minY + h * 0.88)
        let left = strand(from: CGPoint(x: cell.minX + w * 0.15 - shift, y: top), to: bottom,
                          thickness: w * 0.4, bend: -w * 0.05)
        let right = strand(from: CGPoint(x: cell.minX + w * 0.85 - shift, y: top), to: bottom,
                           thickness: w * 0.4, bend: w * 0.05)
        return (left, right)
    }

    /// A leaf-shaped strand from `a` to `b`, `thickness` wide at its middle, bowed sideways by `bend`.
    static func strand(from a: CGPoint, to b: CGPoint, thickness: CGFloat, bend: CGFloat) -> CGPath {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 0.001)
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let mid = CGPoint(x: (a.x + b.x) / 2 + bend, y: (a.y + b.y) / 2)
        // A quadratic's midpoint sits halfway to its control point, so offset by the full thickness.
        let p = CGMutablePath()
        p.move(to: a)
        p.addQuadCurve(to: b, control: CGPoint(x: mid.x + normal.x * thickness, y: mid.y + normal.y * thickness))
        p.addQuadCurve(to: a, control: CGPoint(x: mid.x - normal.x * thickness, y: mid.y - normal.y * thickness))
        p.closeSubpath()
        return p
    }

    /// A purl bump: a shallow arch across the cell.
    public static func purlArch(in cell: CGRect) -> CGPath {
        let w = cell.width, h = cell.height
        let p = CGMutablePath()
        p.move(to: CGPoint(x: cell.minX + w * 0.12, y: cell.minY + h * 0.62))
        p.addQuadCurve(to: CGPoint(x: cell.minX + w * 0.88, y: cell.minY + h * 0.62),
                       control: CGPoint(x: cell.minX + w * 0.5, y: cell.minY + h * 0.08))
        return p
    }

    // MARK: Drawing

    static func drawV(in cell: CGRect, lean: CGFloat, yarn: YarnColor, pixel: CGFloat, context ctx: CGContext) {
        let legs = vLegs(in: cell, lean: lean)
        let top = cell.minY - cell.height * 0.3
        let bottom = cell.minY + cell.height * 0.88
        // Left leg first; the right leg overlaps it slightly at the point, as the yarn does.
        for leg in [legs.left, legs.right] {
            drawYarn(shape: leg, top: top, bottom: bottom, yarn: yarn, pixel: pixel, context: ctx)
        }
    }

    static func drawPurl(in cell: CGRect, yarn: YarnColor, pixel: CGFloat, context ctx: CGContext) {
        let strokeWidth = cell.height * 0.55
        let shape = purlArch(in: cell).copy(strokingWithWidth: strokeWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)
        let box = shape.boundingBox
        drawYarn(shape: shape, top: box.minY, bottom: box.maxY, yarn: yarn.shaded(-0.06), pixel: pixel, context: ctx)
    }

    /// Fills one strand of yarn: cast shadow, lighter-at-top gradient for roundness, a faint
    /// ply twist, and a 1px darker inner shadow along the bottom curve.
    static func drawYarn(shape: CGPath, top: CGFloat, bottom: CGFloat, yarn: YarnColor, pixel: CGFloat, context ctx: CGContext) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!

        // Soft contact shadow onto whatever lies beneath.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pixel * 0.8)
        ctx.addPath(shape)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.28))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()

        let light = yarn.shaded(0.16), mid = yarn, dark = yarn.shaded(-0.28)
        let gradient = CGGradient(colorsSpace: space,
                                  colors: [light.cgColor, mid.cgColor, dark.cgColor] as CFArray,
                                  locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: bottom),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // Ply twist: fine diagonal lines, barely there, so the strand reads as spun fibre.
        let box = shape.boundingBox
        let spacing = max(pixel * 2.5, box.width * 0.22)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.07))
        ctx.setLineWidth(pixel)
        var x = box.minX - box.height
        while x < box.maxX {
            ctx.move(to: CGPoint(x: x, y: box.maxY))
            ctx.addLine(to: CGPoint(x: x + box.height, y: box.minY))
            x += spacing
        }
        ctx.strokePath()

        // Inner shadow: everything inside the strand that isn't covered by the strand nudged
        // up by one pixel — a crescent along the bottom edge.
        let shifted = CGMutablePath()
        shifted.addRect(box.insetBy(dx: -4, dy: -4))
        shifted.addPath(shape, transform: CGAffineTransform(translationX: 0, y: -pixel))
        ctx.addPath(shifted)
        ctx.setFillColor(dark.shaded(-0.35).cgColor(alpha: 0.85))
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }
}
