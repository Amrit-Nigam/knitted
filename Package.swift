// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Knitted",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Knitted", targets: ["Knitted"]),
        .executable(name: "knit-preview", targets: ["knit-preview"]),
    ],
    targets: [
        // The knitting: stitches, patterns, swatches, yarn palettes and the folder icon.
        .target(name: "KnitCore"),
        // The app: drop folders on it and they get knitted icons.
        .executableTarget(name: "Knitted", dependencies: ["KnitCore"]),
        // Renders folder icons to PNG for judging the knit by eye.
        .executableTarget(name: "knit-preview", dependencies: ["KnitCore"]),
        .testTarget(name: "KnitCoreTests", dependencies: ["KnitCore"]),
    ]
)
