import AppKit
import CoreGraphics
import Foundation
import KnitCore
import UniformTypeIdentifiers

// Renders the knitting to PNGs so it can be judged by eye (M5/M6 acceptance is a taste call).
//
//   swift run knit-preview <output-dir> [app paths...]

let args = CommandLine.arguments
let outputDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "preview")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let scale: CGFloat = 2

func makeContext(width: CGFloat, height: CGFloat, background: CGColor) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: height * scale)
    ctx.scaleBy(x: scale, y: -scale)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return ctx
}

func save(_ ctx: CGContext, _ name: String) {
    let url = outputDir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

/// Draws text in a y-down context.
func label(_ text: String, at point: CGPoint, in ctx: CGContext, size: CGFloat = 12) {
    let attributed = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .medium),
        .foregroundColor: NSColor(white: 0.2, alpha: 1),
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.textPosition = CGPoint(x: point.x, y: point.y + size)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

let desk = YarnColor(hex: "#FBEFD2")!.cgColor

let samplePalettes: [(String, YarnPalette)] = [
    ("green", YarnPalette(colors: ["#4F7A4A", "#B9C47A", "#2F4B3A", "#A5AD98"].map { YarnColor(hex: $0)! })),
    ("blue-pink", YarnPalette(colors: ["#3F6FC4", "#D98AA0", "#E8D6B0", "#9FA9C0"].map { YarnColor(hex: $0)! })),
    ("mono", YarnPalette(colors: ["#3A3633", "#E9E2D4", "#8A8177", "#BDB5A8"].map { YarnColor(hex: $0)! })),
]

let style = BorderStyle(holeOverlap: 0)

// 1. Swatches: every pattern × sample palettes, tiled over a patch big enough to show repeats.
do {
    let patch = CGSize(width: 150, height: 110)
    let columns = PatternID.allCases.count
    let ctx = makeContext(width: CGFloat(columns) * (patch.width + 20) + 20,
                          height: CGFloat(samplePalettes.count) * (patch.height + 40) + 20, background: desk)
    for (row, (name, palette)) in samplePalettes.enumerated() {
        for (column, id) in PatternID.allCases.enumerated() {
            let origin = CGPoint(x: 20 + CGFloat(column) * (patch.width + 20), y: 20 + CGFloat(row) * (patch.height + 40))
            label("\(id.displayName) · \(name)", at: origin, in: ctx, size: 11)
            let swatch = SwatchRenderer.render(pattern: .named(id), palette: palette, stitch: style.stitch, scale: scale)!
            ctx.saveGState()
            ctx.clip(to: CGRect(origin: CGPoint(x: origin.x, y: origin.y + 18), size: patch))
            ctx.translateBy(x: origin.x, y: origin.y + 18)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(swatch.image, in: CGRect(x: 0, y: -swatch.size.height, width: swatch.size.width, height: swatch.size.height), byTiling: true)
            ctx.restoreGState()
        }
    }
    save(ctx, "swatches.png")
}

// 2. Close-up of a single swatch at 6× so stitch construction is visible.
do {
    let zoom: CGFloat = 6
    let swatch = SwatchRenderer.render(pattern: .stripes, palette: samplePalettes[0].1, stitch: style.stitch, scale: scale * zoom)!
    let ctx = makeContext(width: 60 * zoom, height: 42 * zoom, background: desk)
    ctx.saveGState()
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(swatch.image, in: CGRect(x: 0, y: -swatch.size.height * zoom, width: swatch.size.width * zoom, height: swatch.size.height * zoom), byTiling: true)
    ctx.restoreGState()
    save(ctx, "stitch-closeup.png")
}

// 3. Mock desktop: bordered windows in different patterns, like the reference screenshot.
func drawMockWindow(_ ctx: CGContext, frame: CGRect, pattern: PatternID, palette: YarnPalette, dark: Bool = false) {
    let bounds = frame.insetBy(dx: -style.borderWidth, dy: -style.borderWidth)
    let fabric = SwatchRenderer.render(pattern: .named(pattern), palette: palette, stitch: style.stitch, scale: scale)!
    let cuff = CuffRenderer.ribbingSwatch(palette: palette, stitch: style.stitch, scale: scale)!
    BorderPainter.paint(in: ctx, bounds: bounds, style: style, fabric: fabric, cuff: cuff)

    let window = CGPath(roundedRect: frame, cornerWidth: style.windowCornerRadius, cornerHeight: style.windowCornerRadius, transform: nil)
    ctx.addPath(window)
    ctx.setFillColor(dark ? CGColor(gray: 0.08, alpha: 1) : CGColor(gray: 0.99, alpha: 1))
    ctx.fillPath()
    for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: frame.minX + 14 + CGFloat(i) * 20, y: frame.minY + 14, width: 12, height: 12))
    }
    label(pattern.displayName, at: CGPoint(x: frame.minX + 18, y: frame.minY + 44), in: ctx, size: 22)
}

