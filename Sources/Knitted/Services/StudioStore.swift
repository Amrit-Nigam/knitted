import Foundation

/// Persists the current design and the wardrobe in UserDefaults.
struct StudioStore {
    private let defaults: UserDefaults
    private let designKey = "design.v2"
    private let wardrobeKey = "wardrobe.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadDesign() -> KnitDesign {
        decode(KnitDesign.self, forKey: designKey) ?? KnitDesign()
    }

    func saveDesign(_ design: KnitDesign) {
        encode(design, forKey: designKey)
    }

    func loadWardrobe() -> [KnittedFolder] {
        decode([KnittedFolder].self, forKey: wardrobeKey) ?? []
    }

    func saveWardrobe(_ wardrobe: [KnittedFolder]) {
        encode(wardrobe, forKey: wardrobeKey)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
