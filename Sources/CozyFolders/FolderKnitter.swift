import AppKit
import KnitCore

/// Puts sweaters on folders and takes them off again.
///
/// Uses `NSWorkspace.setIcon(_:forFile:)`, which stores the icon inside the folder (a hidden
/// `Icon\r` file plus a Finder flag). Passing `nil` restores the standard folder icon.
enum FolderKnitter {
    enum Outcome {
        case knitted
        case notAFolder
        case failed
    }

    static func isKnittable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isVolumeKey])
        return values?.isDirectory == true && values?.isPackage != true && values?.isVolume != true
    }

    static func knit(_ url: URL, with sweater: FolderSweater) -> Outcome {
        guard isKnittable(url) else { return .notAFolder }
        let icon = FolderIconRenderer.icon(for: sweater)
        return NSWorkspace.shared.setIcon(icon, forFile: url.path, options: []) ? .knitted : .failed
    }

    @discardableResult
    static func unknit(_ url: URL) -> Bool {
        NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
    }

    /// Custom folder icons add a hidden `Icon\r` file, which git reports as untracked.
    static func isGitRepository(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path)
    }
}
