import CoreGraphics
import Foundation

/// Memoises rendered folder icons, swatches and cuffs. Everything here is pure, so a design
/// change re-renders only what's new; flipping back to a previous choice is instant.
/// Safe to use from any thread.
public final class RenderCache: @unchecked Sendable {
    public static let shared = RenderCache()

    private let icons = NSCache<Key, CGImage>()
    private let swatches = NSCache<Key, SwatchBox>()

    public init() {
        icons.countLimit = 400
        swatches.countLimit = 400
    }

    public func icon(for sweater: FolderSweater, pixelSize: Int) -> CGImage? {
        let key = Key(IconKey(sweater: sweater, pixelSize: pixelSize))
        if let hit = icons.object(forKey: key) { return hit }
        guard let image = FolderIconRenderer.image(for: sweater, pixelSize: pixelSize) else { return nil }
        icons.setObject(image, forKey: key)
        return image
    }

    public func swatch(_ pattern: KnitPattern, palette: YarnPalette, stitch: StitchSize, scale: CGFloat) -> Swatch? {
        let key = Key(SwatchKey(patternID: pattern.id, palette: palette, stitch: stitch, scale: scale))
        if let hit = swatches.object(forKey: key) { return hit.swatch }
        guard let swatch = SwatchRenderer.render(pattern: pattern, palette: palette, stitch: stitch, scale: scale) else { return nil }
        swatches.setObject(SwatchBox(swatch), forKey: key)
        return swatch
    }

    /// Fabric plus a ribbed cuff in the darkest yarn: everything a knitted frame needs.
    public func frameSwatches(for sweater: FolderSweater, stitch: StitchSize, scale: CGFloat) -> (fabric: Swatch, cuff: Swatch)? {
        let cuffYarn = YarnPalette(colors: Array(repeating: FolderIconRenderer.cuffColor(for: sweater.palette), count: 4))
        guard let fabric = swatch(sweater.pattern.pattern, palette: sweater.palette, stitch: stitch, scale: scale),
              let cuff = swatch(PatternLibrary.ribbing, palette: cuffYarn, stitch: stitch, scale: scale)
        else { return nil }
        return (fabric, cuff)
    }

    private struct IconKey: Hashable {
        let sweater: FolderSweater
        let pixelSize: Int
    }

    private struct SwatchKey: Hashable {
        let patternID: String
        let palette: YarnPalette
        let stitch: StitchSize
        let scale: CGFloat
    }

    /// NSCache needs object keys; this wraps any Hashable value.
    private final class Key: NSObject {
        let value: AnyHashable
        init(_ value: AnyHashable) { self.value = value }
        override var hash: Int { value.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? Key)?.value == value }
    }

    private final class SwatchBox {
        let swatch: Swatch
        init(_ swatch: Swatch) { self.swatch = swatch }
    }
}
