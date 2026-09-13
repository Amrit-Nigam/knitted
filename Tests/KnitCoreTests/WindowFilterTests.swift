import CoreGraphics
import Foundation
import Testing
@testable import KnitCore

struct WindowFilterTests {
    let displays = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

    func window(layer: Int = 0, frame: CGRect = CGRect(x: 10, y: 40, width: 600, height: 400), pid: pid_t = 42, alpha: Double = 1) -> WindowDescription {
        WindowDescription(id: 7, frame: frame, pid: pid, layer: layer, alpha: alpha)
    }

    @Test func acceptsOrdinaryWindow() {
        let filter = WindowFilter(ownPID: 1, displayBounds: displays)
        #expect(filter.accepts(window(), bundleID: "com.example.app"))
    }

    @Test func rejectsNonNormalLayers() {
        let filter = WindowFilter(ownPID: 1, displayBounds: displays)
        #expect(!filter.accepts(window(layer: 25), bundleID: nil))   // status items
        #expect(!filter.accepts(window(layer: 101), bundleID: nil))  // menus
    }

    @Test func rejectsSmallWindows() {
        let filter = WindowFilter(ownPID: 1, displayBounds: displays)
        #expect(!filter.accepts(window(frame: CGRect(x: 0, y: 30, width: 79, height: 300)), bundleID: nil))
        #expect(!filter.accepts(window(frame: CGRect(x: 0, y: 30, width: 300, height: 79)), bundleID: nil))
        #expect(filter.accepts(window(frame: CGRect(x: 0, y: 30, width: 80, height: 80)), bundleID: nil))
    }

    @Test func rejectsOwnProcess() {
        let filter = WindowFilter(ownPID: 42, displayBounds: displays)
        #expect(!filter.accepts(window(pid: 42), bundleID: nil))
    }

    @Test func rejectsExcludedApps() {
        let filter = WindowFilter(ownPID: 1, excludedBundleIDs: ["com.example.app"], displayBounds: displays)
        #expect(!filter.accepts(window(), bundleID: "com.example.app"))
        #expect(filter.accepts(window(), bundleID: "com.example.other"))
    }

    @Test func rejectsFullscreenAndInvisible() {
        let filter = WindowFilter(ownPID: 1, displayBounds: displays)
        #expect(!filter.accepts(window(frame: displays[0]), bundleID: nil))
        #expect(!filter.accepts(window(alpha: 0), bundleID: nil))
        // A zoomed window below the menu bar is not fullscreen.
        #expect(filter.accepts(window(frame: CGRect(x: 0, y: 33, width: 1440, height: 867)), bundleID: nil))
    }

    @Test func parsesWindowListEntry() {
        let info: [String: Any] = [
            kCGWindowNumber as String: 123 as NSNumber,
            kCGWindowOwnerPID as String: 456 as NSNumber,
            kCGWindowLayer as String: 0 as NSNumber,
            kCGWindowBounds as String: CGRect(x: 1, y: 2, width: 300, height: 400).dictionaryRepresentation,
        ]
        let parsed = WindowDescription(info: info)
        #expect(parsed == WindowDescription(id: 123, frame: CGRect(x: 1, y: 2, width: 300, height: 400), pid: 456, layer: 0))
    }
}
