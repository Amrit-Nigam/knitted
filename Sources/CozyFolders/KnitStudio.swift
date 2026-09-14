import AppKit
import KnitCore
import SwiftUI

enum PatternChoice: Hashable {
    /// Each folder gets its own pattern, picked from its name.
    case surprise
    case pattern(PatternID)
}

enum YarnChoice: Hashable {
    /// Each folder gets its own palette, picked from its name.
    case surprise
    case preset(String)
    /// Colours sampled from the current desktop picture.
    case wallpaper
    case custom
}

struct KnittedFolder: Codable, Identifiable, Hashable {
    var path: String
    var date: Date
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

/// The app's state: what the next sweater looks like, and which folders are wearing one.
@MainActor
final class KnitStudio: ObservableObject {
    @Published var patternChoice: PatternChoice = .pattern(.fairIsle) { didSet { savePreferences() } }
    @Published var yarnChoice: YarnChoice = .preset("finder") { didSet { savePreferences() } }
    @Published var hasCuff = true { didSet { savePreferences() } }
    @Published var customColors: [Color] = [Color(hex: "#C8423F"), Color(hex: "#FAF4EA"), Color(hex: "#6E9E78")] {
        didSet { savePreferences() }
    }
    @Published private(set) var knitted: [KnittedFolder] = []
    @Published var message: String?
    /// Name shown under the preview; the last folder dropped, so the preview matches it.
    @Published private(set) var previewName = "Work"

    private let defaults = UserDefaults.standard
    private var messageTask: Task<Void, Never>?
    private var wallpaperPalette: YarnPalette?

