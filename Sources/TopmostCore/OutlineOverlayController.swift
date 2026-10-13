import Cocoa

/// Custom transparent view that renders the configurable pin outline.
final class OutlineView: NSView {
    var outlineColor: NSColor = NSColor(srgbRed: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) { // #007AFF
        didSet { needsDisplay = true }
    }

    var outlineThickness: CGFloat = 3.0 {
        didSet { needsDisplay = true }
    }

    var cornerRadius: CGFloat = 10.0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let inset = outlineThickness / 2.0
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }

        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.lineWidth = outlineThickness
        outlineColor.setStroke()
        path.stroke()
    }
}

/// Floating non-interactive panel displaying the visual outline feedback around a pinned window.
public final class OutlineOverlayController {
    public let identity: WindowIdentity
    private var panel: NSPanel?
    private var outlineView: OutlineView?
    private let settings: SettingsManager

    public init(identity: WindowIdentity, initialFrame: CGRect, settings: SettingsManager = .shared) {
        self.identity = identity
        self.settings = settings
        setupPanel(frame: initialFrame)
    }

    deinit {
        close()
    }

    private func setupPanel(frame: CGRect) {
        let p = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        // Outline window must sit above the floating mirror window (floating.rawValue + 1)
        p.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        p.collectionBehavior = settings.overlayCollectionBehavior

        let view = OutlineView(frame: p.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        applySettings(to: view)

        p.contentView = view
        self.outlineView = view
        self.panel = p

        if settings.showOutline {
            p.orderFront(nil)
        }
    }

    /// Update outline position and dimensions when source window moves/resizes
    public func updateFrame(_ newFrame: CGRect) {
        guard let panel = panel else { return }
        if panel.frame.size == newFrame.size {
            panel.setFrameOrigin(newFrame.origin)
        } else {
            panel.setFrame(newFrame, display: true, animate: false)
        }
    }

    /// Re-apply visual preferences (thickness, color, visibility)
    public func refreshPreferences() {
        guard let view = outlineView, let panel = panel else { return }
        applySettings(to: view)
        if settings.showOutline {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    /// Update space behavior when settings change
    public func refreshSpaceBehavior() {
        guard let panel = panel else { return }
        panel.collectionBehavior = settings.overlayCollectionBehavior
    }

    private func applySettings(to view: OutlineView) {
        view.outlineThickness = CGFloat(settings.outlineThickness)
        view.outlineColor = NSColor.from(hex: settings.outlineColorHex) ?? NSColor(srgbRed: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
    }

    public func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        outlineView = nil
    }
}

// MARK: - Color Hex Helper
extension NSColor {
    public static func from(hex: String) -> NSColor? {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6 else { return nil }
        guard cleanHex.allSatisfy({ $0.isHexDigit }) else { return nil }

        var rgbValue: UInt64 = 0
        let scanner = Scanner(string: cleanHex)
        guard scanner.scanHexInt64(&rgbValue), scanner.isAtEnd else { return nil }

        return NSColor(
            srgbRed: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
