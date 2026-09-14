import KnitCore
import SwiftUI

/// Warm paper, brown ink, terracotta accent.
enum Cozy {
    static let cream = Color(hex: "#EFE6D6")
    static let paper = Color(hex: "#FBF7EF")
    static let card = Color(hex: "#FFFDF8")
    static let ink = Color(hex: "#4A3B31")
    static let softInk = Color(hex: "#8A7666")
    static let stitch = Color(hex: "#C9B79C")
    static let accent = Color(hex: "#C8603F")
    static let warning = Color(hex: "#B7791F")
}

extension Color {
    init(hex: String) {
        self.init(yarn: YarnColor(hex: hex) ?? YarnColor(r: 0.5, g: 0.5, b: 0.5))
    }

    init(yarn: YarnColor) {
        self.init(.sRGB, red: yarn.r, green: yarn.g, blue: yarn.b)
    }
}

extension YarnColor {
    init(swiftUI color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        self.init(r: ns.redComponent, g: ns.greenComponent, b: ns.blueComponent)
    }
}

struct CozyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .secondary
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: kind == .primary ? 14 : 12, weight: .semibold))
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, kind == .primary ? 18 : 12)
            .padding(.vertical, kind == .primary ? 10 : 6)
            .foregroundStyle(kind == .primary ? Color.white : Cozy.ink)
            .background(
                Capsule().fill(kind == .primary ? Cozy.accent : Cozy.stitch.opacity(0.32))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A dashed "running stitch" line, horizontal or vertical.
struct StitchedDivider: View {
    var vertical = false

    var body: some View {
        GeometryReader { geo in
            Path { p in
                if vertical {
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                } else {
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
            }
            .stroke(Cozy.stitch, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6]))
        }
        .frame(width: vertical ? 2 : nil, height: vertical ? nil : 2)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Cozy.softInk)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Cozy.softInk.opacity(0.8))
            }
        }
    }
}
