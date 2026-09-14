import Foundation
import KnitCore

enum PatternChoice: Hashable, Codable {
    /// Each folder gets its own pattern, picked from its name.
    case surprise
    case pattern(PatternID)
}

enum YarnChoice: Hashable, Codable {
    /// Each folder gets its own palette, picked from its name.
    case surprise
    case preset(String)
    /// Colours sampled from the current desktop picture.
    case wallpaper
    case custom
}

/// Everything the user picks in the design panel. A value type: the same design turns into a
/// different sweater per folder only when a choice is "Surprise".
struct KnitDesign: Hashable, Codable {
    var pattern: PatternChoice = .pattern(.fairIsle)
    var yarn: YarnChoice = .preset("finder")
    var hasCuff = true
    /// Main, second and accent yarns for `.custom`, as hex.
    var customHexes: [String] = ["#C8423F", "#FAF4EA", "#6E9E78"]

    func patternID(forFolderNamed name: String) -> PatternID {
        switch pattern {
        case .surprise: return PatternID.assigned(to: name)
        case .pattern(let id): return id
        }
    }

    func palette(forFolderNamed name: String, wallpaper: YarnPalette) -> YarnPalette {
        switch yarn {
        case .surprise: return YarnPreset.assigned(to: name).palette
        case .preset(let id): return (YarnPreset.named(id) ?? YarnPreset.all[0]).palette
        case .wallpaper: return wallpaper
        case .custom: return customPalette
        }
    }

    func sweater(forFolderNamed name: String, wallpaper: YarnPalette) -> FolderSweater {
        FolderSweater(pattern: patternID(forFolderNamed: name),
                      palette: palette(forFolderNamed: name, wallpaper: wallpaper),
                      hasCuff: hasCuff)
    }

    var customPalette: YarnPalette {
        var yarns = customHexes.compactMap(YarnColor.init(hex:))
        while yarns.count < 3 { yarns.append(yarns.last ?? YarnPalette.undyed.primary) }
        var background = yarns[0].hsl
        background.s *= 0.4
        return YarnPalette(colors: Array(yarns.prefix(3)) + [YarnColor(hsl: background)])
    }

    var patternLabel: String {
        switch pattern {
        case .surprise: return "Surprise patterns"
        case .pattern(let id): return id.displayName
        }
    }

    var yarnLabel: String {
        switch yarn {
        case .surprise: return "surprise yarn"
        case .preset(let id): return YarnPreset.named(id)?.name ?? "yarn"
        case .wallpaper: return "wallpaper yarn"
        case .custom: return "custom yarn"
        }
    }
}
