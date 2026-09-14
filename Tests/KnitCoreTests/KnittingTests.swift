import CoreGraphics
import Foundation
import Testing
@testable import KnitCore

struct KnittingTests {
    @Test func surprisePatternsAreStableAndVaried() {
        #expect(PatternID.assigned(to: "Work") == PatternID.assigned(to: "Work"))
        let names = ["code", "Work", "screenshots", "Photos", "Taxes", "Music", "Notes", "Projects"]
        #expect(Set(names.map(PatternID.assigned(to:))).count >= 4)
        #expect(!PatternID.surprisePool.contains(.stockinette))
    }

    @Test func everyPatternHasAFamilyAndName() {
        for family in PatternID.Family.allCases {
            #expect(PatternID.allCases.contains { $0.family == family })
        }
        #expect(Set(PatternID.allCases.map(\.displayName)).count == PatternID.allCases.count)
    }

    @Test func classicRepeats() {
        #expect((PatternLibrary.stripes.columns, PatternLibrary.stripes.rows) == (1, 6))
        #expect((PatternLibrary.fairIsle.columns, PatternLibrary.fairIsle.rows) == (8, 8))
        #expect((PatternLibrary.argyle.columns, PatternLibrary.argyle.rows) == (12, 16))
        #expect((PatternLibrary.houndstooth.columns, PatternLibrary.houndstooth.rows) == (4, 4))
        #expect((PatternLibrary.nordicStar.columns, PatternLibrary.nordicStar.rows) == (15, 15))
    }

    @Test func nordicStarIsSymmetric() {
        let star = PatternLibrary.nordicStar
        // Mirror across the star's centre column (7), ignoring the corner accent at (0, 0).
        for row in 1..<star.rows {
            for column in 1..<star.columns - 1 {
                #expect(star[column, row] == star[14 - column, row], "row \(row) column \(column)")
            }
        }
    }

    @Test func colourworkUsesContrastAndTextureDoesNot() {
        for id in PatternID.allCases {
            let pattern = id.pattern
            switch id.family {
            case .colourwork, .geometric:
                #expect(pattern.colorIndices.count >= 2, "\(id) should use at least two yarns")
            case .texture:
                #expect(pattern.colorIndices == [0], "\(id) should be single-yarn")
            }
        }
        #expect(Set(PatternLibrary.cable.cells.map(\.glyph)).count > 1)
        #expect(Set(PatternLibrary.basketweave.cells.map(\.glyph)) == [.knit, .purl])
    }

    @Test func chevronWrapsSeamlessly() {
        // The zigzag must continue across the repeat edge: column 11 sits next to column 0.
        let chevron = PatternLibrary.chevron
        for row in 0..<chevron.rows {
            let edge = abs(chevron[11, row].colorIndex - chevron[12, row].colorIndex)
            let interior = abs(chevron[5, row].colorIndex - chevron[6, row].colorIndex)
            #expect(edge <= 2 && interior <= 2)
        }
    }

    @Test func lookupWraps() {
        let p = PatternLibrary.fairIsle
        #expect(p[-1, -1] == p[7, 7])
        #expect(p[8, 16] == p[0, 0])
    }

    @Test(arguments: PatternID.allCases)
    func everyPatternRendersAWholeRepeat(_ id: PatternID) throws {
        let stitch = StitchSize(width: 4.5, height: 3.5)
        let pattern = id.pattern
        let swatch = try #require(SwatchRenderer.render(pattern: pattern, palette: YarnPreset.all[0].palette, stitch: stitch, scale: 2))
        #expect(swatch.image.width == Int((CGFloat(pattern.columns) * stitch.width * 2).rounded()))
        #expect(swatch.image.height == Int((CGFloat(pattern.rows) * stitch.height * 2).rounded()))
    }

    @Test func swatchTilesSeamlessly() throws {
        // Opposite edges of a repeat should continue each other: compare the first and last
        // pixel rows' average colour distance to that of two adjacent interior rows.
        let swatch = try #require(SwatchRenderer.render(pattern: PatternLibrary.stockinette, palette: .undyed,
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
        #expect(rowDistance(0, image.height - 1) < rowDistance(image.height / 2, image.height / 2 + 1) * 3 + 10)
        // Fully opaque fabric: no transparent holes in the swatch.
        for i in stride(from: 3, to: image.width * image.height * 4, by: 4) where data[i] != 255 {
            Issue.record("transparent pixel in swatch")
            break
        }
    }

    @Test func renderCacheReturnsTheSameImage() throws {
        let cache = RenderCache()
        let sweater = FolderSweater(pattern: .hearts, palette: YarnPreset.all[3].palette)
        let a = try #require(cache.icon(for: sweater, pixelSize: 64))
        let b = try #require(cache.icon(for: sweater, pixelSize: 64))
        #expect(a === b)
    }

    @Test func knittedFramePaintsOnlyTheRing() throws {
        let size = 200
        let ctx = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let sweater = FolderSweater(pattern: .fairIsle, palette: YarnPreset.all[0].palette)
        let swatches = try #require(RenderCache().frameSwatches(for: sweater, stitch: StitchSize(width: 5, height: 4), scale: 1))
        BorderPainter.paint(in: ctx, bounds: CGRect(x: 0, y: 0, width: size, height: size),
                            style: BorderStyle(borderWidth: 16, cornerRadius: 12), fabric: swatches.fabric, cuff: swatches.cuff)
        let data = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: size * size * 4)
        func alpha(_ x: Int, _ y: Int) -> UInt8 { data[(y * size + x) * 4 + 3] }
        #expect(alpha(size / 2, 8) == 255)          // in the band
        #expect(alpha(size / 2, size / 2) == 0)     // the framed content stays clear
    }
}
