import CoreGraphics
import Testing
@testable import KnitCore

/// Arrangement under test (Quartz, y down):
///
///   secondary 1920×1080 at (-240, -1080)  — sits directly above the primary
///   primary   1440×900  at (0, 0)
///   right     1280×1024 at (1440, 200)    — offset downward
struct CoordinateSpaceTests {
    let primaryHeight: CGFloat = 900

    @Test func windowOnPrimary() {
        let quartz = CGRect(x: 100, y: 50, width: 400, height: 300)
        let appKit = CoordinateSpace.appKitRect(fromQuartz: quartz, primaryDisplayHeight: primaryHeight)
        #expect(appKit == CGRect(x: 100, y: 550, width: 400, height: 300))
    }

    @Test func windowOnDisplayAbovePrimary() {
        // 80pt below the top of the secondary display.
        let quartz = CGRect(x: 100, y: -1000, width: 500, height: 400)
        let appKit = CoordinateSpace.appKitRect(fromQuartz: quartz, primaryDisplayHeight: primaryHeight)
        // Secondary in AppKit spans y 900...1980, so its top edge is 1980; window top = 1900.
        #expect(appKit.maxY == 1900)
        #expect(appKit == CGRect(x: 100, y: 1500, width: 500, height: 400))

        let secondaryAppKit = CoordinateSpace.appKitRect(fromQuartz: CGRect(x: -240, y: -1080, width: 1920, height: 1080),
                                                         primaryDisplayHeight: primaryHeight)
        #expect(secondaryAppKit == CGRect(x: -240, y: 900, width: 1920, height: 1080))
        #expect(secondaryAppKit.contains(appKit))
    }

    @Test func windowStraddlingPrimaryAndDisplayAbove() {
        let quartz = CGRect(x: 0, y: -100, width: 300, height: 250)
        let appKit = CoordinateSpace.appKitRect(fromQuartz: quartz, primaryDisplayHeight: primaryHeight)
        #expect(appKit == CGRect(x: 0, y: 750, width: 300, height: 250))
    }

    @Test func windowOnLowerRightDisplay() {
        let quartz = CGRect(x: 1500, y: 1000, width: 200, height: 200)
        let appKit = CoordinateSpace.appKitRect(fromQuartz: quartz, primaryDisplayHeight: primaryHeight)
        #expect(appKit == CGRect(x: 1500, y: -300, width: 200, height: 200))
    }

    @Test func windowHangingOffScreenEdge() {
        let quartz = CGRect(x: -150, y: 700, width: 400, height: 400)
        let appKit = CoordinateSpace.appKitRect(fromQuartz: quartz, primaryDisplayHeight: primaryHeight)
        #expect(appKit == CGRect(x: -150, y: -200, width: 400, height: 400))
    }

    @Test(arguments: [
        CGRect(x: 10, y: 20, width: 30, height: 40),
        CGRect(x: -240, y: -1080, width: 1920, height: 1080),
        CGRect(x: 1440.5, y: 200.25, width: 1280, height: 1024),
    ])
    func roundTrip(_ rect: CGRect) {
        let there = CoordinateSpace.appKitRect(fromQuartz: rect, primaryDisplayHeight: primaryHeight)
        #expect(CoordinateSpace.quartzRect(fromAppKit: there, primaryDisplayHeight: primaryHeight) == rect)
    }
}
