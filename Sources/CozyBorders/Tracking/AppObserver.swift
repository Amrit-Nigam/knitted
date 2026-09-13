import ApplicationServices
import Foundation

/// Accessibility push notifications for one running app.
///
/// App-level notifications are registered on the application element; move / resize /
/// minimise / destroy are registered on each window element as windows are discovered.
final class AppObserver {
    enum Event {
        /// Geometry or visibility changed: re-enumerate soon.
        case windowsChanged
        /// Focus or stacking may have changed: re-enumerate and re-stack.
        case focusChanged
    }

    let pid: pid_t
    let application: AXUIElement
    private var observer: AXObserver?
    private let handler: (AppObserver, Event) -> Void
    private var attempts = 0
    private var invalidated = false

    private static let appNotifications = [
        kAXWindowCreatedNotification,
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXApplicationActivatedNotification,
    ]

    private static let windowNotifications = [
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXUIElementDestroyedNotification,
    ]

    init(pid: pid_t, handler: @escaping (AppObserver, Event) -> Void) {
        self.pid = pid
        self.application = AXUIElementCreateApplication(pid)
        self.handler = handler
        // Don't let a hung app stall the main thread.
        AXUIElementSetMessagingTimeout(application, 0.25)
        attach()
    }

    deinit {
        invalidate()
    }

    /// Removes the run loop source. Must happen before this object goes away, because the
    /// C callback holds an unretained pointer to it.
    func invalidate() {
        guard !invalidated else { return }
        invalidated = true
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
    }

    private func attach() {
        guard !invalidated else { return }
        attempts += 1

        var created: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let me = Unmanaged<AppObserver>.fromOpaque(refcon).takeUnretainedValue()
            me.received(notification as String, element: element)
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else {
            retryLater()
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var failedWhileLaunching = false
        for name in Self.appNotifications {
            let result = AXObserverAddNotification(created, application, name as CFString, refcon)
            if result == .cannotComplete { failedWhileLaunching = true }
        }
        // Apps that are still launching refuse with kAXErrorCannotComplete. Retry with backoff.
        if failedWhileLaunching {
            retryLater()
            return
        }

        observer = created
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        for window in AX.windows(ofApplication: application) {
            watch(window: window)
        }
    }

    private func retryLater() {
        guard attempts < 3 else { return }
        let delay = 0.25 * pow(2, Double(attempts - 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.attach()
        }
    }

    private func watch(window: AXUIElement) {
        guard let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.windowNotifications {
            // Already-registered errors are harmless.
            AXObserverAddNotification(observer, window, name as CFString, refcon)
        }
    }

    private func received(_ notification: String, element: AXUIElement) {
        guard !invalidated else { return }
        switch notification {
        case kAXWindowCreatedNotification:
            watch(window: element)
            handler(self, .focusChanged)
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXApplicationActivatedNotification:
            handler(self, .focusChanged)
        default:
            handler(self, .windowsChanged)
        }
    }
}
