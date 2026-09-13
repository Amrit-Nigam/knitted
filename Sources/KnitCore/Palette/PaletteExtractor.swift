import Foundation

/// Four yarns: three ranked colours drawn from the icon, and a quieter background yarn.
public struct YarnPalette: Equatable, Hashable, Codable, Sendable {
    public var colors: [YarnColor]  // always 4: primary, secondary, accent, background

    public init(colors: [YarnColor]) {
        precondition(colors.count == 4, "a yarn palette has exactly four colours")
        self.colors = colors
    }

    public subscript(index: Int) -> YarnColor { colors[index % colors.count] }

    public var primary: YarnColor { colors[0] }
    public var background: YarnColor { colors[3] }

    /// Cuffs are knitted in the darkest yarn.
    public var darkest: YarnColor { colors.min { $0.luminance < $1.luminance }! }

    /// Oatmeal and charcoal — used when an app has no usable icon.
    public static let undyed = YarnPalette(colors: [
        YarnColor(hex: "#9A968F")!, YarnColor(hex: "#4A4744")!, YarnColor(hex: "#D9D4CA")!, YarnColor(hex: "#7F7B75")!,
    ])
}

public enum PaletteExtractor {
    struct Bucket {
        var pixels: [YarnColor]
        var mean: YarnColor {
            let n = Double(pixels.count)
            let sum = pixels.reduce((0.0, 0.0, 0.0)) { ($0.0 + $1.r, $0.1 + $1.g, $0.2 + $1.b) }
            return YarnColor(r: sum.0 / n, g: sum.1 / n, b: sum.2 / n)
        }
    }

    struct Swatch {
        var color: YarnColor
        var population: Int
    }

    public static func palette(forPID pid: pid_t) -> YarnPalette {
        guard let pixels = IconSampler.pixels(forPID: pid) else { return .undyed }
        return palette(from: pixels)
    }

    public static func palette(from pixels: [SampledPixel]) -> YarnPalette {
        // 3. Drop transparent pixels; drop greys unless the icon is mostly grey.
        let opaque = pixels.filter { $0.alpha >= 0.5 }.map(\.color)
        guard !opaque.isEmpty else { return .undyed }
        // Near-black and near-white pixels are almost always the icon's backdrop (dark
        // squircles, white plates). Leave them out of the vote, or an orange logo on a black
        // tile gets knitted in grey.
        let voters = opaque.filter { $0.lightness > 0.12 && $0.lightness < 0.94 }
        let electorate = voters.isEmpty ? opaque : voters
        let desaturatedCount = electorate.filter { $0.saturation < 0.12 }.count
        // A small but clearly coloured logo (a green leaf on a dark tile) still counts as colour.
        let vividCount = electorate.filter { $0.saturation >= 0.3 }.count
        let monochrome = Double(desaturatedCount) / Double(electorate.count) > 0.7
            && Double(vividCount) / Double(opaque.count) < 0.05
        let working = monochrome ? opaque : opaque.filter { $0.saturation >= 0.12 }
        guard !working.isEmpty else { return .undyed }

        // 4. Median cut to 8 buckets, then merge perceptually identical buckets.
        let buckets = medianCut(working, bucketCount: 8)
        let swatches = merge(buckets.map { Swatch(color: $0.mean, population: $0.pixels.count) }, within: 10)

        // 5. Rank by population × saturation and take the top three.
        let ranked = swatches.sorted { score($0, monochrome: monochrome) > score($1, monochrome: monochrome) }
        var picks = Array(ranked.prefix(3)).map(\.color)
        while picks.count < 3 {
            // Too few distinct colours: knit tonal variations of the lead yarn.
            let base = picks[0]
            picks.append(base.shaded(picks.count == 1 ? -0.35 : 0.35))
        }

        // 6. Adjust for wool, then keep the three yarns distinguishable from each other.
        var yarns = picks.map { dyed($0, monochrome: monochrome) }
        separate(&yarns)

        // 7. Background: the most populous colour, desaturated by 60%.
        let mostPopulous = swatches.max { $0.population < $1.population }!.color
        var bg = dyed(mostPopulous, monochrome: monochrome).hsl
        bg.s *= 0.4
        yarns.append(YarnColor(hsl: bg))

        return YarnPalette(colors: yarns)
    }

    static func score(_ swatch: Swatch, monochrome: Bool) -> Double {
        // In monochrome icons every candidate is grey, so saturation would zero everything out.
        Double(swatch.population) * (monochrome ? 1 : swatch.color.saturation)
    }