    init() {
        loadPreferences()
        if let data = defaults.data(forKey: "knitted"), let saved = try? JSONDecoder().decode([KnittedFolder].self, from: data) {
            // Drop folders that have since been deleted or moved.
            knitted = saved.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    // MARK: Sweaters

    func sweater(forFolderNamed name: String) -> FolderSweater {
        let pattern: PatternID
        switch patternChoice {
        case .surprise: pattern = PatternID.assigned(toBundleID: name)
        case .pattern(let chosen): pattern = chosen
        }
        return FolderSweater(pattern: pattern, palette: palette(forFolderNamed: name), hasCuff: hasCuff)
    }

    func palette(forFolderNamed name: String) -> YarnPalette {
        switch yarnChoice {
        case .surprise:
            return YarnPreset.assigned(to: name).palette
        case .preset(let id):
            return YarnPreset.named(id)?.palette ?? YarnPreset.all[0].palette
        case .wallpaper:
            return currentWallpaperPalette()
        case .custom:
            let yarns = customColors.map { YarnColor(swiftUI: $0) }
            var background = yarns[0].hsl
            background.s *= 0.4
            return YarnPalette(colors: yarns + [YarnColor(hsl: background)])
        }
    }

    var previewSweater: FolderSweater { sweater(forFolderNamed: previewName) }

    func currentWallpaperPalette() -> YarnPalette {
        if let wallpaperPalette { return wallpaperPalette }
        let palette = NSScreen.main
            .flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
            .flatMap { PaletteExtractor.palette(fromImageAt: $0) } ?? .undyed
        wallpaperPalette = palette
        return palette
    }

    /// The desktop picture may have changed since we last looked.
    func refreshWallpaper() {
        wallpaperPalette = nil
        if yarnChoice == .wallpaper { objectWillChange.send() }
    }

    // MARK: Knitting

    func knit(_ urls: [URL]) {
        var done: [URL] = []
        var skipped = 0
        var failed: [String] = []
        for url in urls {
            switch FolderKnitter.knit(url, with: sweater(forFolderNamed: url.lastPathComponent)) {
            case .knitted: done.append(url)
            case .notAFolder: skipped += 1
            case .failed: failed.append(url.lastPathComponent)
            }
        }

        for url in done {
            knitted.removeAll { $0.path == url.path }
            knitted.insert(KnittedFolder(path: url.path, date: Date()), at: 0)
        }
        if let last = done.last { previewName = last.lastPathComponent }
        saveHistory()

        var parts: [String] = []
        if done.count == 1 {
            parts.append("Knitted a sweater for \(done[0].lastPathComponent)")
        } else if done.count > 1 {
            parts.append("Knitted \(done.count) sweaters")
        }
        if skipped > 0 { parts.append(skipped == 1 ? "only folders can wear sweaters" : "skipped \(skipped) non-folders") }
        if !failed.isEmpty { parts.append("couldn't change \(failed.joined(separator: ", ")) — check Cozy Folders can access it") }
        if done.contains(where: FolderKnitter.isGitRepository) {
            parts.append("git will see a hidden “Icon” file; add Icon? to .gitignore")
        }
        show(parts.joined(separator: " · "))
    }

    /// Re-knits every folder currently wearing a sweater with the current settings.
    func reknitAll() {
        knit(knitted.map(\.url))
    }

    func unknit(_ folder: KnittedFolder) {
        FolderKnitter.unknit(folder.url)
        knitted.removeAll { $0.path == folder.path }
        saveHistory()
        show("\(folder.name) is back to its usual self")
    }

    func unknitAll() {
        let count = knitted.count
        for folder in knitted { FolderKnitter.unknit(folder.url) }
        knitted.removeAll()
        saveHistory()
        show(count == 1 ? "Unknitted 1 folder" : "Unknitted \(count) folders")
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Knit"
        panel.message = "Choose folders to knit sweaters for"
        if panel.runModal() == .OK {
            knit(panel.urls)
        }
    }

    private func show(_ text: String) {
        guard !text.isEmpty else { return }
        message = text
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }

    // MARK: Persistence

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(knitted) { defaults.set(data, forKey: "knitted") }
    }

    private var loading = false

    private func savePreferences() {
        guard !loading else { return }
        let pattern: String
        switch patternChoice {
        case .surprise: pattern = "surprise"
        case .pattern(let id): pattern = id.rawValue
        }
        let yarn: String
        switch yarnChoice {
        case .surprise: yarn = "surprise"
        case .preset(let id): yarn = "preset:\(id)"
        case .wallpaper: yarn = "wallpaper"
        case .custom: yarn = "custom"
        }
        defaults.set(pattern, forKey: "pattern")
        defaults.set(yarn, forKey: "yarn")
        defaults.set(hasCuff, forKey: "hasCuff")
        defaults.set(customColors.map { YarnColor(swiftUI: $0).hex }, forKey: "customColors")
    }

    private func loadPreferences() {
        loading = true
        defer { loading = false }
        if let pattern = defaults.string(forKey: "pattern") {
            patternChoice = pattern == "surprise" ? .surprise : PatternID(rawValue: pattern).map(PatternChoice.pattern) ?? patternChoice
        }
        if let yarn = defaults.string(forKey: "yarn") {
            if yarn == "surprise" { yarnChoice = .surprise }
            else if yarn == "wallpaper" { yarnChoice = .wallpaper }
            else if yarn == "custom" { yarnChoice = .custom }
            else if yarn.hasPrefix("preset:"), YarnPreset.named(String(yarn.dropFirst(7))) != nil {
                yarnChoice = .preset(String(yarn.dropFirst(7)))
            }
        }
        if defaults.object(forKey: "hasCuff") != nil { hasCuff = defaults.bool(forKey: "hasCuff") }
        if let hexes = defaults.stringArray(forKey: "customColors"), hexes.count == 3 {
            customColors = hexes.map { Color(hex: $0) }
        }
    }
}

extension Color {
    init(hex: String) {
        let yarn = YarnColor(hex: hex) ?? YarnColor(r: 0.5, g: 0.5, b: 0.5)
        self.init(.sRGB, red: yarn.r, green: yarn.g, blue: yarn.b)
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
