import CoreGraphics
import Foundation

/// The ribbed corners that turn "textured border" into "little sweater".
///
/// Each corner gets a cuff of 1×1 ribbing in the palette's darkest yarn. The cuff spans the
/// mitred corner square and runs a short way along both adjacent edges; within each edge the
/// ribs run perpendicular to that edge, so the two halves meet at the mitre like a knitted
/// picture frame. Cuffs sit at the full border width while the band between them is pulled
/// in slightly, which gives the gentle flare of a sweater cuff.
public enum CuffRenderer {
    public static func ribbingSwatch(palette: YarnPalette, stitch: StitchSize, scale: CGFloat) -> Swatch? {
        let yarn = palette.darkest
        let ribbingPalette = YarnPalette(colors: [yarn, yarn, yarn, yarn])
        return SwatchRenderer.render(pattern: PatternLibrary.ribbing, palette: ribbingPalette, stitch: stitch, scale: scale)
    }

    /// How far a cuff extends along an edge past the corner square: about three rows' depth
    /// of ribbing, measured in the direction the ribs travel.
    public static func cuffExtension(stitch: StitchSize, rows: Int) -> CGFloat {
        CGFloat(rows) * stitch.height * 1.5
    }

    /// The union of all four corner zones, in the border's y-down coordinates.
    /// `depth` is the band's full thickness (border width plus any overlap under the content).
    public static func cuffZones(in bounds: CGRect, depth: CGFloat, extension ext: CGFloat) -> CGPath {
        let length = depth + ext
        var rects: [CGRect] = []
        let corners = [
            (bounds.minX, bounds.minY, 1.0, 1.0),
            (bounds.maxX, bounds.minY, -1.0, 1.0),
            (bounds.minX, bounds.maxY, 1.0, -1.0),
            (bounds.maxX, bounds.maxY, -1.0, -1.0),
        ]
        for (x, y, sx, sy) in corners {
            // One strip along the horizontal edge, one along the vertical edge.
            rects.append(CGRect(x: x, y: y, width: sx * length, height: sy * depth).standardized)
            rects.append(CGRect(x: x, y: y, width: sx * depth, height: sy * length).standardized)
        }
        var zones = CGPath(rect: rects[0], transform: nil)
        for rect in rects.dropFirst() {
            zones = zones.union(CGPath(rect: rect, transform: nil))
        }
        return zones
    }
}
