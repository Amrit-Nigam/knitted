import Foundation

public enum PatternID: String, CaseIterable, Codable, Sendable {
    // Colourwork
    case fairIsle
    case nordicStar
    case hearts
    case trees
    case argyle
    // Stripes & checks
    case stripes
    case gingham
    case houndstooth
    case chevron
    case polkaDots
    // Texture
    case stockinette
    case seed
    case rib
    case basketweave
    case cable

    public enum Family: String, CaseIterable, Sendable {
        case colourwork = "Colourwork"
        case geometric = "Stripes & Checks"
        case texture = "Texture"
    }

    public var family: Family {
        switch self {
        case .fairIsle, .nordicStar, .hearts, .trees, .argyle: return .colourwork
        case .stripes, .gingham, .houndstooth, .chevron, .polkaDots: return .geometric
        case .stockinette, .seed, .rib, .basketweave, .cable: return .texture
        }
    }

    public var displayName: String {
        switch self {
        case .fairIsle: return "Fair Isle"
        case .nordicStar: return "Nordic Star"
        case .hearts: return "Hearts"
        case .trees: return "Pine Trees"
        case .argyle: return "Argyle"
        case .stripes: return "Stripes"
        case .gingham: return "Gingham"
        case .houndstooth: return "Houndstooth"
        case .chevron: return "Chevron"
        case .polkaDots: return "Polka Dots"
        case .stockinette: return "Stockinette"
        case .seed: return "Seed Stitch"
        case .rib: return "Rib"
        case .basketweave: return "Basketweave"
        case .cable: return "Cable"
        }
    }

    /// Patterns handed out by "Surprise". Plain stockinette is left out; it's no surprise.
    public static let surprisePool: [PatternID] = allCases.filter { $0 != .stockinette }

    /// A stable pattern for a name: the same folder always gets the same surprise.
    public static func assigned(to name: String) -> PatternID {
        surprisePool[Int(StableHash.fnv1a(name) % UInt64(surprisePool.count))]
    }

    public var pattern: KnitPattern { PatternLibrary.pattern(for: self) }
}

public struct KnitCell: Equatable, Sendable {
    public var colorIndex: Int
    public var glyph: StitchGlyph

    public init(_ colorIndex: Int, _ glyph: StitchGlyph = .knit) {
        self.colorIndex = colorIndex
        self.glyph = glyph
    }
}

/// A small stitch grid that tiles. Each cell indexes into a `YarnPalette` and names a glyph.
public struct KnitPattern: Equatable, Sendable {
    public let id: String
    public let columns: Int
    public let rows: Int
    public let cells: [KnitCell]  // row-major, row 0 at the top
    /// Shift odd rows by half a stitch to break up grid regularity. Off for anything whose
    /// look depends on straight columns (ribbing, cables, seed) or on a colourwork chart.
    public let offsetsAlternateRows: Bool

    public init(id: String, columns: Int, rows: Int, offsetsAlternateRows: Bool = false,
                cell: (_ column: Int, _ row: Int) -> KnitCell) {
        precondition(!offsetsAlternateRows || rows % 2 == 0, "offset patterns need an even row repeat to tile")
        self.id = id
        self.columns = columns
        self.rows = rows
        self.offsetsAlternateRows = offsetsAlternateRows
        var cells: [KnitCell] = []
        for row in 0..<rows {
            for column in 0..<columns { cells.append(cell(column, row)) }
        }
        self.cells = cells
    }

    /// Builds a pattern from a colourwork chart, top row first. Every character maps to a
    /// cell through `key`; all rows must be the same width.
    public init(id: String, chart: [String], key: [Character: KnitCell]) {
        let grid = chart.map(Array.init)
        precondition(Set(grid.map(\.count)).count == 1, "chart rows for \(id) differ in width")
        self.init(id: id, columns: grid[0].count, rows: grid.count) { column, row in
            guard let cell = key[grid[row][column]] else { preconditionFailure("no key for '\(grid[row][column])' in \(id)") }
            return cell
        }
    }

    /// Wrapping lookup, so neighbours across the repeat boundary resolve correctly.
    public subscript(column: Int, row: Int) -> KnitCell {
        let c = ((column % columns) + columns) % columns
        let r = ((row % rows) + rows) % rows
        return cells[r * columns + c]
    }

    /// Palette indices this pattern actually uses.
    public var colorIndices: Set<Int> { Set(cells.map(\.colorIndex)) }
}
