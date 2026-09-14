import AppKit
import KnitCore

/// Writes (or clears, with `nil`) a file's custom icon. Abstracted so tests can observe the
/// exact sequence of icon changes.
protocol IconWriting {
    func setIcon(_ image: NSImage?, forFile path: String) -> Bool
}

/// The real thing: `NSWorkspace.setIcon(_:forFile:)`, which stores the icon inside the folder
/// (a hidden `Icon\r` file plus a Finder flag). Main thread only.
struct WorkspaceIconWriter: IconWriting {
    func setIcon(_ image: NSImage?, forFile path: String) -> Bool {
        NSWorkspace.shared.setIcon(image, forFile: path, options: [])
    }
}

/// Puts sweaters on folders and takes them off again. Icon changes happen on the main actor.
struct FolderKnitter {
    var writer: IconWriting = WorkspaceIconWriter()

    /// How long a folder rests without a sweater before it gets a new one.
    ///
    /// Writing over an existing custom icon, or clearing and re-setting it in one go, often
    /// leaves the Desktop showing the old sweater: it only redraws when it has seen the folder
    /// without its custom icon. Measured on macOS 26 with app-sized icons, re-knitting showed
    /// the new sweater on the Desktop 2/8 times immediately, 4/8 after 0.25s, 8/8 after 0.6s.
    var settleDelay: Duration = .milliseconds(750)

    static func isKnittable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isVolumeKey])
        return values?.isDirectory == true && values?.isPackage != true && values?.isVolume != true
    }

    /// Knits each folder with its sweater, returning the folders that succeeded.
    /// Folders already wearing a sweater have it taken off first; the whole batch then waits
    /// `settleDelay` once before the new sweaters go on.
    @MainActor
    func knit(_ jobs: [(url: URL, sweater: FolderSweater)]) async -> Set<URL> {
        let knittable = jobs.filter { Self.isKnittable($0.url) }
        // Render before touching anything, so folders spend as little time bare as possible.
        let icons = knittable.map { (url: $0.url, icon: FolderIconRenderer.icon(for: $0.sweater)) }

        let rewearing = knittable.filter { Self.hasCustomIcon($0.url) }
        for job in rewearing {
            unknit(job.url)
        }
        if !rewearing.isEmpty {
            try? await Task.sleep(for: settleDelay)
        }

        var done = Set<URL>()
        for job in icons where writer.setIcon(job.icon, forFile: job.url.path) {
            done.insert(job.url)
        }
        return done
    }

    @MainActor
    func knit(_ url: URL, with sweater: FolderSweater) async -> Bool {
        await knit([(url, sweater)]).contains(url)
    }

    @MainActor
    @discardableResult
    func unknit(_ url: URL) -> Bool {
        writer.setIcon(nil, forFile: url.path)
    }

    /// Whether the folder carries a custom icon: the hidden `Icon\r` file is present.
    static func hasCustomIcon(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: iconFile(in: url).path)
    }

    static func iconFile(in url: URL) -> URL {
        url.appendingPathComponent("Icon\r")
    }
}
