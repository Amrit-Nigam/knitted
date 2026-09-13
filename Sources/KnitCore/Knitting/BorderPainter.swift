import CoreGraphics
import Foundation

public struct BorderStyle: Equatable, Sendable {
    public var borderWidth: CGFloat
    /// Corner radius of the window being wrapped.
    public var windowCornerRadius: CGFloat
    /// How far the fabric reaches under the window. Positive when borders sit beneath their
    /// window, so no sliver of desktop shows at the seam; zero when borders sit on top.
    public var holeOverlap: CGFloat
    public var stitch: StitchSize
    public var cuffRows: Int
    /// How much narrower the band is than the cuffs, in points.
    public var flare: CGFloat

    public init(borderWidth: CGFloat = 14, windowCornerRadius: CGFloat = 12, holeOverlap: CGFloat = 0,
                stitch: StitchSize = StitchSize(width: 4.5, height: 3.5), cuffRows: Int = 3, flare: CGFloat = 1.5) {
        self.borderWidth = borderWidth
        self.windowCornerRadius = windowCornerRadius
        self.holeOverlap = holeOverlap
        self.stitch = stitch
        self.cuffRows = cuffRows
        self.flare = flare
    }
}

/// Composes swatches into the ring around a window. Expects a y-down context in points
/// whose `bounds` is the border window (the target window outset by `borderWidth`).
///
/// Each edge is a knitted band whose rows run along the edge; bands meet the cuffs at the
/// corners with mitred seams.
public enum BorderPainter {
    public static func paint(in ctx: CGContext, bounds: CGRect, style: BorderStyle, fabric: Swatch, cuff: Swatch) {
        let geometry = Geometry(bounds: bounds, style: style)

        for edge in Edge.allCases {
            let transform = edge.transform(in: bounds)
            var t = transform
            let trapezoid = geometry.trapezoid(for: edge).copy(using: &t)!

            // Band.
            ctx.saveGState()
            ctx.addPath(geometry.band)
            ctx.clip()
            ctx.addPath(trapezoid)
            ctx.clip()
            ctx.concatenate(transform)
            tile(fabric, in: ctx)
            ctx.restoreGState()

            // Cuffs.
            ctx.saveGState()
            ctx.addPath(geometry.cuffs)
            ctx.clip()
            ctx.addPath(trapezoid)
            ctx.clip()
            ctx.concatenate(transform)
            tile(cuff, in: ctx)
            ctx.restoreGState()
        }

        // Fabric thickness: darken just inside every cut edge, and mark the cuff seams.
        ctx.saveGState()
        ctx.addPath(geometry.fabric)
        ctx.clip()
        ctx.addPath(geometry.fabric)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.28))
        ctx.setLineWidth(2.4)
        ctx.strokePath()
        ctx.addPath(geometry.cuffs)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.22))
        ctx.setLineWidth(1.4)
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Tiles a swatch over the current clip. Local space is edge-aligned: x along the edge,
    /// y inward from the outer edge, y-down. The swatch's rows stack inward from y = 0, so
    /// every edge starts on a whole row at the outside of the fabric.
    static func tile(_ swatch: Swatch, in ctx: CGContext) {
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(swatch.image, in: CGRect(x: 0, y: -swatch.size.height, width: swatch.size.width, height: swatch.size.height),
                 byTiling: true)
        ctx.restoreGState()
    }

    enum Edge: CaseIterable {
        case top, right, bottom, left

        /// Maps edge-local coordinates (x along the edge, y inward) into border coordinates.
        func transform(in bounds: CGRect) -> CGAffineTransform {
            switch self {
            case .top:
                return CGAffineTransform(translationX: bounds.minX, y: bounds.minY)
            case .right:
                return CGAffineTransform(translationX: bounds.maxX, y: bounds.minY).rotated(by: .pi / 2)
            case .bottom:
                return CGAffineTransform(translationX: bounds.maxX, y: bounds.maxY).rotated(by: .pi)
            case .left:
                return CGAffineTransform(translationX: bounds.minX, y: bounds.maxY).rotated(by: -.pi / 2)
            }
        }

        func length(in bounds: CGRect) -> CGFloat {
            switch self {
            case .top, .bottom: return bounds.width
            case .left, .right: return bounds.height
            }
        }
    }

    struct Geometry {
        let bounds: CGRect
        let depth: CGFloat
        /// How deep the mitred edge strips reach: past the fabric and the window's rounded
        /// corner, so the corner fill is split along the diagonal too. The hole clips the rest.
        let reach: CGFloat
        let band: CGPath
        let cuffs: CGPath
        let fabric: CGPath

        init(bounds: CGRect, style: BorderStyle) {
            self.bounds = bounds
            let bw = style.borderWidth
            depth = bw + style.holeOverlap
            reach = bw + max(style.windowCornerRadius, 0) + style.flare

            let target = bounds.insetBy(dx: bw, dy: bw)
            let hole = target.insetBy(dx: style.holeOverlap, dy: style.holeOverlap)
            let holePath = Self.roundedRect(hole, radius: style.windowCornerRadius - style.holeOverlap)
            let outer = Self.roundedRect(bounds, radius: style.windowCornerRadius + bw)
            let flared = Self.roundedRect(bounds.insetBy(dx: style.flare, dy: style.flare),
                                          radius: style.windowCornerRadius + bw - style.flare)

            let zones = CuffRenderer.cuffZones(in: bounds, depth: reach,
                                               extension: CuffRenderer.cuffExtension(stitch: style.stitch, rows: style.cuffRows))
            cuffs = outer.intersection(zones).subtracting(holePath)
            band = flared.subtracting(zones).subtracting(holePath)
            fabric = cuffs.union(band)
        }

        /// The mitred strip belonging to one edge, in edge-local coordinates.
        func trapezoid(for edge: Edge) -> CGPath {
            let length = edge.length(in: bounds)
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: length, y: 0))
            p.addLine(to: CGPoint(x: length - reach, y: reach))
            p.addLine(to: CGPoint(x: reach, y: reach))
            p.closeSubpath()
            return p
        }

        static func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
            let r = max(0, min(radius, rect.width / 2, rect.height / 2))
            guard rect.width > 0, rect.height > 0 else { return CGMutablePath() }
            return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        }
    }
}
