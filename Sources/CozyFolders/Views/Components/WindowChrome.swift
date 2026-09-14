import AppKit
import SwiftUI

extension View {
    /// Lets the content (and its knitted frame) run to the window's edges.
    ///
    /// An empty toolbar makes the title bar tall enough to hold the traffic lights, which are
    /// then nudged off the knitted band onto the paper, level with the title. The toolbar's own
    /// background is hidden so the knit shows through.
    func knittedWindowChrome(trafficLightOffset: CGSize) -> some View {
        self
            .toolbar { ChromeSpacer() }
            .modifier(HiddenToolbarBackground())
            .background(TitleBarConfigurator(trafficLightOffset: trafficLightOffset))
    }
}

private struct HiddenToolbarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            content.toolbarBackground(.hidden, for: .windowToolbar)
        }
    }
}

/// The toolbar needs one item to exist. On macOS 26 every item gets a glass capsule, which
/// would show as a sliver through the title, so hide it there.
private struct ChromeSpacer: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            item.sharedBackgroundVisibility(.hidden)
        } else {
            item
        }
    }

    private var item: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

/// AppKit bits SwiftUI doesn't expose: a transparent, title-less title bar with content
/// underneath, and traffic lights moved in from the window edge.
private struct TitleBarConfigurator: NSViewRepresentable {
    let trafficLightOffset: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            context.coordinator.attach(to: window, offset: trafficLightOffset)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var original: [NSWindow.ButtonType: NSPoint] = [:]
        private var observers: [NSObjectProtocol] = []

        func attach(to window: NSWindow, offset: CGSize) {
            let apply = { [weak self, weak window] in
                guard let self, let window else { return }
                self.moveButtons(in: window, by: offset)
            }
            apply()
            // AppKit lays the buttons out again on resize and when the window changes key state.
            for name in [NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification,
                         NSWindow.didResignKeyNotification, NSWindow.didExitFullScreenNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { _ in
                    MainActor.assumeIsolated { apply() }
                })
            }
        }

        private func moveButtons(in window: NSWindow, by offset: CGSize) {
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(type) else { continue }
                // Remember where AppKit put it, then place it relative to that — idempotent
                // whether or not AppKit has reset it in between.
                let base = original[type] ?? button.frame.origin
                original[type] = base
                // The title bar's coordinates are y-up, so moving down subtracts.
                let target = NSPoint(x: base.x + offset.width, y: base.y - offset.height)
                if button.frame.origin != target { button.setFrameOrigin(target) }
            }
        }

        deinit {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
        }
    }
}
