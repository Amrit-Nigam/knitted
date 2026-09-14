import AppKit
import KnitCore
import SwiftUI
import UniformTypeIdentifiers

enum Cozy {
    static let cream = Color(hex: "#F6F0E4")
    static let paper = Color(hex: "#FFFBF3")
    static let ink = Color(hex: "#4A3B31")
    static let softInk = Color(hex: "#8A7666")
    static let stitch = Color(hex: "#C9B79C")
    static let accent = Color(hex: "#C8603F")
}

struct ContentView: View {
    @EnvironmentObject var studio: KnitStudio
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                dropZone
                    .padding(20)
                Divider().overlay(Cozy.stitch.opacity(0.5))
                ScrollView {
                    controls.padding(20)
                }
                .frame(width: 330)
            }
            if !studio.knitted.isEmpty {
                Divider().overlay(Cozy.stitch.opacity(0.5))
                wardrobe
            }
        }
        .background(Cozy.cream)
        .foregroundStyle(Cozy.ink)
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            studio.refreshWallpaper()
        }
    }

    // MARK: Drop zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(dropTargeted ? Cozy.paper : Cozy.paper.opacity(0.6))
            // A running stitch instead of a plain dashed line.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(dropTargeted ? Cozy.accent : Cozy.stitch,
                              style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 9]))
                .padding(8)

            VStack(spacing: 14) {
                SweaterPreview(sweater: studio.previewSweater)
                    .frame(width: 230, height: 230)
                    .scaleEffect(dropTargeted ? 1.06 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: dropTargeted)
                Text(studio.previewName)
                    .font(.system(size: 15, weight: .semibold))
                VStack(spacing: 4) {
                    Text(dropTargeted ? "Let go to knit" : "Drop folders here")
                        .font(.system(size: 22, weight: .bold))
                    Text("Each one gets a little sweater. You can take it off any time.")
                        .font(.system(size: 13))
                        .foregroundStyle(Cozy.softInk)
                        .multilineTextAlignment(.center)
                }
                Button("Choose Folders…") { studio.chooseFolders() }
                    .buttonStyle(CozyButtonStyle(prominent: true))
                if let message = studio.message {
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Cozy.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Cozy.stitch.opacity(0.35)))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(30)
            .animation(.easeOut(duration: 0.2), value: studio.message)
        }
        .frame(minWidth: 400, minHeight: 500)
        .dropDestination(for: URL.self) { urls, _ in
            studio.knit(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Pattern") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                    ChoiceTile(title: "Surprise", selected: studio.patternChoice == .surprise) {
                        SurpriseBadge()
                    } action: { studio.patternChoice = .surprise }
                    ForEach(PatternID.allCases, id: \.self) { pattern in
                        ChoiceTile(title: pattern.displayName, selected: studio.patternChoice == .pattern(pattern)) {
                            SwatchThumbnail(pattern: pattern, palette: studio.palette(forFolderNamed: studio.previewName))
                        } action: { studio.patternChoice = .pattern(pattern) }
                    }
                }
            }

            section("Yarn") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                    ChoiceTile(title: "Surprise", selected: studio.yarnChoice == .surprise) {
                        SurpriseBadge()
                    } action: { studio.yarnChoice = .surprise }
                    ChoiceTile(title: "Wallpaper", selected: studio.yarnChoice == .wallpaper) {
                        YarnDots(palette: studio.currentWallpaperPalette())
                    } action: { studio.yarnChoice = .wallpaper }
                    ForEach(YarnPreset.all) { preset in
                        ChoiceTile(title: preset.name, selected: studio.yarnChoice == .preset(preset.id)) {
                            YarnDots(palette: preset.palette)
                        } action: { studio.yarnChoice = .preset(preset.id) }
                    }
                    ChoiceTile(title: "Custom", selected: studio.yarnChoice == .custom) {
                        YarnDots(palette: YarnPalette(colors: studio.customColors.map { YarnColor(swiftUI: $0) } + [YarnColor(swiftUI: studio.customColors[0])]))
                    } action: { studio.yarnChoice = .custom }
                }
                if studio.yarnChoice == .custom {
                    HStack(spacing: 14) {
                        ForEach(studio.customColors.indices, id: \.self) { i in
                            ColorPicker(["Main", "Second", "Accent"][i], selection: $studio.customColors[i], supportsOpacity: false)
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.top, 4)
                }
            }

            section("Details") {
                Toggle("Ribbed cuff along the pocket", isOn: $studio.hasCuff)
                    .toggleStyle(.switch)
                    .tint(Cozy.accent)
                    .font(.system(size: 13))
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Cozy.softInk)
            content()
        }
    }

    // MARK: Wardrobe

    private var wardrobe: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WEARING SWEATERS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Cozy.softInk)
                Spacer()
                Button("Re-knit All") { studio.reknitAll() }
                    .buttonStyle(CozyButtonStyle(prominent: false))
                    .help("Apply the current pattern and yarn to every folder below")
                Button("Unknit All") { studio.unknitAll() }
                    .buttonStyle(CozyButtonStyle(prominent: false))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(studio.knitted) { folder in
                        WardrobeItem(folder: folder)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 76)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Cozy.paper.opacity(0.5))
    }
}

// MARK: - Pieces

struct SweaterPreview: View {
    let sweater: FolderSweater

    var body: some View {
        if let image = FolderIconRenderer.image(for: sweater, pixelSize: 512) {
            Image(decorative: image, scale: 2)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        }
    }
}

struct SwatchThumbnail: View {
    let pattern: PatternID
    let palette: YarnPalette

    var body: some View {
        if let swatch = SwatchRenderer.render(pattern: .named(pattern), palette: palette,
                                              stitch: StitchSize(width: 7, height: 5.5), scale: 2) {
            Rectangle()
                .fill(ImagePaint(image: Image(decorative: swatch.image, scale: 2)))
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
            Image(systemName: "dice")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
    }
}

struct ChoiceTile<Preview: View>: View {
    let title: String
    let selected: Bool
    @ViewBuilder let preview: () -> Preview
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .frame(height: 44)
                Text(title)
                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Cozy.paper : Cozy.paper.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Cozy.accent : Cozy.stitch.opacity(0.5), lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WardrobeItem: View {
    @EnvironmentObject var studio: KnitStudio
    let folder: KnittedFolder
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                    .resizable()
                    .frame(width: 52, height: 52)
                if hovering {
                    Button {
                        studio.unknit(folder)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Cozy.ink, Cozy.paper)
                    }
                    .buttonStyle(.plain)
                    .help("Take the sweater off")
                    .offset(x: 6, y: -4)
                }
            }
            Text(folder.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: 76)
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.activateFileViewerSelecting([folder.url])
        }
        .help("\(folder.path)\nDouble-click to show in Finder")
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder.url]) }
            Button("Re-knit") { studio.knit([folder.url]) }
            Button("Take Sweater Off") { studio.unknit(folder) }
        }
    }
}

struct CozyButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(prominent ? Color.white : Cozy.ink)
            .background(
                Capsule().fill(prominent ? Cozy.accent : Cozy.stitch.opacity(0.35))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
