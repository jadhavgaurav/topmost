import Cocoa
import ApplicationServices

/// Custom view that displays the live captured window surface and handles user interaction.
final class FloatingMirrorView: NSView {
    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onMouseUp: ((NSEvent) -> Void)?
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
        displayLayer.contentsGravity = .resize
        displayLayer.cornerRadius = 10.0
        displayLayer.masksToBounds = true
        displayLayer.backgroundColor = NSColor.clear.cgColor
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event)
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUp?(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }
}

/// Floating non-activating window hosting the live mirrored window content.
///
/// Safety rule: the panel never intercepts mouse events until the first captured frame has been
/// presented. A mirror that has nothing to show (capture failed, permission stale, window gone)
/// would otherwise be an invisible rectangle that swallows every click beneath it.
public final class FloatingWindowController: NSObject, WindowCaptureManagerDelegate {
    public let identity: WindowIdentity
    public var axElement: AXUIElement?

    /// Invoked on the main thread when capture cannot start or stops unexpectedly.
    /// The owner is expected to dismiss this controller.
    public var onCaptureFailure: ((WindowIdentity) -> Void)?

    /// Invoked on the main thread while the user drags the mirror, with the frame the window is
    /// being dragged to, so sibling overlays (the outline) can follow instantly.
    public var onGestureFrameChange: ((CGRect) -> Void)?

    /// True while the user is dragging the pinned window by its mirror. Source-window position
    /// reports are stale during that time and must not move the overlays back.
    public var isUserMovingWindow: Bool { gesture?.didDrag == true }

    private static let resizeDebounce: TimeInterval = 0.1

    private var panel: NSPanel?
    private var mirrorView: FloatingMirrorView?
    private var captureManager: WindowCaptureManager?
    private let settings: SettingsManager
    private var currentFrame: CGRect

    private var isSourceActive = false
    private var hasPresentedFrame = false
    private var pendingResize: DispatchWorkItem?

    // Latest-frame-wins hand-off between the capture queue and the main thread.
    private let frameLock = NSLock()
    private var pendingSurface: IOSurface?
    private var presentationScheduled = false

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
        p.ignoresMouseEvents = true
        p.collectionBehavior = settings.overlayCollectionBehavior

        let view = FloatingMirrorView(frame: p.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        view.onMouseDown = { [weak self] event in
            self?.handleMouseDown(event)
        }
        view.onMouseDragged = { [weak self] event in
            self?.handleMouseDragged(event)
        }
        view.onMouseUp = { [weak self] event in
            self?.handleMouseUp(event)
        }

        p.contentView = view
        self.mirrorView = view
        self.panel = p

        // Check whether the source app is currently frontmost
        let isFront = (NSWorkspace.shared.frontmostApplication?.processIdentifier == identity.processID)
        updateSourceActiveState(isSourceActive: isFront)
    }

