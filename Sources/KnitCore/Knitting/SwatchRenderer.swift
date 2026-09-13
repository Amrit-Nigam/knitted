import CoreGraphics
import Foundation

public struct StitchSize: Hashable, Codable, Sendable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

/// A rendered, seamlessly tileable piece of fabric: one whole pattern repeat.
public struct Swatch {
    public let image: CGImage
    /// Size of one repeat in points. `image` is `size × scale` pixels.
    public let size: CGSize
    public let scale: CGFloat
}

/// Knits a pattern repeat into a `CGImage` once. Never called on window move.
public enum SwatchRenderer {
    public static func render(pattern: KnitPattern, palette: YarnPalette, stitch: StitchSize, scale: CGFloat) -> Swatch? {
        let size = CGSize(width: CGFloat(pattern.columns) * stitch.width, height: CGFloat(pattern.rows) * stitch.height)
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                                  bytesPerRow: pixelWidth * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // y-down, points.
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        let pixel = 1 / scale

        func yarn(column: Int, row: Int) -> YarnColor {
            let base = palette[pattern[column, row].colorIndex]
            // A little per-stitch tension variation. Hash on the wrapped cell so it tiles.
            let c = ((column % pattern.columns) + pattern.columns) % pattern.columns
            let r = ((row % pattern.rows) + pattern.rows) % pattern.rows
            var h = UInt32(truncatingIfNeeded: c &* 73_856_093 ^ r &* 19_349_663)
            h ^= h >> 13
            h = h &* 0x5BD1_E995
            h ^= h >> 15
            let jitter = (Double(h % 1000) / 1000 - 0.5) * 0.07
            return base.shaded(jitter)
        }

        func cellRect(column: Int, row: Int) -> CGRect {
            let offset = pattern.offsetsAlternateRows && ((row % 2) + 2) % 2 == 1 ? stitch.width / 2 : 0
            return CGRect(x: CGFloat(column) * stitch.width + offset, y: CGFloat(row) * stitch.height,
                          width: stitch.width, height: stitch.height)
        }

        // Shadowed gaps first, then stitches.
        for row in -1...pattern.rows {
            for column in -1...pattern.columns {
                let rect = cellRect(column: column, row: row)
                ctx.setFillColor(StitchGeometry.gapColor(for: yarn(column: column, row: row)).cgColor)
                ctx.fill(rect.insetBy(dx: -pixel / 2, dy: -pixel / 2))
            }
        }

        // Bottom row first so each stitch's top ends tuck behind the row above. One row of
        // wrapped neighbours on every side keeps the repeat edges seamless.
        for row in stride(from: pattern.rows, through: -1, by: -1) {
            let columns = (-1...pattern.columns).sorted {
                pattern[$0, row].glyph.drawOrder < pattern[$1, row].glyph.drawOrder
            }
            for column in columns {
                StitchGeometry.draw(pattern[column, row].glyph, in: cellRect(column: column, row: row),
                                    yarn: yarn(column: column, row: row), pixel: pixel, context: ctx)
            }
        }

        guard let image = ctx.makeImage() else { return nil }
        return Swatch(image: image, size: size, scale: scale)
    }
}

/// Swatches keyed by (bundleID, pattern, stitch size, scale, palette). Main thread only.
public final class SwatchCache {
    struct Key: Hashable {
        var bundleID: String
        var patternID: String
        var stitch: StitchSize
        var scale: CGFloat
        var palette: YarnPalette
    }

    private var swatches: [Key: Swatch] = [:]

    public init() {}

    public func swatch(bundleID: String, pattern: KnitPattern, palette: YarnPalette, stitch: StitchSize, scale: CGFloat) -> Swatch? {
        let key = Key(bundleID: bundleID, patternID: pattern.id, stitch: stitch, scale: scale, palette: palette)
        if let cached = swatches[key] { return cached }
        let swatch = SwatchRenderer.render(pattern: pattern, palette: palette, stitch: stitch, scale: scale)
        swatches[key] = swatch
        return swatch
    }

    public func removeAll() { swatches.removeAll() }
}
