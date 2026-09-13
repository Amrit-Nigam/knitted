import AppKit

/// Explains why Accessibility access is needed and deep-links to the right settings pane.
final class OnboardingWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Cozy Borders"
        window.isReleasedWhenClosed = false
        self.init(window: window)

        let icon = NSImageView(image: YarnBallIcon.image(size: 48, template: false))
        let title = NSTextField(labelWithString: "Let Cozy Borders see your windows")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
        To knit a border around each window, Cozy Borders needs to know where your windows are \
        and when they move. macOS gates that behind Accessibility access.

        It never reads what's inside your windows, and it doesn't need Screen Recording.
        """)
        body.preferredMaxLayoutWidth = 400

        let open = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettings))
        open.keyEquivalent = "\r"
        let quit = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))

        let hint = NSTextField(labelWithString: "Borders appear as soon as access is switched on.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)

        let buttons = NSStackView(views: [quit, open])
        buttons.spacing = 12
        let stack = NSStackView(views: [icon, title, body, hint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.setCustomSpacing(18, after: hint)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.center()
    }

    @objc private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A little ball of yarn, drawn in code so there's no asset catalog to build.
enum YarnBallIcon {
    static func image(size: CGFloat, template: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let s = rect.width
            let ball = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
            let color = template ? NSColor.black : NSColor(srgbRed: 0.82, green: 0.42, blue: 0.3, alpha: 1)
            let line = template ? NSColor.black : NSColor(srgbRed: 0.45, green: 0.2, blue: 0.14, alpha: 1)

            let circle = NSBezierPath(ovalIn: ball)
            if template {
                circle.lineWidth = s * 0.08
                line.setStroke()
                circle.stroke()
            } else {
                color.setFill()
                circle.fill()
            }

            // Wound strands.
            NSGraphicsContext.saveGraphicsState()
            circle.addClip()
            line.setStroke()
            for i in 0..<3 {
                let p = NSBezierPath()
                let offset = CGFloat(i) * s * 0.2
                p.move(to: NSPoint(x: s * 0.05, y: s * 0.35 + offset))
                p.curve(to: NSPoint(x: s * 0.95, y: s * 0.15 + offset),
                        controlPoint1: NSPoint(x: s * 0.35, y: s * 0.1 + offset),
                        controlPoint2: NSPoint(x: s * 0.65, y: s * 0.45 + offset))
                p.lineWidth = s * 0.06
                p.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()

            // Loose end.
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: s * 0.78, y: s * 0.8))
            tail.curve(to: NSPoint(x: s * 0.98, y: s * 0.98), controlPoint1: NSPoint(x: s * 0.95, y: s * 0.8), controlPoint2: NSPoint(x: s * 0.8, y: s * 0.98))
            tail.lineWidth = s * 0.07
            tail.lineCapStyle = .round
            line.setStroke()
            tail.stroke()
            return true
        }
        image.isTemplate = template
        return image
    }
}