    /// Wool is never neon and never pure black.
    static func dyed(_ color: YarnColor, monochrome: Bool) -> YarnColor {
        var c = color.hsl
        c.l = c.l.clamped(0.25, 0.75)
        c.s *= 0.85
        if monochrome || c.s < 0.1 {
            // Undyed wool: only a breath of warmth. Any more and charcoal turns to mud.
            c.h = 0.1
            c.s = min(c.s, 0.05)
        }
        // Dark oranges and yellows turn into mud; lift them into tan / ochre territory.
        let hueDegrees = c.h * 360
        if hueDegrees > 15, hueDegrees < 65, c.l < 0.42 {
            c.l = 0.42
        }
        return YarnColor(hsl: c)
    }

    /// Nudges lightness so no two of the leading yarns are within ΔE 14 of each other,
    /// otherwise two-colour patterns knit up as a single blur.
    static func separate(_ yarns: inout [YarnColor]) {
        for i in 1..<yarns.count {
            for _ in 0..<4 {
                guard let clash = yarns[0..<i].first(where: { $0.deltaE(yarns[i]) < 14 }) else { break }
                var c = yarns[i].hsl
                let goDarker = clash.lightness >= 0.5
                c.l = (c.l + (goDarker ? -0.14 : 0.14)).clamped(0.25, 0.75)
                if abs(c.l - clash.lightness) < 0.05 { c.l = goDarker ? 0.25 : 0.75 }
                yarns[i] = YarnColor(hsl: c)
            }
        }
    }

    // MARK: Median cut

    static func medianCut(_ colors: [YarnColor], bucketCount: Int) -> [Bucket] {
        var buckets = [Bucket(pixels: colors)]
        while buckets.count < bucketCount {
            // Split the bucket with the widest channel range, weighted by how many pixels it holds.
            var bestIndex = -1
            var bestScore = 0.0
            for (i, bucket) in buckets.enumerated() where bucket.pixels.count > 1 {
                let s = range(of: bucket).extent * Double(bucket.pixels.count)
                if s > bestScore { bestScore = s; bestIndex = i }
            }
            guard bestIndex >= 0 else { break }
            let bucket = buckets.remove(at: bestIndex)
            let channel = range(of: bucket).channel
            let sorted = bucket.pixels.sorted { component($0, channel) < component($1, channel) }
            let mid = sorted.count / 2
            buckets.append(Bucket(pixels: Array(sorted[..<mid])))
            buckets.append(Bucket(pixels: Array(sorted[mid...])))
        }
        return buckets
    }

    static func range(of bucket: Bucket) -> (channel: Int, extent: Double) {
        var best = (channel: 0, extent: 0.0)
        for channel in 0..<3 {
            let values = bucket.pixels.map { component($0, channel) }
            let extent = (values.max() ?? 0) - (values.min() ?? 0)
            if extent > best.extent { best = (channel, extent) }
        }
        return best
    }

    static func component(_ c: YarnColor, _ channel: Int) -> Double {
        channel == 0 ? c.r : channel == 1 ? c.g : c.b
    }

    static func merge(_ swatches: [Swatch], within threshold: Double) -> [Swatch] {
        var merged: [Swatch] = []
        for swatch in swatches.sorted(by: { $0.population > $1.population }) {
            if let i = merged.firstIndex(where: { $0.color.deltaE(swatch.color) < threshold }) {
                let total = merged[i].population + swatch.population
                let t = Double(swatch.population) / Double(total)
                merged[i] = Swatch(color: merged[i].color.mixed(with: swatch.color, t), population: total)
            } else {
                merged.append(swatch)
            }
        }
        return merged
    }
}

/// Palettes per bundle identifier. Icons change rarely; invalidate when the app relaunches.
public final class PaletteCache {
    private var palettes: [String: YarnPalette] = [:]

    public init() {}

    public func palette(bundleID: String?, pid: pid_t) -> YarnPalette {
        let key = bundleID ?? "pid:\(pid)"
        if let cached = palettes[key] { return cached }
        let palette = PaletteExtractor.palette(forPID: pid)
        palettes[key] = palette
        return palette
    }

    public func invalidate(bundleID: String?) {
        guard let bundleID else { return }
        palettes[bundleID] = nil
    }

    public func removeAll() { palettes.removeAll() }
}
