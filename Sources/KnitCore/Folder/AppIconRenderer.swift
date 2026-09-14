import CoreGraphics
import Foundation

/// The app's own icon: a knitted folder resting on a cream tile, laid out on Apple's macOS
/// icon grid (an 824-unit rounded square centred on a 1024 canvas, with room for its shadow).
public enum AppIconRenderer {
    static let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let tileRadius: CGFloat = 185
    /// How much of the tile the folder takes up.
    static let folderScale: CGFloat = 0.64

    public static let sweater = FolderSweater(pattern: .fairIsle, palette: YarnPreset.all[0].palette)

    public static func image(pixelSize: Int) -> CGImage? {
        let size = CGFloat(pixelSize)
        guard let ctx = CGContext(data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let k = size / FolderIconRenderer.canvas
        ctx.translateBy(x: 0, y: size)
        ctx.scaleBy(x: k, y: -k)
        ctx.interpolationQuality = .high

        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let tilePath = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)

        // Tile with a soft drop shadow.
        ctx.saveGState()
        FolderIconRenderer.shadow(ctx, k: k, dy: 12, blur: 24, color: CGColor(gray: 0, alpha: 0.3))
        ctx.addPath(tilePath)
        ctx.setFillColor(YarnColor(hex: "#F4E6C4")!.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Warm cream, lighter at the top, like paper catching the light.
        ctx.saveGState()
        ctx.addPath(tilePath)
        ctx.clip()
        let cream = CGGradient(colorsSpace: space,
                               colors: [YarnColor(hex: "#FBF2DC")!.cgColor, YarnColor(hex: "#F1DFB6")!.cgColor] as CFArray,
                               locations: [0, 1])!
        ctx.drawLinearGradient(cream, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
        // Inner edge: a whisper of highlight on top, shade at the bottom.
        ctx.addPath(tilePath)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.6))
        ctx.setLineWidth(6)
        ctx.strokePath()
        ctx.restoreGState()

        // The folder, centred on the tile (its artwork sits slightly high on its own canvas).
        ctx.saveGState()
        ctx.translateBy(x: tile.midX, y: tile.midY + 10)
        ctx.scaleBy(x: folderScale, y: folderScale)
        ctx.translateBy(x: -FolderIconRenderer.canvas / 2, y: -FolderIconRenderer.canvas / 2)
        FolderIconRenderer.draw(sweater, in: ctx, pixelsPerUnit: k * folderScale)
        ctx.restoreGState()

        return ctx.makeImage()
    }
}
