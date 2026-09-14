import CoreGraphics
import Foundation
import Testing
@testable import KnitCore

struct FolderIconTests {
    let sweater = FolderSweater(pattern: .fairIsle, palette: YarnPreset.all[0].palette)

    @Test(arguments: [32, 128, 512, 1024])
    func rendersAtSize(_ pixels: Int) throws {
        let image = try #require(FolderIconRenderer.image(for: sweater, pixelSize: pixels))
        #expect(image.width == pixels)
        #expect(image.height == pixels)
    }

    @Test func cornersAreTransparentAndPocketIsOpaque() throws {
        let size = 256
        let image = try #require(FolderIconRenderer.image(for: sweater, pixelSize: size))
        let ctx = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        let data = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: size * size * 4)
        // Memory row 0 is the top of the image.
        func alpha(x: Int, y: Int) -> UInt8 { data[(y * size + x) * 4 + 3] }
        #expect(alpha(x: 2, y: 2) == 0)
        #expect(alpha(x: size - 3, y: size - 3) < 40)  // only the faint drop shadow
        #expect(alpha(x: size / 2, y: size * 3 / 4) == 255)
    }

    @Test func differentSweatersLookDifferent() throws {
        let a = try #require(FolderIconRenderer.image(for: sweater, pixelSize: 64)?.dataProvider?.data as Data?)
        var other = sweater
        other.pattern = .stripes
        let b = try #require(FolderIconRenderer.image(for: other, pixelSize: 64)?.dataProvider?.data as Data?)
        #expect(a != b)
    }

    @Test func presetsAreStableAndDistinct() {
        #expect(YarnPreset.assigned(to: "Work") == YarnPreset.assigned(to: "Work"))
        let names = ["code", "Work", "screenshots", "Photos", "Taxes", "Music", "Notes", "Projects"]
        #expect(Set(names.map { YarnPreset.assigned(to: $0).id }).count >= 3)
        #expect(Set(YarnPreset.all.map(\.id)).count == YarnPreset.all.count)
    }
}
