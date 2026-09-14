import Foundation

/// Hand-picked yarn palettes: primary, secondary, accent, background.
public struct YarnPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let palette: YarnPalette

    init(_ id: String, _ name: String, _ hexes: [String]) {
        self.id = id
        self.name = name
        self.palette = YarnPalette(colors: hexes.map { YarnColor(hex: $0)! })
    }

    public static let all: [YarnPreset] = [
        YarnPreset("finder", "Finder Blue", ["#6FAEE3", "#D6EAF8", "#FFFDF7", "#9CC6EA"]),
        YarnPreset("oatmeal", "Oatmeal", ["#D8C8AE", "#9C7F66", "#F4ECDD", "#BCAE99"]),
        YarnPreset("forest", "Forest", ["#4E7A58", "#B6C48A", "#EFE6D0", "#7E9A83"]),
        YarnPreset("berry", "Berry", ["#A34463", "#EBB2C2", "#F6EBE0", "#BC8595"]),
        YarnPreset("ocean", "Ocean", ["#3D6FA6", "#A6CBE6", "#F3EDDD", "#8199B3"]),
        YarnPreset("pumpkin", "Pumpkin", ["#D2743A", "#F4CB86", "#FBF1DF", "#B38A6C"]),
        YarnPreset("heather", "Heather", ["#8174A8", "#CFC1E6", "#F2ECF5", "#A39BB6"]),
        YarnPreset("mint", "Mint", ["#62AE9C", "#F5D3C4", "#FBF6EE", "#93BFB4"]),
        YarnPreset("charcoal", "Charcoal", ["#47474D", "#DAD5CB", "#C0503F", "#7C7C82"]),
        YarnPreset("candy", "Candy Cane", ["#C8423F", "#FAF4EA", "#6E9E78", "#D99A95"]),
    ]

    public static func named(_ id: String) -> YarnPreset? {
        all.first { $0.id == id }
    }

    /// A stable preset for a name — so "Surprise me" gives each folder its own sweater, and
    /// the same folder always gets the same one.
    public static func assigned(to name: String) -> YarnPreset {
        all[Int(StableHash.fnv1a(name) >> 8 % UInt64(all.count))]
    }
}

public enum StableHash {
    /// FNV-1a. Swift's `hashValue` is seeded per launch, so it can't be used for anything
    /// that must be stable across launches.
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
