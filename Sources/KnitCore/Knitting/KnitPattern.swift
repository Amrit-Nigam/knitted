import Foundation

public enum PatternID: String, CaseIterable, Codable, Sendable {
    case stripes
    case fairIsle
    case seed
    case argyle
    case cable
    /// Plain knit in the lead yarn. Not auto-assigned; available as an override.
    case stockinette

    /// The patterns handed out automatically by bundle-identifier hash.
    public static let autoAssigned: [PatternID] = [.stripes, .fairIsle, .seed, .argyle, .cable]

    public var displayName: String {
        switch self {
        case .stripes: return "Stripes"
        case .fairIsle: return "Fair Isle"
        case .seed: return "Seed Stitch"
        case .argyle: return "Argyle"
        case .cable: return "Cable"
        case .stockinette: return "Stockinette"
        }
    }

    /// Deterministic per-app pattern: FNV-1a of the bundle identifier, modulo the pattern
    /// count. Swift's `hashValue` is seeded per launch, so it can't be used here.
    public static func assigned(toBundleID bundleID: String) -> PatternID {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in bundleID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return autoAssigned[Int(hash % UInt64(autoAssigned.count))]
    }
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

    public init(id: String, columns: Int, rows: Int, offsetsAlternateRows: Bool, cell: (_ column: Int, _ row: Int) -> KnitCell) {
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

    /// Wrapping lookup, so neighbours across the repeat boundary resolve correctly.
    public subscript(column: Int, row: Int) -> KnitCell {
        let c = ((column % columns) + columns) % columns
        let r = ((row % rows) + rows) % rows
        return cells[r * columns + c]
    }

    public static func named(_ id: PatternID) -> KnitPattern {
        switch id {
        case .stripes: return stripes
        case .fairIsle: return fairIsle
        case .seed: return seed
        case .argyle: return argyle
        case .cable: return cable
        case .stockinette: return stockinette
        }
    }

    // MARK: Definitions

    public static let stockinette = KnitPattern(id: "stockinette", columns: 1, rows: 2, offsetsAlternateRows: true) { _, _ in
        KnitCell(0)
    }

    /// Horizontal bands, three rows per colour.
    public static let stripes = KnitPattern(id: "stripes", columns: 1, rows: 6, offsetsAlternateRows: true) { _, row in
        KnitCell(row < 3 ? 0 : 1)
    }

    /// A small diamond with a dot between repeats, knitted over the lead yarn.
    public static let fairIsle: KnitPattern = {
        let chart = [
            "...#....",
            "..#.#...",
            ".#...#..",
            "#..o..#.",
            ".#...#..",
            "..#.#...",
            "...#....",
            ".......o",
        ].map { Array($0) }
        return KnitPattern(id: "fairIsle", columns: 8, rows: 8, offsetsAlternateRows: false) { column, row in
            switch chart[row][column] {
            case "#": return KnitCell(1)
            case "o": return KnitCell(2)
            default: return KnitCell(0)
            }
        }
    }()

    /// Alternating knit and purl, single colour — all texture.
    public static let seed = KnitPattern(id: "seed", columns: 2, rows: 2, offsetsAlternateRows: false) { column, row in
        KnitCell(0, (column + row) % 2 == 0 ? .knit : .purl)
    }

    /// Diamonds in two colours with a dashed diagonal lattice in a third.
    public static let argyle = KnitPattern(id: "argyle", columns: 12, rows: 16, offsetsAlternateRows: false) { column, row in
        // Lattice: two diagonals crossing at each diamond's centre, one stitch wide per row.
        let v = (Double(row) + 0.5) / 16  // 0..<1 down the repeat
        let falling = Int(v * 12) % 12
        let rising = (11 - Int(v * 12)) % 12
        if column == falling || column == rising { return KnitCell(2) }
        let u = (Double(column) + 0.5) / 6
        let inDiamond = abs(u - 1) + abs(v * 2 - 1) <= 1
        return KnitCell(inDiamond ? 0 : 3)
    }

    /// A four-stitch rope cable between purl gutters. Geometry, not colour.
    public static let cable = KnitPattern(id: "cable", columns: 6, rows: 12, offsetsAlternateRows: false) { column, row in
        switch column {
        case 0, 5:
            return KnitCell(0, .purl)
        default:
            guard row < 4 else { return KnitCell(0) }
            // During the crossing the left pair travels right, in front of the right pair.
            return KnitCell(0, column <= 2 ? .cableRight : .cableLeft)
        }
    }

    /// 1×1 ribbing: alternating columns of knit and purl. Used for cuffs.
    public static let ribbing = KnitPattern(id: "ribbing", columns: 2, rows: 2, offsetsAlternateRows: false) { column, _ in
        KnitCell(0, column == 0 ? .knit : .purl)
    }
}
