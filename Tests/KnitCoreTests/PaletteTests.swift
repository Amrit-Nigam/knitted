import CoreGraphics
import Testing
@testable import KnitCore

struct PaletteTests {
    func pixels(_ spec: [(String, Int)], transparent: Int = 0) -> [SampledPixel] {
        var result: [SampledPixel] = []
        for (hex, count) in spec {
            result += Array(repeating: SampledPixel(color: YarnColor(hex: hex)!, alpha: 1), count: count)
        }
        result += Array(repeating: SampledPixel(color: YarnColor(r: 0, g: 0, b: 0), alpha: 0), count: transparent)
        return result
    }

    @Test func hslRoundTrip() {
        for hex in ["#1DB954", "#FF0000", "#336699", "#808080", "#F5DEB3"] {
            let c = YarnColor(hex: hex)!
            let back = YarnColor(hsl: c.hsl)
            #expect(c.deltaE(back) < 0.5, "\(hex)")
        }
    }

    @Test func spotifyGreenKnitsGreen() {
        let palette = PaletteExtractor.palette(from: pixels([("#1DB954", 600), ("#191414", 300)], transparent: 124))
        let hue = palette.primary.hsl.h * 360
        #expect(hue > 100 && hue < 170)
    }

    @Test func woolIsNeverNeonOrBlack() {
        let palette = PaletteExtractor.palette(from: pixels([("#00FF00", 400), ("#FF00FF", 300), ("#0000FF", 200), ("#000000", 124)]))
        for yarn in palette.colors {
            #expect(yarn.lightness >= 0.24 && yarn.lightness <= 0.76)
            #expect(yarn.saturation <= 0.86)
        }
    }

    @Test func mostlyWhiteIconBuildsMonochromePalette() {
        let palette = PaletteExtractor.palette(from: pixels([("#FFFFFF", 700), ("#DDDDDD", 150), ("#888888", 100), ("#FF3B30", 20)]))
        for yarn in palette.colors.prefix(3) {
            #expect(yarn.saturation < 0.12)
        }
    }

    @Test func smallVividLogoOnDarkTileKeepsItsColour() {
        let palette = PaletteExtractor.palette(from: pixels([("#1A1A1A", 800), ("#2A2A2A", 100), ("#13AA52", 80)]))
        let hue = palette.primary.hsl.h * 360
        #expect(palette.primary.saturation > 0.2)
        #expect(hue > 100 && hue < 170)
    }

    @Test func leadingYarnsAreDistinguishable() {
        let palette = PaletteExtractor.palette(from: pixels([("#3366CC", 500), ("#3A6BD0", 300), ("#2F60C0", 200)]))
        #expect(palette.colors[0].deltaE(palette.colors[1]) >= 10)
        #expect(palette.colors[1].deltaE(palette.colors[2]) >= 10)
    }

    @Test func transparentIconFallsBackToUndyed() {
        #expect(PaletteExtractor.palette(from: pixels([], transparent: 1024)) == .undyed)
    }

    @Test func backgroundIsDesaturated() {
        let palette = PaletteExtractor.palette(from: pixels([("#E03C31", 700), ("#1E90FF", 300)]))
        #expect(palette.background.saturation < palette.primary.saturation)
    }
}
