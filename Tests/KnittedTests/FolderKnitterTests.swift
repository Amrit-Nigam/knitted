import Foundation
import KnitCore
import Testing
@testable import Knitted

/// NSWorkspace icon calls aren't thread-safe; the app makes them on the main thread, so do the tests.
@MainActor
@Suite(.serialized)
struct FolderKnitterTests {
    let knitter = FolderKnitter.forTests

    /// The reported bug: re-knitting must take the old sweater off before putting the new one
    /// on, so the folder's custom-icon flag actually changes and the Desktop redraws.
    @Test func reknittingClearsTheOldIconBeforeSettingTheNewOne() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let recorder = RecordingIconWriter()
        let knitter = FolderKnitter(writer: recorder, settleDelay: .milliseconds(80))

        try #require(await knitter.knit(work, with: .blueFairIsle))
        #expect(recorder.kinds == [.set], "a first knit has nothing to clear")

        recorder.calls.removeAll()
        try #require(await knitter.knit(work, with: .mintChevron))
        #expect(recorder.kinds == [.clear, .set])

        recorder.calls.removeAll()
        try #require(await knitter.knit(work, with: .blueFairIsle))
        #expect(recorder.kinds == [.clear, .set])
    }

    /// Clearing and re-setting in one go isn't enough for the Desktop: the folder has to rest
    /// bare for a moment. Every rewear waits, and the whole batch waits only once.
    @Test func reknittingRestsTheFolderBeforeTheNewSweater() async throws {
        let sandbox = try Sandbox()
        let folders = [try sandbox.folder("A"), try sandbox.folder("B"), try sandbox.folder("C")]
        let recorder = RecordingIconWriter()
        let knitter = FolderKnitter(writer: recorder, settleDelay: .milliseconds(300))

        let firstTime = ContinuousClock.now
        let first = await knitter.knit(folders.map { ($0, .blueFairIsle) })
        #expect(first.count == 3)
        #expect(ContinuousClock.now - firstTime < .milliseconds(300), "first knits have nothing to wait for")

        recorder.calls.removeAll()
        let secondTime = ContinuousClock.now
        let second = await knitter.knit(folders.map { ($0, .mintChevron) })
        let elapsed = ContinuousClock.now - secondTime
        #expect(second.count == 3)
        #expect(recorder.kinds == [.clear, .clear, .clear, .set, .set, .set], "take all off, then put all on")
        let lastClear = try #require(recorder.calls.last { $0.kind == .clear }?.at)
        let firstSet = try #require(recorder.calls.first { $0.kind == .set }?.at)
        #expect(firstSet - lastClear >= .milliseconds(300))
        #expect(elapsed < .milliseconds(900), "one wait for the whole batch, not one per folder")
    }

    @Test func aBatchWithFailuresKnitsTheRest() async throws {
        let sandbox = try Sandbox()
        let good = try sandbox.folder("Good")
        let file = try sandbox.file("not-a-folder.txt")
        let missing = sandbox.root.appendingPathComponent("missing")

        let done = await knitter.knit([(good, .blueFairIsle), (file, .blueFairIsle), (missing, .blueFairIsle)])
        #expect(done == [good])
    }

    @Test func knittingAFolderGivesItACustomIcon() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")

        #expect(await knitter.knit(work, with: .blueFairIsle))
        #expect(FolderKnitter.hasCustomIcon(work))
        #expect(IconInspector.hasCustomIconFlag(work))
        #expect(IconInspector.storedIconDigest(work) != nil)
    }

    @Test func reknittingReplacesTheStoredIcon() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")

        try #require(await knitter.knit(work, with: .blueFairIsle))
        let first = try #require(IconInspector.storedIconDigest(work))

        try #require(await knitter.knit(work, with: .mintChevron))
        let second = try #require(IconInspector.storedIconDigest(work))

        #expect(first != second)
        #expect(IconInspector.hasCustomIconFlag(work))
    }

    @Test func storedIconLooksLikeTheSweater() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        try #require(await knitter.knit(work, with: .blueFairIsle))

        let matching = try #require(IconInspector.colorDistance(of: work, to: .blueFairIsle))
        let other = try #require(IconInspector.colorDistance(of: work, to: .mintChevron))
        #expect(matching < 0.05)
        #expect(other > matching * 3)
    }

    @Test func reknittingManyTimesAlwaysEndsOnTheLatestSweater() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        let sweaters: [FolderSweater] = [.blueFairIsle, .mintChevron, .blueFairIsle, .mintChevron, .blueFairIsle]
        for (round, sweater) in sweaters.enumerated() {
            try #require(await knitter.knit(work, with: sweater))
            let current = try #require(IconInspector.colorDistance(of: work, to: sweater))
            let previous = try #require(IconInspector.colorDistance(of: work, to: sweater == .blueFairIsle ? .mintChevron : .blueFairIsle))
            #expect(current < previous, "round \(round): the folder should show the sweater just applied")
        }
    }

    @Test func unknittingRestoresTheNormalIcon() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        try #require(await knitter.knit(work, with: .blueFairIsle))

        #expect(knitter.unknit(work))
        #expect(!FolderKnitter.hasCustomIcon(work))
        #expect(!IconInspector.hasCustomIconFlag(work))
    }

    @Test func unknittingAPlainFolderIsHarmless() async throws {
        let sandbox = try Sandbox()
        let plain = try sandbox.folder("Plain")
        knitter.unknit(plain)
        #expect(!FolderKnitter.hasCustomIcon(plain))
        #expect(FileManager.default.fileExists(atPath: plain.path))
    }

    @Test func knittingKeepsTheFolderContents() async throws {
        let sandbox = try Sandbox()
        let work = try sandbox.folder("Work")
        try Data("notes".utf8).write(to: work.appendingPathComponent("notes.txt"))

        try #require(await knitter.knit(work, with: .blueFairIsle))
        try #require(await knitter.knit(work, with: .mintChevron))
        knitter.unknit(work)

        let contents = try FileManager.default.contentsOfDirectory(atPath: work.path)
        #expect(contents == ["notes.txt"])
    }

    @Test func onlyRealFoldersAreKnittable() async throws {
        let sandbox = try Sandbox()
        #expect(FolderKnitter.isKnittable(try sandbox.folder("Folder")))
        #expect(!FolderKnitter.isKnittable(try sandbox.file("file.txt")))
        #expect(!FolderKnitter.isKnittable(try sandbox.package("Something")))
        #expect(!FolderKnitter.isKnittable(sandbox.root.appendingPathComponent("missing")))

        let file = try sandbox.file("other.txt")
        let fileKnitted = await knitter.knit(file, with: .blueFairIsle)
        let missingKnitted = await knitter.knit(sandbox.root.appendingPathComponent("missing"), with: .blueFairIsle)
        #expect(!fileKnitted)
        #expect(!missingKnitted)
    }

    @Test func foldersWithUnusualNamesWork() async throws {
        let sandbox = try Sandbox()
        for name in ["goa-trip", "side gig", "Ünïcødé 🧶", "dots.in.name"] {
            let folder = try sandbox.folder(name)
            #expect(await knitter.knit(folder, with: .mintChevron), "\(name)")
            #expect(FolderKnitter.hasCustomIcon(folder), "\(name)")
        }
    }
}
