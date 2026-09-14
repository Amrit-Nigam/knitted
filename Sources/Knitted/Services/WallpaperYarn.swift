import AppKit
import KnitCore

/// Yarn colours sampled from the desktop picture, re-sampled only when the picture changes.
@MainActor
final class WallpaperYarn {
    private var sampled: (url: URL, palette: YarnPalette)?

    func palette() -> YarnPalette {
        guard let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return .undyed
        }
        if let sampled, sampled.url == url { return sampled.palette }
        let palette = PaletteExtractor.palette(fromImageAt: url) ?? .undyed
        sampled = (url, palette)
        return palette
    }
}
