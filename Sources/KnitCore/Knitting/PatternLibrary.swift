import Foundation

/// Every pattern, charted. Palette indices: 0 lead yarn, 1 contrast, 2 accent, 3 background.
///
/// Charts read top row first. Chart keys: `.` lead, `#` contrast, `o` accent, `-` background.
public enum PatternLibrary {
    public static func pattern(for id: PatternID) -> KnitPattern {
        switch id {
        case .fairIsle: return fairIsle
        case .nordicStar: return nordicStar
        case .hearts: return hearts
        case .trees: return trees
        case .argyle: return argyle
        case .stripes: return stripes
        case .gingham: return gingham
        case .houndstooth: return houndstooth
        case .chevron: return chevron
        case .polkaDots: return polkaDots
        case .stockinette: return stockinette
        case .seed: return seed
        case .rib: return rib
        case .basketweave: return basketweave
        case .cable: return cable
        }
    }

    static let colourKey: [Character: KnitCell] = [".": KnitCell(0), "#": KnitCell(1), "o": KnitCell(2), "-": KnitCell(3)]

    // MARK: Colourwork

    /// A small diamond with a dot between repeats.
    public static let fairIsle = KnitPattern(id: "fairIsle", chart: [
        "...#....",
        "..#.#...",
        ".#...#..",
        "#..o..#.",
        ".#...#..",
        "..#.#...",
        "...#....",
        ".......o",
    ], key: colourKey)

    /// The eight-petal Selbu star, with an accent stitch at its heart and between stars.
    public static let nordicStar = KnitPattern(id: "nordicStar", chart: [
        "o..............",
        ".......#.......",
        "......###......",
        "..#...###...#..",
        "..##..###..##..",
        "..###..#..###..",
        "...####.####...",
        "..#####o#####..",
        "...####.####...",
        "..###..#..###..",
        "..##..###..##..",
        "..#...###...#..",
        "......###......",
        ".......#.......",
        "...............",
    ], key: colourKey)

    public static let hearts = KnitPattern(id: "hearts", chart: [
        "..........",
        "..##.##...",
        ".#######..",
        ".###o###..",
        "..#####...",
        "...###....",
        "....#.....",
        "..........",
        "..........",
    ], key: colourKey)

    /// Little pines with accent trunks, and a snowflake stitch between them.
    public static let trees = KnitPattern(id: "trees", chart: [
        "..........",
        "....#.....",
        "...###....",
        "....#.....",
        "...###....",
        "..#####...",
        ".#######..",
        "....o.....",
        "..........",
        ".........-",
    ], key: colourKey)

    /// Diamonds in two colours with a dashed diagonal lattice in a third.
    public static let argyle = KnitPattern(id: "argyle", columns: 12, rows: 16) { column, row in
        // Lattice: two diagonals crossing at each diamond's centre, one stitch wide per row.
        let v = (Double(row) + 0.5) / 16  // 0..<1 down the repeat
        let falling = Int(v * 12) % 12
        let rising = (11 - Int(v * 12)) % 12
        if column == falling || column == rising { return KnitCell(2) }
        let u = (Double(column) + 0.5) / 6
        let inDiamond = abs(u - 1) + abs(v * 2 - 1) <= 1
        return KnitCell(inDiamond ? 0 : 3)
    }

    // MARK: Stripes & checks

    /// Horizontal bands, three rows per colour.
    public static let stripes = KnitPattern(id: "stripes", columns: 1, rows: 6, offsetsAlternateRows: true) { _, row in
        KnitCell(row < 3 ? 0 : 1)
    }

    /// Woven-looking checks: lead where bands cross, background where one band passes, accent between.
    public static let gingham = KnitPattern(id: "gingham", columns: 8, rows: 8) { column, row in
        switch (column < 4, row < 4) {
        case (true, true): return KnitCell(0)
        case (false, false): return KnitCell(2)
        default: return KnitCell(3)
        }
    }

    /// The classic four-stitch houndstooth.
    public static let houndstooth = KnitPattern(id: "houndstooth", chart: [
        "#...",
        "..#.",
        ".###",
        "###.",
    ], key: colourKey)

    /// Zigzag bands in contrast and accent over the lead yarn.
    public static let chevron = KnitPattern(id: "chevron", columns: 12, rows: 8) { column, row in
        switch (row + abs(column - 6)) % 8 {
        case 0, 1: return KnitCell(1)
        case 4, 5: return KnitCell(2)
        default: return KnitCell(0)
        }
    }

    public static let polkaDots = KnitPattern(id: "polkaDots", chart: [
        "........",
        ".##.....",
        ".##.....",
        "........",
        "........",
        ".....oo.",
        ".....oo.",
        "........",
    ], key: colourKey)

    // MARK: Texture

    /// Plain knit in the lead yarn.
    public static let stockinette = KnitPattern(id: "stockinette", columns: 1, rows: 2, offsetsAlternateRows: true) { _, _ in
        KnitCell(0)
    }

    /// Alternating knit and purl — all texture.
    public static let seed = KnitPattern(id: "seed", columns: 2, rows: 2) { column, row in
        KnitCell(0, (column + row) % 2 == 0 ? .knit : .purl)
    }

    /// 2×2 rib: two columns of knit, two of purl.
    public static let rib = KnitPattern(id: "rib", columns: 4, rows: 2) { column, _ in
        KnitCell(0, column < 2 ? .knit : .purl)
    }

    /// Blocks of knit and purl, like woven cane.
    public static let basketweave = KnitPattern(id: "basketweave", columns: 8, rows: 8) { column, row in
        KnitCell(0, (column < 4) == (row < 4) ? .knit : .purl)
    }

    /// A four-stitch rope cable between purl gutters. Geometry, not colour.
    public static let cable = KnitPattern(id: "cable", columns: 6, rows: 12) { column, row in
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
    public static let ribbing = KnitPattern(id: "ribbing", columns: 2, rows: 2) { column, _ in
        KnitCell(0, column == 0 ? .knit : .purl)
    }
}
