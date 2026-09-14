import KnitCore
import SwiftUI

/// Wraps content in a knitted border with ribbed cuffs at the corners — the Cozy Borders look,
/// knitted in whatever yarn and pattern is currently chosen.
struct KnittedFrame<Content: View>: View {
    let sweater: FolderSweater
    var thickness: CGFloat = 16
    var cornerRadius: CGFloat = 20
    /// How far the knit runs past the view's edges. When the frame fills a window, the window's
    /// own rounded clip then gives the fabric a clean outer edge instead of a painted one.
    var bleed: CGFloat = 0
    @ViewBuilder var content: Content

    @Environment(\.displayScale) private var displayScale

    /// A little chunkier than a window border, so the stitches read at a glance.
    private static var stitch: StitchSize { StitchSize(width: 6, height: 4.7) }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .circular))
            .padding(thickness)
            .background {
                Canvas { context, size in
                    guard let swatches = RenderCache.shared.frameSwatches(for: sweater, stitch: Self.stitch, scale: displayScale) else { return }
                    // No flare: cuffs and bands share one outer edge, so nothing sticks out.
                    let style = BorderStyle(borderWidth: thickness + bleed, cornerRadius: cornerRadius,
                                            holeOverlap: 2, stitch: Self.stitch, flare: 0)
                    let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -bleed, dy: -bleed)
                    context.withCGContext { cg in
                        BorderPainter.paint(in: cg, bounds: bounds, style: style, fabric: swatches.fabric, cuff: swatches.cuff)
                    }
                }
            }
    }
}