do {
    let ctx = makeContext(width: 1000, height: 700, background: desk)
    drawMockWindow(ctx, frame: CGRect(x: 40, y: 40, width: 420, height: 280), pattern: .fairIsle, palette: samplePalettes[0].1)
    drawMockWindow(ctx, frame: CGRect(x: 520, y: 40, width: 440, height: 250), pattern: .argyle, palette: samplePalettes[1].1, dark: true)
    drawMockWindow(ctx, frame: CGRect(x: 40, y: 380, width: 280, height: 280), pattern: .cable, palette: samplePalettes[1].1)
    drawMockWindow(ctx, frame: CGRect(x: 370, y: 380, width: 280, height: 280), pattern: .stripes, palette: samplePalettes[2].1)
    drawMockWindow(ctx, frame: CGRect(x: 700, y: 360, width: 260, height: 300), pattern: .seed, palette: samplePalettes[0].1)
    save(ctx, "desktop.png")

    // Corner close-up at 4×.
    let zoomed = makeContext(width: 640, height: 480, background: desk)
    zoomed.scaleBy(x: 4, y: 4)
    drawMockWindow(zoomed, frame: CGRect(x: 30, y: 30, width: 300, height: 200), pattern: .fairIsle, palette: samplePalettes[0].1)
    save(zoomed, "corner-closeup.png")
}

// 4. Palettes from real app icons.
do {
    var apps = Array(args.dropFirst(2))
    if apps.isEmpty {
        let found = (try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []
        let system = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Applications")) ?? []
        apps = (found.map { "/Applications/\($0)" } + system.map { "/System/Applications/\($0)" })
            .filter { $0.hasSuffix(".app") }
            .sorted()
    }
    apps = Array(apps.prefix(24))
    let rowHeight: CGFloat = 76
    let ctx = makeContext(width: 820, height: CGFloat(apps.count) * rowHeight + 20, background: desk)
    for (i, path) in apps.enumerated() {
        let y = 10 + CGFloat(i) * rowHeight
        let icon = NSWorkspace.shared.icon(forFile: path)
        var rect = CGRect(x: 0, y: 0, width: 256, height: 256)
        guard let cg = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let pixels = IconSampler.pixels(for: cg) else { continue }
        let palette = PaletteExtractor.palette(from: pixels)

        ctx.saveGState()
        ctx.translateBy(x: 10, y: y + 64)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        ctx.restoreGState()

        for (j, color) in palette.colors.enumerated() {
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: 90 + CGFloat(j) * 46, y: y + 8, width: 40, height: 40))
        }
        let pattern = PatternID.assigned(toBundleID: Bundle(path: path)?.bundleIdentifier ?? path)
        let swatch = SwatchRenderer.render(pattern: .named(pattern), palette: palette, stitch: style.stitch, scale: scale)!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 290, y: y + 8, width: 300, height: 56))
        ctx.translateBy(x: 290, y: y + 8)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(swatch.image, in: CGRect(x: 0, y: -swatch.size.height, width: swatch.size.width, height: swatch.size.height), byTiling: true)
        ctx.restoreGState()
        label(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, at: CGPoint(x: 605, y: y + 18), in: ctx, size: 13)
        label(pattern.displayName, at: CGPoint(x: 605, y: y + 38), in: ctx, size: 11)
    }
    save(ctx, "palettes.png")
}
