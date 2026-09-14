import AppKit
import CoreGraphics
import Foundation

/// What a folder's sweater looks like.
public struct FolderSweater: Equatable, Hashable, Sendable {
    public var pattern: PatternID
    public var palette: YarnPalette
    /// Ribbed hem along the top of the front pocket.
    public var hasCuff: Bool

    public init(pattern: PatternID, palette: YarnPalette, hasCuff: Bool = true) {
        self.pattern = pattern
        self.palette = palette
        self.hasCuff = hasCuff
    }
}

/// Draws a macOS-style folder knitted out of yarn.
///
/// All geometry is laid out on a 1024-unit, y-down canvas and scaled to the requested pixel
/// size, so every size is drawn from the same design rather than resampled.
public enum FolderIconRenderer {
    public static let canvas: CGFloat = 1024

    /// Stitch size on the 1024 canvas. Big enough to read as knitting at desktop icon sizes
    /// (a 64pt icon shows ~20 stitches across).
    static let stitch = StitchSize(width: 36, height: 28)

    // Folder geometry, modelled on the macOS folder.
    static let back = CGRect(x: 84, y: 196, width: 856, height: 660)
    static let tab = CGRect(x: 84, y: 148, width: 344, height: 120)
    static let paper = CGRect(x: 132, y: 236, width: 760, height: 240)
    static let front = CGRect(x: 84, y: 300, width: 856, height: 576)
    static let cuffDepth: CGFloat = 104

