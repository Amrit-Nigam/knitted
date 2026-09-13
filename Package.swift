// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CozyBorders",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CozyBorders", targets: ["CozyBorders"]),
        .executable(name: "knit-preview", targets: ["knit-preview"]),
    ],
    targets: [
        // Pure, testable pieces: coordinate maths, filtering, knitting, palettes.
        .target(name: "KnitCore"),
        // The menu bar agent: tracking, border windows, stacking, preferences.
        .executableTarget(name: "CozyBorders", dependencies: ["KnitCore"]),
        // Renders swatches, a mock bordered window and icon palettes to PNG for eyeballing.
        .executableTarget(name: "knit-preview", dependencies: ["KnitCore"]),
        .testTarget(name: "KnitCoreTests", dependencies: ["KnitCore"]),
    ]
)
