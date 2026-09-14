import AppKit
import KnitCore
import Observation

/// The app's state and everything you can do in it.
///
/// Folders move through three places: dropped or chosen folders are **staged**; **apply**
/// knits the current design onto every staged folder and moves them to the **wardrobe**;
/// from the wardrobe a folder can be restaged to change its sweater, or unknitted.
@MainActor
@Observable
final class Studio {
    var design: KnitDesign {
        didSet { store.saveDesign(design) }
    }
    private(set) var staged: [StagedFolder] = []
    var focusedID: StagedFolder.ID?
    private(set) var wardrobe: [KnittedFolder]
    private(set) var toast: Toast?

    @ObservationIgnored private let store: StudioStore
    @ObservationIgnored private let wallpaper = WallpaperYarn()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(store: StudioStore = StudioStore()) {
        self.store = store
        design = store.loadDesign()
        wardrobe = store.loadWardrobe().filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: Previews

    var focused: StagedFolder? {
        staged.first { $0.id == focusedID } ?? staged.first
    }

    /// The folder name the big preview and the pattern thumbnails are drawn for.
    var previewName: String { focused?.name ?? "Work" }

    var previewSweater: FolderSweater { sweater(forFolderNamed: previewName) }

    func sweater(forFolderNamed name: String) -> FolderSweater {
        design.sweater(forFolderNamed: name, wallpaper: wallpaperPalette)
    }

    var wallpaperPalette: YarnPalette { wallpaper.palette() }

    // MARK: Staging

    func stage(_ urls: [URL]) {
        let folders = urls.filter(FolderKnitter.isKnittable)
        var added = 0
        for url in folders where !staged.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            staged.append(StagedFolder(url: url))
            added += 1
        }
        if added > 0 {
            focusedID = staged.last?.id
        }
        let skipped = urls.count - folders.count
        if skipped > 0 {
            show(skipped == 1 ? "Only folders can wear sweaters" : "Skipped \(skipped) items that aren't folders", .warning)
        }
    }

    func unstage(_ folder: StagedFolder) {
        staged.removeAll { $0.id == folder.id }
        if focusedID == folder.id { focusedID = staged.first?.id }
    }

    func clearStaged() {
        staged.removeAll()
        focusedID = nil
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders to knit sweaters for"
        guard panel.runModal() == .OK else { return }
        stage(panel.urls)
    }

    /// Moves wardrobe folders back to staging so their sweater can be changed.
    func restage(_ folders: [KnittedFolder]) {
        stage(folders.map(\.url))
    }

    // MARK: Knitting

    func apply() {
        guard !staged.isEmpty else { return }
        var done: [StagedFolder] = []
        var failed: [StagedFolder] = []
        for folder in staged {
            if FolderKnitter.knit(folder.url, with: sweater(forFolderNamed: folder.name)) {
                done.append(folder)
            } else {
                failed.append(folder)
            }
        }

        let now = Date()
        for folder in done {
            wardrobe.removeAll { $0.path == folder.url.path }
            wardrobe.insert(KnittedFolder(path: folder.url.path, date: now), at: 0)
        }
        store.saveWardrobe(wardrobe)
        // Keep failures staged so they can be retried.
        staged = failed
        focusedID = failed.first?.id

        if !failed.isEmpty {
            show("Couldn't change \(failed.map(\.name).joined(separator: ", ")). Check Knitted is allowed to access it.", .warning)
        } else if done.contains(where: \.isGitRepository) {
            show("Knitted! Git will notice a hidden “Icon” file — add Icon? to .gitignore", .warning)
        } else {
            show(done.count == 1 ? "\(done[0].name) is wearing its sweater" : "Knitted \(done.count) sweaters", .done)
        }
    }

    func unknit(_ folder: KnittedFolder) {
        FolderKnitter.unknit(folder.url)
        wardrobe.removeAll { $0.id == folder.id }
        store.saveWardrobe(wardrobe)
        show("\(folder.name) is back to its usual self", .done)
    }

    func unknitAll() {
        let count = wardrobe.count
        for folder in wardrobe { FolderKnitter.unknit(folder.url) }
        wardrobe.removeAll()
        store.saveWardrobe(wardrobe)
        show(count == 1 ? "Took off 1 sweater" : "Took off \(count) sweaters", .done)
    }

    // MARK: Toasts

    private func show(_ message: String, _ kind: Toast.Kind) {
        toast = Toast(message: message, kind: kind)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(kind == .warning ? 6 : 3.5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
