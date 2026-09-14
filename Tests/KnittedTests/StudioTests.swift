import Foundation
import KnitCore
import Testing
@testable import Knitted

@MainActor
@Suite(.serialized)
struct StudioTests {
    func makeStudio(_ defaults: UserDefaults = isolatedDefaults()) -> Studio {
        Studio(store: StudioStore(defaults: defaults), knitter: .forTests)
    }

    // MARK: Staging

    @Test func stagingAddsFoldersWithoutChangingThem() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let studio = makeStudio()

        studio.stage([work])

        #expect(studio.staged.map(\.url) == [work])
        #expect(studio.focused?.url == work)
        #expect(!FolderKnitter.hasCustomIcon(work), "staging must not knit")
        #expect(studio.wardrobe.isEmpty)
    }

    @Test func stagingSkipsDuplicatesAndNonFolders() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let code = try sandbox.folder("code")
        let file = try sandbox.file("notes.txt")
        let studio = makeStudio()

        studio.stage([work, file])
        studio.stage([work, code])

        #expect(studio.staged.map(\.name) == ["Work", "code"])
        #expect(studio.focused?.name == "code")
        #expect(studio.toast?.kind == .warning)
    }

    @Test func unstagingMovesFocus() async throws {
        let sandbox = try Sandbox()
        let studio = makeStudio()
        studio.stage([try sandbox.folder("A"), try sandbox.folder("B")])
        let b = try #require(studio.staged.last)

        studio.unstage(b)
        #expect(studio.staged.map(\.name) == ["A"])
        #expect(studio.focused?.name == "A")

        studio.clearStaged()
        #expect(studio.staged.isEmpty)
        #expect(studio.focused == nil)
    }

    // MARK: Applying

    @Test func applyKnitsEveryStagedFolderAndMovesThemToTheWardrobe() async throws {
        let sandbox = try Sandbox()
        let folders = [try sandbox.folder("Work"), try sandbox.folder("code"), try sandbox.folder("screenshots")]
        let studio = makeStudio()

        studio.stage(folders)
        await studio.apply()

        #expect(studio.staged.isEmpty)
        #expect(Set(studio.wardrobe.map(\.path)) == Set(folders.map(\.path)))
        for folder in folders {
            #expect(FolderKnitter.hasCustomIcon(folder), "\(folder.lastPathComponent)")
        }
        #expect(studio.toast?.kind == .done)
    }

    /// The reported bug, end to end: knit, change the design, restage from the wardrobe, knit
    /// again — the folder must end up with the new icon and appear once in the wardrobe.
    @Test func changingASweaterFromTheWardrobeAppliesTheNewDesign() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let studio = makeStudio()

        studio.design.pattern = .pattern(.chevron)
        studio.design.yarn = .preset("pumpkin")
        studio.stage([work])
        await studio.apply()
        let first = try #require(IconInspector.storedIconDigest(work))

        studio.design.yarn = .preset("mint")
        studio.restage(studio.wardrobe)
        #expect(studio.staged.map(\.url) == [work])
        await studio.apply()
        let second = try #require(IconInspector.storedIconDigest(work))

        #expect(first != second)
        #expect(studio.wardrobe.count == 1)
        #expect(studio.staged.isEmpty)

        // And the stored icon looks like the mint design, not the pumpkin one.
        var pumpkin = studio.design
        pumpkin.yarn = .preset("pumpkin")
        let toMint = try #require(IconInspector.colorDistance(of: work, to: studio.sweater(forFolderNamed: "Work")))
        let toPumpkin = try #require(IconInspector.colorDistance(of: work, to: pumpkin.sweater(forFolderNamed: "Work", wallpaper: .undyed)))
        #expect(toMint < toPumpkin)
    }

    @Test func reknittingMovesTheFolderToTheFrontOfTheWardrobe() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let code = try sandbox.folder("code")
        let studio = makeStudio()

        studio.stage([work]); await studio.apply()
        studio.stage([code]); await studio.apply()
        #expect(studio.wardrobe.map(\.name) == ["code", "Work"])

        studio.stage([work]); await studio.apply()
        #expect(studio.wardrobe.map(\.name) == ["Work", "code"])
    }

    @Test func foldersThatCannotBeKnittedStayStaged() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let doomed = try sandbox.folder("Doomed")
        let studio = makeStudio()

        studio.stage([work, doomed])
        try FileManager.default.removeItem(at: doomed)
        await studio.apply()

        #expect(studio.staged.map(\.name) == ["Doomed"])
        #expect(studio.wardrobe.map(\.name) == ["Work"])
        #expect(studio.toast?.kind == .warning)
    }

    @Test func knittingFlagIsClearedAfterApply() async throws {
        let sandbox = try Sandbox()
        let studio = makeStudio()
        studio.stage([try sandbox.folder("Work")])
        #expect(!studio.isKnitting)
        await studio.apply()
        #expect(!studio.isKnitting)
    }

    @Test func applyWithNothingStagedDoesNothing() async {
        let studio = makeStudio()
        await studio.apply()
        #expect(studio.wardrobe.isEmpty)
        #expect(studio.toast == nil)
    }

    @Test func surpriseGivesEachFolderItsOwnStableSweater() async throws {
        let sandbox = try Sandbox()
        let names = ["Work", "code", "screenshots", "goa-trip", "side-gig", "Photos"]
        let folders = try names.map { try sandbox.folder($0) }
        let studio = makeStudio()
        studio.design.pattern = .surprise
        studio.design.yarn = .surprise

        studio.stage(folders)
        await studio.apply()

        #expect(folders.allSatisfy(FolderKnitter.hasCustomIcon))
        let sweaters = Set(names.map { studio.sweater(forFolderNamed: $0) })
        #expect(sweaters.count > 1, "surprise should vary between folders")
        // Each folder wears its own surprise, not the first folder's.
        for (name, folder) in zip(names, folders) {
            let own = try #require(IconInspector.colorDistance(of: folder, to: studio.sweater(forFolderNamed: name)))
            #expect(own < 0.05, "\(name)")
        }
        #expect(studio.sweater(forFolderNamed: "Work") == studio.sweater(forFolderNamed: "Work"))
    }

    // MARK: Taking sweaters off

    @Test func unknitRemovesTheIconAndTheWardrobeEntry() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let studio = makeStudio()
        studio.stage([work]); await studio.apply()
        let knitted = try #require(studio.wardrobe.first)

        studio.unknit(knitted)

        #expect(!FolderKnitter.hasCustomIcon(work))
        #expect(studio.wardrobe.isEmpty)
    }

    @Test func unknitAllRestoresEveryFolder() async throws {
        let sandbox = try Sandbox()
        let folders = [try sandbox.folder("A"), try sandbox.folder("B")]
        let studio = makeStudio()
        studio.stage(folders); await studio.apply()

        studio.unknitAll()

        #expect(studio.wardrobe.isEmpty)
        #expect(folders.allSatisfy { !FolderKnitter.hasCustomIcon($0) })
    }

    // MARK: Persistence

    @Test func designAndWardrobeSurviveARelaunch() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let defaults = isolatedDefaults()

        let first = makeStudio(defaults)
        first.design.pattern = .pattern(.hearts)
        first.design.yarn = .custom
        first.design.customHexes = ["#112233", "#445566", "#778899"]
        first.design.hasCuff = false
        first.stage([work]); await first.apply()

        let relaunched = makeStudio(defaults)
        #expect(relaunched.design == first.design)
        #expect(relaunched.wardrobe.map(\.path) == [work.path])
        #expect(relaunched.staged.isEmpty, "the basket isn't persisted")
    }

    @Test func wardrobeForgetsFoldersThatNoLongerExist() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let gone = try sandbox.folder("Gone")
        let defaults = isolatedDefaults()

        let first = makeStudio(defaults)
        first.stage([work, gone]); await first.apply()
        try FileManager.default.removeItem(at: gone)

        #expect(makeStudio(defaults).wardrobe.map(\.name) == ["Work"])
    }
}

