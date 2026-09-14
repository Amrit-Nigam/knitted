import AppKit
import CryptoKit
import Foundation
import KnitCore
@testable import Knitted

/// A throwaway directory for one test, removed when the value goes away.
final class Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KnittedTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func folder(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("hello".utf8).write(to: url)
        return url
    }

    /// A directory macOS treats as a single file (an app bundle).
    func package(_ name: String) throws -> URL {
        let url = try folder("\(name).app")
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        return url
    }
}

/// Passes icon writes through to NSWorkspace and remembers what was asked for.
final class RecordingIconWriter: IconWriting {
    enum Kind: Equatable { case set, clear }
    struct Call { let kind: Kind; let at: ContinuousClock.Instant }
    var calls: [Call] = []
    var kinds: [Kind] { calls.map(\.kind) }
    private let real = WorkspaceIconWriter()

    func setIcon(_ image: NSImage?, forFile path: String) -> Bool {
        calls.append(Call(kind: image == nil ? .clear : .set, at: .now))
        return real.setIcon(image, forFile: path)
    }
}

extension FolderKnitter {
    /// The real knitter with a short rest, so the suite stays quick.
    static var forTests: FolderKnitter { FolderKnitter(settleDelay: .milliseconds(20)) }
}

enum IconInspector {
    /// The Finder "has custom icon" flag, from the folder's FinderInfo.
    static func hasCustomIconFlag(_ url: URL) -> Bool {
        let size = getxattr(url.path, "com.apple.FinderInfo", nil, 0, 0, 0)
        guard size >= 10 else { return false }
        var bytes = [UInt8](repeating: 0, count: size)
        getxattr(url.path, "com.apple.FinderInfo", &bytes, size, 0, 0)
        // Finder flags are big-endian at offset 8; kHasCustomIcon is 0x0400.
        return bytes[8] & 0x04 != 0
    }

    /// A fingerprint of the bytes stored in the folder's hidden Icon file, or nil if none.
    /// Encoding isn't deterministic, so equal sweaters can differ here; use it only to show change.
    static func storedIconDigest(_ url: URL) -> String? {
        storedIconData(url).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    }

    /// The `icns` image inside the folder's hidden Icon file.
    static func storedIcon(_ url: URL) -> NSImage? {
        guard let fork = storedIconData(url) else { return nil }
        // The resource fork wraps one 'icns' resource: magic, big-endian length, then the image.
        let magic = Data("icns".utf8)
        guard let start = fork.range(of: magic)?.lowerBound, fork.count >= start + 8 else { return nil }
        let length = fork[start + 4..<start + 8].reduce(0) { $0 << 8 | Int($1) }
        guard fork.count >= start + length else { return nil }
        return NSImage(data: fork.subdata(in: start..<start + length))
    }

    /// Average colour of an image drawn at 64×64, as (r, g, b) in 0...1 over opaque pixels.
    static func averageColor(_ image: NSImage) -> (r: Double, g: Double, b: Double) {
        let size = 64
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        var total = (r: 0.0, g: 0.0, b: 0.0), count = 0.0
        for y in 0..<size {
            for x in 0..<size {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.9 else { continue }
                total.r += c.redComponent; total.g += c.greenComponent; total.b += c.blueComponent
                count += 1
            }
        }
        return count > 0 ? (total.r / count, total.g / count, total.b / count) : (0, 0, 0)
    }

    static func distance(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        ((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)).squareRoot()
    }

    /// How far the folder's stored icon is from what `sweater` renders to.
    static func colorDistance(of url: URL, to sweater: FolderSweater) -> Double? {
        guard let stored = storedIcon(url) else { return nil }
        return distance(averageColor(stored), averageColor(FolderIconRenderer.icon(for: sweater)))
    }

    private static func storedIconData(_ url: URL) -> Data? {
        let fork = FolderKnitter.iconFile(in: url).appendingPathComponent("..namedfork/rsrc")
        guard let data = try? Data(contentsOf: fork), !data.isEmpty else { return nil }
        return data
    }
}

extension FolderSweater {
    static let blueFairIsle = FolderSweater(pattern: .fairIsle, palette: YarnPreset.named("finder")!.palette)
    static let mintChevron = FolderSweater(pattern: .chevron, palette: YarnPreset.named("mint")!.palette)
}

/// UserDefaults that don't touch the real app's settings.
func isolatedDefaults() -> UserDefaults {
    let name = "KnittedTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
