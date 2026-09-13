import AppKit
import KnitCore

/// How border windows are stacked relative to the windows they wrap. See StackingCoordinator.
enum OrderingMode: String, Codable, CaseIterable {
    /// Strategy (a): only the frontmost window gets a border, floating above everything.
    case focusedOnly
    /// Strategy (b): every window gets a border, all parked just below normal windows.
    case belowAll
    /// Strategy (c): private SkyLight ordering puts each border directly beneath its window.
    case skyLight

    var displayName: String {
        switch self {
        case .focusedOnly: return "Focused Window Only"
        case .belowAll: return "All Windows"
        case .skyLight: return "All Windows, Exact Stacking (Experimental)"
        }
    }
}

struct Preferences: Codable, Equatable {
    var enabled = true
    var ordering: OrderingMode = .belowAll
    var borderWidth: Double = 14
    var stitchWidth: Double = 4.5
    var stitchHeight: Double = 3.5
    var windowCornerRadius: Double = 12
    var excludedBundleIDs: [String] = []
    var patternOverrides: [String: PatternID] = [:]
    /// Hex colours, primary / secondary / accent. The background yarn is derived.
    var paletteOverrides: [String: [String]] = [:]

    init() {}

    // Decode field by field so preferences saved by an older build survive new keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        ordering = (try? c.decodeIfPresent(OrderingMode.self, forKey: .ordering)) ?? d.ordering
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? d.borderWidth
        stitchWidth = try c.decodeIfPresent(Double.self, forKey: .stitchWidth) ?? d.stitchWidth
        stitchHeight = try c.decodeIfPresent(Double.self, forKey: .stitchHeight) ?? d.stitchHeight
        windowCornerRadius = try c.decodeIfPresent(Double.self, forKey: .windowCornerRadius) ?? d.windowCornerRadius
        excludedBundleIDs = try c.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? d.excludedBundleIDs
        patternOverrides = (try? c.decodeIfPresent([String: PatternID].self, forKey: .patternOverrides)) ?? d.patternOverrides
        paletteOverrides = try c.decodeIfPresent([String: [String]].self, forKey: .paletteOverrides) ?? d.paletteOverrides
    }

    var stitch: StitchSize { StitchSize(width: stitchWidth, height: stitchHeight) }

    func pattern(forBundleID bundleID: String?) -> PatternID {
        guard let bundleID else { return .stockinette }
        return patternOverrides[bundleID] ?? PatternID.assigned(toBundleID: bundleID)
    }

    func paletteOverride(forBundleID bundleID: String?) -> YarnPalette? {
        guard let bundleID, let hexes = paletteOverrides[bundleID] else { return nil }
        let colors = hexes.compactMap(YarnColor.init(hex:))
        guard colors.count == 3 else { return nil }
        var background = colors[0].hsl
        background.s *= 0.4
        return YarnPalette(colors: colors + [YarnColor(hsl: background)])
    }
}

/// UserDefaults-backed settings. Main thread only.
final class PreferencesStore {
    static let shared = PreferencesStore()
    static let didChangeNotification = Notification.Name("CozyBordersPreferencesDidChange")

    private let defaults: UserDefaults
    private let key = "preferences.v1"

    private(set) var preferences: Preferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = Preferences()
        }
    }

    func update(_ change: (inout Preferences) -> Void) {
        var next = preferences
        change(&next)
        guard next != preferences else { return }
        preferences = next
        if let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    // App-level flags that aren't user preferences.
    var hasPromptedForAccessibility: Bool {
        get { defaults.bool(forKey: "hasPromptedForAccessibility") }
        set { defaults.set(newValue, forKey: "hasPromptedForAccessibility") }
    }
}