struct KnitDesignTests {
    let wallpaper = YarnPalette.undyed

    @Test func fixedChoicesGiveEveryFolderTheSameSweater() async {
        var design = KnitDesign()
        design.pattern = .pattern(.gingham)
        design.yarn = .preset("berry")
        let a = design.sweater(forFolderNamed: "Work", wallpaper: wallpaper)
        let b = design.sweater(forFolderNamed: "code", wallpaper: wallpaper)
        #expect(a == b)
        #expect(a.pattern == .gingham)
        #expect(a.palette == YarnPreset.named("berry")!.palette)
    }

    @Test func cuffSettingIsCarriedThrough() async {
        var design = KnitDesign()
        design.hasCuff = false
        #expect(design.sweater(forFolderNamed: "Work", wallpaper: wallpaper).hasCuff == false)
    }

    @Test func wallpaperYarnUsesTheWallpaperPalette() async {
        var design = KnitDesign()
        design.yarn = .wallpaper
        #expect(design.palette(forFolderNamed: "Work", wallpaper: wallpaper) == wallpaper)
    }

    @Test func customYarnUsesTheChosenColours() async {
        var design = KnitDesign()
        design.yarn = .custom
        design.customHexes = ["#FF0000", "#00FF00", "#0000FF"]
        let palette = design.palette(forFolderNamed: "Work", wallpaper: wallpaper)
        #expect(palette.colors.prefix(3).map(\.hex) == ["#FF0000", "#00FF00", "#0000FF"])
        #expect(palette.colors.count == 4)
    }

    @Test func badCustomHexesStillMakeAPalette() async {
        var design = KnitDesign()
        design.yarn = .custom
        design.customHexes = ["nope"]
        #expect(design.palette(forFolderNamed: "Work", wallpaper: wallpaper).colors.count == 4)
    }

    @Test func unknownPresetFallsBackToTheFirstPreset() async {
        var design = KnitDesign()
        design.yarn = .preset("does-not-exist")
        #expect(design.palette(forFolderNamed: "Work", wallpaper: wallpaper) == YarnPreset.all[0].palette)
    }

    @Test func designsRoundTripThroughJSON() async throws {
        var design = KnitDesign()
        design.pattern = .surprise
        design.yarn = .preset("mint")
        let data = try JSONEncoder().encode(design)
        #expect(try JSONDecoder().decode(KnitDesign.self, from: data) == design)
    }
}
