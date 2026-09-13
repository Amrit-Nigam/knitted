import AppKit
import CoreGraphics

/// One sampled pixel, un-premultiplied, components in 0...1.
public struct SampledPixel: Equatable, Sendable {
    public var color: YarnColor
    public var alpha: Double
}

/// Turns an app icon into a small grid of raw pixels. Sampling icons needs no permission.
public enum IconSampler {
    public static let sampleSize = 32

    public static func pixels(forPID pid: pid_t) -> [SampledPixel]? {
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return nil }
        return pixels(for: icon)
    }

    public static func pixels(for image: NSImage) -> [SampledPixel]? {
        var rect = CGRect(x: 0, y: 0, width: 256, height: 256)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        return pixels(for: cg)
    }

    /// Draws the image into a 32×32 sRGB premultiplied context. Downsampling this hard is
    /// deliberate: it averages away gradients and antialiasing.
    public static func pixels(for image: CGImage) -> [SampledPixel]? {
        let size = sampleSize
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = ctx.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: size * size * 4)

        var result: [SampledPixel] = []
        result.reserveCapacity(size * size)
        for i in 0..<(size * size) {
            let a = Double(bytes[i * 4 + 3]) / 255
            guard a > 0 else {
                result.append(SampledPixel(color: YarnColor(r: 0, g: 0, b: 0), alpha: 0))
                continue
            }
            let color = YarnColor(r: Double(bytes[i * 4]) / 255 / a,
                                  g: Double(bytes[i * 4 + 1]) / 255 / a,
                                  b: Double(bytes[i * 4 + 2]) / 255 / a)
            result.append(SampledPixel(color: color, alpha: a))
        }
        return result
    }
}
