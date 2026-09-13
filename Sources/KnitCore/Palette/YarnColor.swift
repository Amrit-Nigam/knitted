import CoreGraphics
import Foundation

/// An sRGB colour with components in 0...1, plus the colour-space maths palette work needs.
public struct YarnColor: Equatable, Hashable, Codable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r.clamped(0, 1)
        self.g = g.clamped(0, 1)
        self.b = b.clamped(0, 1)
    }

    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(r: Double((value >> 16) & 0xFF) / 255,
                  g: Double((value >> 8) & 0xFF) / 255,
                  b: Double(value & 0xFF) / 255)
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    public func cgColor(alpha: Double) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    // MARK: HSL

    public struct HSL: Equatable {
        public var h: Double  // 0..<1
        public var s: Double
        public var l: Double
    }

    public var hsl: HSL {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let l = (maxC + minC) / 2
        let d = maxC - minC
        guard d > 1e-9 else { return HSL(h: 0, s: 0, l: l) }
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        var h: Double
        switch maxC {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h /= 6
        return HSL(h: h, s: s, l: l)
    }

    public init(hsl: HSL) {
        let h = hsl.h - floor(hsl.h), s = hsl.s.clamped(0, 1), l = hsl.l.clamped(0, 1)
        guard s > 1e-9 else { self.init(r: l, g: l, b: l); return }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        self.init(r: channel(h + 1.0 / 3), g: channel(h), b: channel(h - 1.0 / 3))
    }

    /// HSL saturation — what the spec's thresholds (0.12 etc.) are expressed in.
    public var saturation: Double { hsl.s }
    public var lightness: Double { hsl.l }

    /// Relative luminance (WCAG), for picking the darkest yarn.
    public var luminance: Double {
        0.2126 * Self.linear(r) + 0.7152 * Self.linear(g) + 0.0722 * Self.linear(b)
    }

    // MARK: Lab

    public struct Lab: Equatable {
        public var l: Double
        public var a: Double
        public var b: Double
    }

    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    public var lab: Lab {
        let lr = Self.linear(r), lg = Self.linear(g), lb = Self.linear(b)
        // sRGB -> XYZ (D65), normalised by the D65 white point.
        let x = (0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb) / 0.95047
        let y = (0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb) / 1.0
        let z = (0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb) / 1.08883
        func f(_ t: Double) -> Double {
            t > 216.0 / 24389 ? cbrt(t) : (24389.0 / 27 * t + 16) / 116
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    /// CIE76 ΔE — plenty for "are these two yarns the same colour".
    public func deltaE(_ other: YarnColor) -> Double {
        let p = lab, q = other.lab
        return sqrt((p.l - q.l) * (p.l - q.l) + (p.a - q.a) * (p.a - q.a) + (p.b - q.b) * (p.b - q.b))
    }

    // MARK: Adjustments

    /// Scales brightness towards black (negative) or white (positive) in HSL lightness.
    public func shaded(_ amount: Double) -> YarnColor {
        var c = hsl
        c.l = amount >= 0 ? c.l + (1 - c.l) * amount : c.l * (1 + amount)
        return YarnColor(hsl: c)
    }

    public func mixed(with other: YarnColor, _ t: Double) -> YarnColor {
        YarnColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}
