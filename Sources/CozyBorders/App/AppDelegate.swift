import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = PreferencesStore.shared
    let tracker = WindowTracker()
    private(set) lazy var coordinator = StackingCoordinator(store: store)
    private var statusMenu: StatusMenuController!
    private var onboarding: OnboardingWindowController?
    private var preferencesWindow: PreferencesWindowController?
    private var trustObserver: NSObjectProtocol?
    private var trustTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenuController(app: self)

        NotificationCenter.default.addObserver(forName: PreferencesStore.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.preferencesDidChange()
        }
        coordinator.onStrategyFallback = { [weak self] in
            self?.statusMenu.refresh()
        }

        // Prompt exactly once. After that, a missing grant shows onboarding instead of the
        // system dialog.
        let shouldPrompt = !store.hasPromptedForAccessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: shouldPrompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        store.hasPromptedForAccessibility = true

        if trusted {
            startBorders()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stop()
        coordinator.removeAllBorders()
    }

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    // MARK: Borders

    private func startBorders() {
        tracker.delegate = coordinator
        tracker.excludedBundleIDs = Set(store.preferences.excludedBundleIDs)
        tracker.start()
        statusMenu.refresh()
    }

    private func preferencesDidChange() {
        tracker.excludedBundleIDs = Set(store.preferences.excludedBundleIDs)
        coordinator.preferencesDidChange()
        statusMenu.refresh()
        preferencesWindow?.reload()
    }

    // MARK: Accessibility onboarding

    func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController()
        }
        onboarding?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        waitForTrust()
    }

    private func waitForTrust() {
        guard trustObserver == nil else { return }
        // The system posts this when the Accessibility list changes. The grant can take a
        // moment to apply, so check shortly after, and keep a slow check running only while
        // onboarding is on screen in case the notification never arrives.
        trustObserver = DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.apple.accessibility.api"),
                                                                             object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.checkTrust() }
        }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkTrust()
        }
    }

    private func checkTrust() {
        guard AXIsProcessTrusted() else { return }
        if let trustObserver { DistributedNotificationCenter.default().removeObserver(trustObserver) }
        trustObserver = nil
        trustTimer?.invalidate()
        trustTimer = nil
        onboarding?.close()
        onboarding = nil
        startBorders()
    }

    // MARK: Preferences

    func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(store: store)
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
