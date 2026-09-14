import AppKit
import CoreGraphics
import Foundation
import KnitCore
import UniformTypeIdentifiers

// Renders knitted folder icons to PNGs so the knit can be judged by eye.
//
//   swift run knit-preview <output-dir>
//   swift run knit-preview iconset <AppIcon.iconset>   (used by scripts/build-app.sh)

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "iconset" {
    let dir = URL(fileURLWithPath: CommandLine.arguments[2])
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let sweater = FolderSweater(pattern: .fairIsle, palette: YarnPreset.named("finder")!.palette)
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let image = FolderIconRenderer.image(for: sweater, pixelSize: points * scale)!
            let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
    }
    exit(0)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "preview")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func makeContext(width: Int, height: Int, background: CGColor) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return ctx
}

func save(_ image: CGImage, _ name: String) {
    let url = outputDir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

/// Draws a label centred under a point, in a bottom-left-origin context.
func label(_ text: String, centeredAt point: CGPoint, in ctx: CGContext, size: CGFloat, color: NSColor) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.5)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: color, .shadow: shadow,
    ])
    let line = CTLineCreateWithAttributedString(string)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: point.x - width / 2, y: point.y)
    CTLineDraw(line, ctx)
}

let sheet = makeContext(width: 256 * PatternID.allCases.count, height: 256 * 4, background: YarnColor(hex: "#F4EEE2")!.cgColor)
let presets = ["finder", "forest", "berry", "charcoal"].compactMap(YarnPreset.named)
for (row, preset) in presets.enumerated() {
    for (column, pattern) in PatternID.allCases.enumerated() {
        let icon = FolderIconRenderer.image(for: FolderSweater(pattern: pattern, palette: preset.palette), pixelSize: 256)!
        sheet.draw(icon, in: CGRect(x: column * 256, y: (3 - row) * 256, width: 256, height: 256))
    }
}
save(sheet.makeImage()!, "folders-sheet.png")

save(FolderIconRenderer.image(for: FolderSweater(pattern: .fairIsle, palette: YarnPreset.named("finder")!.palette), pixelSize: 1024)!, "folder-1024.png")

// A desktop column like the reference: 64pt icons at 2x on a teal wallpaper, with labels.
let desktop = makeContext(width: 600, height: 900, background: YarnColor(hex: "#5E8C9C")!.cgColor)
let names = ["code", "Work", "screenshots"]
let sweaters = [
    FolderSweater(pattern: .cable, palette: YarnPreset.named("oatmeal")!.palette),
    FolderSweater(pattern: .fairIsle, palette: YarnPreset.named("finder")!.palette),
    FolderSweater(pattern: .stripes, palette: YarnPreset.named("berry")!.palette),
]
for (i, sweater) in sweaters.enumerated() {
    let y = 900 - 60 - i * 280 - 128
    let icon = FolderIconRenderer.image(for: sweater, pixelSize: 128)!
    desktop.draw(icon, in: CGRect(x: 90, y: y, width: 128, height: 128))
    label(names[i], centeredAt: CGPoint(x: 154, y: y - 40), in: desktop, size: 26, color: .white)
    let big = FolderIconRenderer.image(for: sweater, pixelSize: 256)!
    desktop.draw(big, in: CGRect(x: 300, y: y - 60, width: 256, height: 256))
}
save(desktop.makeImage()!, "desktop.png")