    private func bestScreen(for frame: CGRect) -> NSScreen? {
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func startCapture(frame: CGRect) {
        let capture = WindowCaptureManager(windowID: identity.windowID, settings: settings)
        capture.delegate = self
        self.captureManager = capture

        let scale = bestScreen(for: frame)?.backingScaleFactor ?? 2.0
        Task { @MainActor [weak self] in
            do {
                try await capture.start(initialSize: frame.size, scaleFactor: scale)
            } catch {
                // Ignore failures from a capture that was already replaced or closed.
                guard let self = self, self.captureManager === capture else { return }
                NSLog("[Topmost] Capture start error for window %d: %@", self.identity.windowID, error.localizedDescription)
                self.onCaptureFailure?(self.identity)
            }
        }
    }

    /// Update frame when source window moves or resizes
    public func updateFrame(_ newFrame: CGRect, sizeChanged: Bool = true) {
        self.currentFrame = newFrame
        if let panel = panel {
            if panel.frame.size == newFrame.size {
                panel.setFrameOrigin(newFrame.origin)
            } else {
                panel.setFrame(newFrame, display: true, animate: false)
            }
        }

        if sizeChanged {
            scheduleCaptureResize()
        }
    }

    /// Resizing a window emits many size changes; only the settled size needs a new stream configuration.
    private func scheduleCaptureResize() {
        pendingResize?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let scale = self.bestScreen(for: self.currentFrame)?.backingScaleFactor ?? 2.0
            self.captureManager?.updateDimensions(size: self.currentFrame.size, scaleFactor: scale)
        }
        pendingResize = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.resizeDebounce, execute: work)
    }

    /// Update space behavior when settings change
    public func refreshSpaceBehavior() {
        guard let panel = panel else { return }
        panel.collectionBehavior = settings.overlayCollectionBehavior
    }

    /// Refresh capture stream performance parameters
    public func refreshCaptureSettings() {
        let scale = bestScreen(for: currentFrame)?.backingScaleFactor ?? 2.0
        captureManager?.refreshConfiguration(size: currentFrame.size, scaleFactor: scale)
    }

    /// Called when the active frontmost application changes
    public func updateSourceActiveState(isSourceActive: Bool) {
        self.isSourceActive = isSourceActive
        applyInteractionState()
    }

    /// Decides whether the mirror is shown.
    ///
    /// When the pinned window is the focused window of the active app, the real window is already
    /// on top and is shown natively: no copy, no lag, real window controls. In every other case the
    /// mirror floats above everything and intercepts presses so they can be handed to the real window.
    private func applyInteractionState() {
        guard let panel = panel else { return }

        // Never block clicks while there is no picture to show.
        guard hasPresentedFrame else {
            panel.ignoresMouseEvents = true
            return
        }

        // Activating the source app flips it to "active" mid-press. The mirror must keep receiving
        // the rest of that press (drag and release), otherwise the gesture is lost half way.
        if gesture != nil {
            panel.ignoresMouseEvents = false
            panel.orderFront(nil)
            return
        }

        if isSourceActive && isSourceWindowFocused() {
            panel.orderOut(nil)
        } else {
            panel.ignoresMouseEvents = false
            panel.orderFront(nil)
        }
    }

    /// True when the pinned window is the focused window of its application.
    private func isSourceWindowFocused() -> Bool {
        guard let element = axElement else { return true }
        let appElement = Accessibility.applicationElement(pid: identity.processID)
        guard let focused = Accessibility.copyAttribute(appElement, kAXFocusedWindowAttribute) else { return false }
        return CFEqual(focused, element)
    }

    // MARK: - Interaction forwarding

    /// Height of the strip, measured from the top of the mirror, that counts as the title bar / toolbar.
    private static let dragStripHeight: CGFloat = 44
    /// Pointer travel (in points) below which a press is treated as a click rather than a drag.
    private static let dragThreshold: CGFloat = 3

    private struct Gesture {
        let startPoint: CGPoint
        let startWindowOrigin: CGPoint?
        let startPanelFrame: CGRect
        var didDrag = false
    }

    private var gesture: Gesture?
    private static let sourceMoveInterval: CFTimeInterval = 1.0 / 60.0
    private var lastSourceMoveTime: CFTimeInterval = 0
    private var pendingSourceOrigin: CGPoint?

    /// A press on the mirror means the user is aiming at the real window underneath.
    /// The source app is brought forward immediately. A drag that starts in the title strip then
    /// moves the real window through Accessibility, and a plain click is replayed onto the real
    /// window once it is active, so the mirror never makes the window feel dead.
    private func handleMouseDown(_ event: NSEvent) {
        bringSourceToForeground()

        guard settings.overlayClickBehavior == .forwardClick, event.type == .leftMouseDown else { return }

        let inTitleStrip = event.locationInWindow.y >= (panel?.frame.height ?? 0) - Self.dragStripHeight
        gesture = Gesture(
            startPoint: screenPoint(for: event),
            startWindowOrigin: inTitleStrip ? sourceWindowOrigin() : nil,
            startPanelFrame: panel?.frame ?? .zero
        )
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard var current = gesture else { return }

        let point = screenPoint(for: event)
        let dx = point.x - current.startPoint.x
        let dy = point.y - current.startPoint.y

        if !current.didDrag, hypot(dx, dy) >= Self.dragThreshold {
            current.didDrag = true
            gesture = current
        }

        guard current.didDrag, let origin = current.startWindowOrigin else { return }

        // Move what the user sees right now; the real window is asked to follow, but never waited on.
        var frame = current.startPanelFrame
        frame.origin.x += dx
        frame.origin.y -= dy
        currentFrame = frame
        panel?.setFrameOrigin(frame.origin)
        onGestureFrameChange?(frame)

        let now = CACurrentMediaTime()
        if now - lastSourceMoveTime >= Self.sourceMoveInterval {
            lastSourceMoveTime = now
            setSourceWindowOrigin(CGPoint(x: origin.x + dx, y: origin.y + dy))
        }
        pendingSourceOrigin = CGPoint(x: origin.x + dx, y: origin.y + dy)
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard let finished = gesture else { return }
        gesture = nil
        NSLog("[Topmost] Overlay press ended for window %d (dragged: %@)", identity.windowID, finished.didDrag ? "yes" : "no")

        if finished.didDrag {
            // The throttled writes may have skipped the last position; land exactly where the pointer ended.
            if let final = pendingSourceOrigin { setSourceWindowOrigin(final) }
        } else {
            replayClick(at: screenPoint(for: event))
        }
        pendingSourceOrigin = nil
        applyInteractionState()
    }

    /// Re-issues a click at `point` so it lands on the real window rather than the mirror.
    private func replayClick(at point: CGPoint) {
        guard let panel = panel else { return }
        panel.ignoresMouseEvents = true

        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
                NSLog("[Topmost] Could not create replay mouse event for window %d", identity.windowID)
                return
            }
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.post(tap: .cghidEventTap)
        }
    }

    /// Pointer position in global display coordinates (origin top-left of the primary screen).
    /// Uses the global mouse location rather than the event's window-relative location: the mirror
    /// follows the source window while it is being dragged, so window-relative positions would
    /// shift under the pointer and feed back into the move.
    private func screenPoint(for event: NSEvent) -> CGPoint {
        let cocoaPoint = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: cocoaPoint.x, y: primaryHeight - cocoaPoint.y)
    }

    private func sourceWindowOrigin() -> CGPoint? {
        guard let element = axElement else { return nil }
        return Accessibility.point(from: Accessibility.copyAttribute(element, kAXPositionAttribute))
    }

    private func setSourceWindowOrigin(_ origin: CGPoint) {
        guard let element = axElement else { return }
        var target = origin
        guard let value = AXValueCreate(.cgPoint, &target) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    /// Activate the source application and raise the source window.
    ///
    /// `NSRunningApplication.activate()` is ignored on macOS 14+ when the caller is not the
    /// frontmost app, which Topmost never is. Setting AXFrontmost through the Accessibility API
    /// is not subject to that restriction.
    public func bringSourceToForeground() {
        let appElement = Accessibility.applicationElement(pid: identity.processID)
        let frontmostResult = AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        if frontmostResult != .success, let app = NSRunningApplication(processIdentifier: identity.processID) {
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
        pendingResize?.cancel()
        pendingResize = nil
        captureManager?.delegate = nil
        captureManager?.stop()
        captureManager = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        mirrorView = nil
    }

    // MARK: - WindowCaptureManagerDelegate
    public func captureManager(_ manager: WindowCaptureManager, didOutputIOSurface surface: IOSurface) {
        frameLock.lock()
        pendingSurface = surface
        let shouldSchedule = !presentationScheduled
        presentationScheduled = true
        frameLock.unlock()

        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            self?.presentPendingSurface()
        }
    }

    private func presentPendingSurface() {
        frameLock.lock()
        let surface = pendingSurface
        pendingSurface = nil
        presentationScheduled = false
        frameLock.unlock()

        guard let surface = surface, let mirrorView = mirrorView else { return }
        mirrorView.updateSurface(surface)

        if !hasPresentedFrame {
            hasPresentedFrame = true
            applyInteractionState()
        }
    }

    public func captureManager(_ manager: WindowCaptureManager, didFailWithError error: Error) {
        NSLog("[Topmost] Capture stream error: %@", error.localizedDescription)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.captureManager === manager else { return }
            self.onCaptureFailure?(self.identity)
        }
    }
}
