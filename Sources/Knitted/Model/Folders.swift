import Foundation

/// A folder picked for knitting but not yet changed.
struct StagedFolder: Identifiable, Hashable {
    let url: URL
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    /// Custom icons add a hidden `Icon\r` file, which git reports as untracked.
    var isGitRepository: Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path)
    }
}

/// A folder that's wearing a sweater.
struct KnittedFolder: Identifiable, Hashable, Codable {
    var path: String
    var date: Date
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

struct Toast: Identifiable, Equatable {
    enum Kind { case done, warning }
    let id = UUID()
    let message: String
    let kind: Kind
}
