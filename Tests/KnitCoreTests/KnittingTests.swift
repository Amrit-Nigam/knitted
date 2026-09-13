import CoreGraphics
import Testing
@testable import KnitCore

struct KnittingTests {
    @Test func patternAssignmentIsStableAndVaried() {
        #expect(PatternID.assigned(toBundleID: "com.apple.finder") == PatternID.assigned(toBundleID: "com.apple.finder"))
        let ids = ["com.apple.finder", "com.spotify.client", "com.apple.Safari", "com.microsoft.VSCode",
                   "com.tinyspeck.slackmacgap", "com.apple.mail", "com.apple.Notes", "com.google.Chrome"]
        #expect(Set(ids.map(PatternID.assigned(toBundleID:))).count >= 3)
        #expect(PatternID.autoAssigned.contains(PatternID.assigned(toBundleID: "anything")))
    }

    @Test func patternRepeatsMatchSpec() {
        #expect((KnitPattern.stripes.columns, KnitPattern.stripes.rows) == (1, 6))
        #expect((KnitPattern.fairIsle.columns, KnitPattern.fairIsle.rows) == (8, 8))
        #expect((KnitPattern.seed.columns, KnitPattern.seed.rows) == (2, 2))
        #expect((KnitPattern.argyle.columns, KnitPattern.argyle.rows) == (12, 16))
        #expect((KnitPattern.cable.columns, KnitPattern.cable.rows) == (6, 12))
    }

    @Test func patternColourCounts() {
        func colours(_ p: KnitPattern) -> Set<Int> { Set(p.cells.map(\.colorIndex)) }
        #expect(colours(.fairIsle).count == 3)  // ground, motif, dot
        #expect(colours(.seed).count == 1)
        #expect(colours(.argyle).count == 3)
        #expect(colours(.cable).count == 1)
        #expect(Set(KnitPattern.cable.cells.map(\.glyph)).count > 1)
    }

    @Test func lookupWraps() {
        let p = KnitPattern.fairIsle
        #expect(p[-1, -1] == p[7, 7])
        #expect(p[8, 16] == p[0, 0])
    }

    @Test func swatchIsWholeRepeatAtScale() throws {
        let palette = YarnPalette.undyed
        let stitch = StitchSize(width: 4.5, height: 3.5)
        let swatch = try #require(SwatchRenderer.render(pattern: .argyle, palette: palette, stitch: stitch, scale: 2))
        #expect(swatch.size == CGSize(width: 54, height: 56))
        #expect(swatch.image.width == 108)
        #expect(swatch.image.height == 112)
    }

    @Test func swatchTilesSeamlessly() throws {
        // Opposite edges of a repeat should continue each other: compare the first and last
        // pixel columns' average colour distance to that of two adjacent interior columns.
        let swatch = try #require(SwatchRenderer.render(pattern: .stockinette, palette: .undyed,
                                                        stitch: StitchSize(width: 8, height: 6), scale: 2))
        let image = swatch.image
        let ctx = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                         bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        func rowDistance(_ a: Int, _ b: Int) -> Double {
            var total = 0.0
            for x in 0..<image.width {
                for c in 0..<3 { total += abs(Double(data[(a * image.width + x) * 4 + c]) - Double(data[(b * image.width + x) * 4 + c])) }
            }
            return total / Double(image.width)
        }
        let seam = rowDistance(0, image.height - 1)
        let interior = rowDistance(image.height / 2, image.height / 2 + 1)
        #expect(seam < interior * 3 + 10)
        // Fully opaque fabric: no transparent holes in the swatch.
        for i in stride(from: 3, to: image.width * image.height * 4, by: 4) where data[i] != 255 {
            Issue.record("transparent pixel in swatch")
            break
        }
    }
}
