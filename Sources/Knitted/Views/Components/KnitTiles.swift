import AppKit
import KnitCore
import SwiftUI

/// A rendered knitted folder icon.
struct SweaterImage: View {
    let sweater: FolderSweater
    var pixelSize = 256

    var body: some View {
        if let image = RenderCache.shared.icon(for: sweater, pixelSize: pixelSize) {
            Image(decorative: image, scale: 2)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        }
    }
}

/// A tiled patch of fabric, with stitches small enough to show a whole motif.
struct SwatchThumbnail: View {
    let pattern: PatternID
    let palette: YarnPalette

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if let swatch = RenderCache.shared.swatch(pattern.pattern, palette: palette,
                                                  stitch: StitchSize(width: 3.6, height: 2.8), scale: displayScale) {
            Rectangle()
                .fill(ImagePaint(image: Image(decorative: swatch.image, scale: displayScale)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct YarnDots: View {
    let palette: YarnPalette

    var body: some View {
        HStack(spacing: -8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(yarn: palette.colors[i]))
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SurpriseBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#F4CB86"), Color(hex: "#EBB2C2"), Color(hex: "#A6CBE6")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
    }
}

/// A selectable tile: preview on top, label below.
struct ChoiceTile<Preview: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .frame(height: 42)
                Text(title)
                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Theme.card : Theme.card.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Theme.stitch.opacity(0.5), lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.kind == .done ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(toast.kind == .done ? Theme.accent : Theme.warning)
            Text(toast.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Theme.card).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
        .overlay(Capsule().strokeBorder(Theme.stitch.opacity(0.6), lineWidth: 1))
    }
}
