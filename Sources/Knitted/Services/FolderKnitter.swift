import AppKit
import KnitCore

/// Puts sweaters on folders and takes them off again.
///
/// Uses `NSWorkspace.setIcon(_:forFile:)`, which stores the icon inside the folder (a hidden
/// `Icon\r` file plus a Finder flag). Passing `nil` restores the standard folder icon.
enum FolderKnitter {
    static func isKnittable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isVolumeKey])
        return values?.isDirectory == true && values?.isPackage != true && values?.isVolume != true
    }

    static func knit(_ url: URL, with sweater: FolderSweater) -> Bool {
        guard isKnittable(url) else { return false }
        return NSWorkspace.shared.setIcon(FolderIconRenderer.icon(for: sweater), forFile: url.path, options: [])
    }

    @discardableResult
    static func unknit(_ url: URL) -> Bool {
        NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
    }
}
