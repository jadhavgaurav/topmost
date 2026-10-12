import Cocoa
import ApplicationServices

/// Custom view that displays the live captured window surface and handles user interaction.
final class FloatingMirrorView: NSView {
    var onClick: (() -> Void)?
    var onForwardClick: ((CGPoint) -> Void)?
    private let displayLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        displayLayer.contentsGravity = .resizeAspectFill
        displayLayer.cornerRadius = 10.0
        displayLayer.masksToBounds = true
        displayLayer.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.addSublayer(displayLayer)
    }

    override func layout() {
        super.layout()
        displayLayer.frame = bounds
    }

    func updateSurface(_ surface: IOSurface) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.contents = surface
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onClick?()
        onForwardClick?(location)
    }

    override func rightMouseDown(with event: NSEvent) {
        onClick?()
    }
}

/// Floating non-activating window hosting the live mirrored window content.
public final class FloatingWindowController: NSObject, WindowCaptureManagerDelegate {
    public let identity: WindowIdentity
    public var axElement: AXUIElement?

    private var panel: NSPanel?
    private var mirrorView: FloatingMirrorView?
    private var captureManager: WindowCaptureManager?
    private let settings: SettingsManager
    private var currentFrame: CGRect

    public init(
        identity: WindowIdentity,
        initialFrame: CGRect,
        axElement: AXUIElement?,
        settings: SettingsManager = .shared
    ) {
        self.identity = identity
        self.currentFrame = initialFrame
        self.axElement = axElement
        self.settings = settings
        super.init()

        setupPanel(frame: initialFrame)
        startCapture(frame: initialFrame)
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
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = FloatingMirrorView(frame: p.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        view.onClick = { [weak self] in
            self?.handleOverlayClick()
        }

        p.contentView = view
        self.mirrorView = view
        self.panel = p

        p.orderFront(nil)
    }

    private func startCapture(frame: CGRect) {
        let capture = WindowCaptureManager(windowID: identity.windowID, settings: settings)
        capture.delegate = self
        self.captureManager = capture

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        Task {
            do {
                try await capture.start(initialSize: frame.size, scaleFactor: scale)
            } catch {
                NSLog("[Topmost] Capture start error for window %d: %@", identity.windowID, error.localizedDescription)
            }
        }
    }

    /// Update frame when source window moves or resizes
    public func updateFrame(_ newFrame: CGRect) {
        self.currentFrame = newFrame
        panel?.setFrame(newFrame, display: true, animate: false)

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        captureManager?.updateDimensions(size: newFrame.size, scaleFactor: scale)
    }

    /// Called when the active frontmost application changes
    public func updateSourceActiveState(isSourceActive: Bool) {
        guard let panel = panel else { return }
        if isSourceActive {
            // When source app is active, real window is in front. Make mirror click-through.
            panel.ignoresMouseEvents = true
        } else {
            // When another app is active, floating mirror sits on top and intercepts clicks to bring source forward
            panel.ignoresMouseEvents = false
            panel.orderFront(nil)
        }
    }

    private func handleOverlayClick() {
        switch settings.overlayClickBehavior {
        case .bringSourceForward:
            bringSourceToForeground()
        case .forwardClick:
            bringSourceToForeground()
        }
    }

    /// Activate the source application and raise the source window
    public func bringSourceToForeground() {
        if let app = NSRunningApplication(processIdentifier: identity.processID) {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
        if let element = axElement {
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        }
    }

    public func close() {
        captureManager?.stop()
        captureManager = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        mirrorView = nil
    }

    // MARK: - WindowCaptureManagerDelegate
    public func captureManager(_ manager: WindowCaptureManager, didOutputIOSurface surface: IOSurface) {
        DispatchQueue.main.async { [weak self] in
            self?.mirrorView?.updateSurface(surface)
        }
    }

    public func captureManager(_ manager: WindowCaptureManager, didFailWithError error: Error) {
        NSLog("[Topmost] Capture stream error: %@", error.localizedDescription)
    }
}