    public static func image(for sweater: FolderSweater, pixelSize: Int) -> CGImage? {
        let size = CGFloat(pixelSize)
        guard let ctx = CGContext(data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let k = size / canvas
        ctx.translateBy(x: 0, y: size)
        ctx.scaleBy(x: k, y: -k)
        ctx.interpolationQuality = .high
        draw(sweater, in: ctx, pixelsPerUnit: k)
        return ctx.makeImage()
    }

    /// A multi-resolution `NSImage` suitable for `NSWorkspace.setIcon(_:forFile:)`.
    public static func icon(for sweater: FolderSweater) -> NSImage {
        let image = NSImage(size: NSSize(width: 512, height: 512))
        for pixels in [1024, 512, 256, 128, 64, 32] {
            guard let cg = FolderIconRenderer.image(for: sweater, pixelSize: pixels) else { continue }
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = NSSize(width: 512, height: 512)
            image.addRepresentation(rep)
        }
        return image
    }

    // MARK: Drawing

    static func draw(_ sweater: FolderSweater, in ctx: CGContext, pixelsPerUnit k: CGFloat) {
        let palette = sweater.palette
        let lead = palette.primary

        // Back panel with tab: plain stockinette in a deeper shade — the inside of the sweater.
        let backShape = roundedRect(back, 56).union(roundedRect(tab, 44)).union(tabShoulder())
        ctx.saveGState()
        shadow(ctx, k: k, dy: 10, blur: 28, color: CGColor(gray: 0, alpha: 0.28))
        ctx.addPath(backShape)
        ctx.setFillColor(lead.shaded(-0.3).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        let backYarn = YarnPalette(colors: Array(repeating: lead.shaded(-0.22), count: 4))
        fill(backShape, with: PatternLibrary.stockinette, palette: backYarn, origin: CGPoint(x: back.minX, y: tab.minY), k: k, in: ctx)
        rim(backShape, in: ctx, alpha: 0.3)

        // Paper peeking out of the pocket.
        let paperShape = roundedRect(paper, 18)
        ctx.saveGState()
        shadow(ctx, k: k, dy: 4, blur: 10, color: CGColor(gray: 0, alpha: 0.2))
        ctx.addPath(paperShape)
        ctx.setFillColor(YarnColor(hex: "#FBF8F1")!.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(paperShape)
        ctx.clip()
        ctx.setStrokeColor(CGColor(gray: 0.55, alpha: 0.18))
        ctx.setLineWidth(5)
        for y in stride(from: paper.minY + 30, to: paper.minY + 80, by: 22) {
            ctx.move(to: CGPoint(x: paper.minX + 40, y: y))
            ctx.addLine(to: CGPoint(x: paper.maxX - 40, y: y))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Front pocket: the pattern, casting a soft shadow up onto the paper and back panel.
        let frontShape = pocketShape()
        ctx.saveGState()
        shadow(ctx, k: k, dy: -8, blur: 30, color: CGColor(gray: 0, alpha: 0.35))
        ctx.addPath(frontShape)
        ctx.setFillColor(lead.shaded(-0.2).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        let cuffBottom = front.minY + (sweater.hasCuff ? cuffDepth : 0)
        let body = frontShape.intersection(CGPath(rect: CGRect(x: 0, y: cuffBottom, width: canvas, height: canvas), transform: nil))
        fill(body, with: sweater.pattern.pattern, palette: palette, origin: CGPoint(x: front.minX + stitch.width / 2, y: cuffBottom), k: k, in: ctx)

        if sweater.hasCuff {
            // Ribbed hem in the darkest yarn, flaring a touch past the pocket like a sweater cuff.
            let cuffRect = CGRect(x: front.minX - 10, y: front.minY - 6, width: front.width + 20, height: cuffDepth + 10)
            let cuff = roundedRect(cuffRect, 50)
            let cuffYarn = YarnPalette(colors: Array(repeating: cuffColor(for: palette), count: 4))
            ctx.saveGState()
            shadow(ctx, k: k, dy: 8, blur: 14, color: CGColor(gray: 0, alpha: 0.3))
            ctx.addPath(cuff)
            ctx.setFillColor(cuffYarn.primary.shaded(-0.3).cgColor)
            ctx.fillPath()
            ctx.restoreGState()
            fill(cuff, with: PatternLibrary.ribbing, palette: cuffYarn, origin: CGPoint(x: cuffRect.minX + 6, y: cuffRect.minY + 4), k: k, in: ctx)
            rim(cuff, in: ctx, alpha: 0.32)
            // A little light catching the rolled top edge.
            ctx.saveGState()
            ctx.addPath(cuff)
            ctx.clip()
            let highlight = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                       colors: [CGColor(gray: 1, alpha: 0.22), CGColor(gray: 1, alpha: 0)] as CFArray,
                                       locations: [0, 1])!
            ctx.drawLinearGradient(highlight, start: CGPoint(x: 0, y: cuffRect.minY), end: CGPoint(x: 0, y: cuffRect.minY + 36), options: [])
            ctx.restoreGState()
        }

        // Soft light from above across the whole pocket, so it reads as a padded object.
        ctx.saveGState()
        ctx.addPath(frontShape)
        ctx.clip()
        let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                               colors: [CGColor(gray: 1, alpha: 0.08), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.16)] as CFArray,
                               locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: front.minY), end: CGPoint(x: 0, y: front.maxY), options: [])
        ctx.restoreGState()
        rim(frontShape, in: ctx, alpha: 0.34)
    }

    /// `CGContext.setShadow` works in device space, ignoring the CTM, so scale it by hand.
    /// Offsets are given in the y-down canvas; device space is y-up.
    static func shadow(_ ctx: CGContext, k: CGFloat, dy: CGFloat, blur: CGFloat, color: CGColor) {
        ctx.setShadow(offset: CGSize(width: 0, height: -dy * k), blur: blur * k, color: color)
    }

    /// Tiles a swatch across `shape`, rows anchored at `origin` so the pattern starts on a
    /// whole stitch at the top of each piece.
    static func fill(_ shape: CGPath, with pattern: KnitPattern, palette: YarnPalette, origin: CGPoint, k: CGFloat, in ctx: CGContext) {
        guard let swatch = SwatchRenderer.render(pattern: pattern, palette: palette, stitch: stitch, scale: k) else { return }
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        // Round the anchor to whole device pixels so tiles meet without hairline seams.
        let ox = (origin.x * k).rounded() / k, oy = (origin.y * k).rounded() / k
        ctx.translateBy(x: ox, y: oy)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(swatch.image, in: CGRect(x: 0, y: -swatch.size.height, width: swatch.size.width, height: swatch.size.height), byTiling: true)
        ctx.restoreGState()
    }

    /// Darkens just inside a piece's edge so the fabric has thickness.
    static func rim(_ shape: CGPath, in ctx: CGContext, alpha: CGFloat) {
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        ctx.addPath(shape)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: alpha))
        ctx.setLineWidth(18)
        ctx.strokePath()
        ctx.restoreGState()
    }

    public static func cuffColor(for palette: YarnPalette) -> YarnColor {
        // The darkest yarn, unless it's barely different from the pocket — then deepen the lead.
        let darkest = palette.darkest
        return darkest.deltaE(palette.primary) < 12 ? palette.primary.shaded(-0.3) : darkest
    }

    static func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// The pocket bulges very slightly at the sides, like fabric over a stuffed folder.
    static func pocketShape() -> CGPath {
        let r: CGFloat = 60
        let bulge: CGFloat = 8
        let f = front
        let p = CGMutablePath()
        p.move(to: CGPoint(x: f.minX + r, y: f.minY))
        p.addLine(to: CGPoint(x: f.maxX - r, y: f.minY))
        p.addQuadCurve(to: CGPoint(x: f.maxX, y: f.minY + r), control: CGPoint(x: f.maxX, y: f.minY))
        p.addQuadCurve(to: CGPoint(x: f.maxX, y: f.maxY - r), control: CGPoint(x: f.maxX + bulge, y: f.midY))
        p.addQuadCurve(to: CGPoint(x: f.maxX - r, y: f.maxY), control: CGPoint(x: f.maxX, y: f.maxY))
        p.addLine(to: CGPoint(x: f.minX + r, y: f.maxY))
        p.addQuadCurve(to: CGPoint(x: f.minX, y: f.maxY - r), control: CGPoint(x: f.minX, y: f.maxY))
        p.addQuadCurve(to: CGPoint(x: f.minX, y: f.minY + r), control: CGPoint(x: f.minX - bulge, y: f.midY))
        p.addQuadCurve(to: CGPoint(x: f.minX + r, y: f.minY), control: CGPoint(x: f.minX, y: f.minY))
        p.closeSubpath()
        return p
    }

    /// The slope from the tab down to the back panel's top edge.
    static func tabShoulder() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: tab.maxX - 60, y: tab.minY))
        p.addQuadCurve(to: CGPoint(x: tab.maxX + 30, y: back.minY), control: CGPoint(x: tab.maxX + 4, y: tab.minY))
        p.addLine(to: CGPoint(x: tab.maxX - 60, y: back.minY + 40))
        p.closeSubpath()
        return p
    }
}
