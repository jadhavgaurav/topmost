import Cocoa
import ApplicationServices
import Combine

/// Represents an active pinned window session.
final class PinnedSession {
    let identity: WindowIdentity
    var info: WindowInfo
    let outlineController: OutlineOverlayController
    let floatingController: FloatingWindowController
    let pinnedAt: Date

    init(
        identity: WindowIdentity,
        info: WindowInfo,
        outlineController: OutlineOverlayController,
        floatingController: FloatingWindowController,
        pinnedAt: Date = Date()
    ) {
        self.identity = identity
        self.info = info
        self.outlineController = outlineController
        self.floatingController = floatingController
        self.pinnedAt = pinnedAt
    }

    func close() {
        outlineController.close()
        floatingController.close()
    }
}

/// Central state manager coordinating window pinning, overlays, capture, and lifecycle.
public final class PinManager: ObservableObject {
    public static let shared = PinManager()

    @Published public private(set) var pinnedIdentities: [WindowIdentity] = []

    private var sessions: [WindowIdentity: PinnedSession] = [:]
    private let detector: WindowDetector
    private let observer: WindowObserver
    private let feedback: FeedbackManager
    private let settings: SettingsManager
    private let permissions: PermissionManager

    public init(
        detector: WindowDetector = .shared,
        observer: WindowObserver = .shared,
        feedback: FeedbackManager = .shared,
        settings: SettingsManager = .shared,
        permissions: PermissionManager = .shared
    ) {
        self.detector = detector
        self.observer = observer
        self.feedback = feedback
        self.settings = settings
        self.permissions = permissions

        setupActiveAppObserver()
    }

    deinit {
        unpinAll()
    }

    private func setupActiveAppObserver() {
        observer.onActiveAppChanged { [weak self] activePID in
            self?.handleActiveAppChanged(activePID: activePID)
        }
    }

    /// Toggles the pin state of the currently focused window
    public func togglePinCurrentWindow() {
        guard let detected = detector.detectFocusedWindow() else {
            NSLog("[Topmost] No focused window found to toggle")
            feedback.playErrorSound()
            return
        }

        if isPinned(detected.identity) {
            unpin(detected.identity)
        } else {
            pin(identity: detected.identity, info: detected.info, element: detected.element)
        }
    }

    /// Check if a window identity is currently pinned
    public func isPinned(_ identity: WindowIdentity) -> Bool {
        return sessions[identity] != nil
    }

    /// Pin a window
    public func pin(identity: WindowIdentity, info: WindowInfo, element: AXUIElement?) {
        // Enforce single-window pin if multi-window is disabled
        if !settings.multiWindowPinning && !sessions.isEmpty {
            unpinAll()
        }

        if sessions[identity] != nil {
            NSLog("[Topmost] Window is already pinned: %@", identity.description)
            return
        }

        NSLog("[Topmost] Pinning window: %@", identity.description)

        // 1. Create Outline Overlay
        let outline = OutlineOverlayController(
            identity: identity,
            initialFrame: info.frame,
            settings: settings
        )

        // 2. Create Floating Mirror Window
        let floating = FloatingWindowController(
            identity: identity,
            initialFrame: info.frame,
            axElement: element,
            settings: settings
        )

        // 3. Create Session
        let session = PinnedSession(
            identity: identity,
            info: info,
            outlineController: outline,
            floatingController: floating
        )
        sessions[identity] = session
        updatePinnedIdentities()

        // 4. Setup Observers
        observer.observe(
            identity: identity,
            axElement: element,
            onMoved: { [weak self] ident, newFrame in
                self?.handleWindowMoved(identity: ident, newFrame: newFrame)
            },
            onClosed: { [weak self] ident in
                self?.handleWindowClosed(identity: ident)
            }
        )

        // 5. Play confirmation sound
        feedback.playPinSound()
    }

    /// Unpin a specific window
    public func unpin(_ identity: WindowIdentity) {
        guard let session = sessions.removeValue(forKey: identity) else {
            return
        }

        NSLog("[Topmost] Unpinning window: %@", identity.description)

        observer.stopObserving(identity: identity)
        session.close()
        updatePinnedIdentities()

        feedback.playUnpinSound()
    }

    /// Unpin all currently pinned windows
    public func unpinAll() {
        guard !sessions.isEmpty else { return }

        NSLog("[Topmost] Unpinning all %d windows", sessions.count)
        for (identity, session) in sessions {
            observer.stopObserving(identity: identity)
            session.close()
        }
        sessions.removeAll()
        updatePinnedIdentities()

        feedback.playUnpinSound()
    }

    /// Unpin the most recently pinned window
    public func unpinMostRecent() {
        guard let mostRecent = sessions.values.max(by: { $0.pinnedAt < $1.pinnedAt }) else {
            return
        }
        unpin(mostRecent.identity)
    }

    /// Refresh visual preferences for all active outline overlays
    public func refreshVisualPreferences() {
        for session in sessions.values {
            session.outlineController.refreshPreferences()
        }
    }

    // MARK: - Event Handling
    private func handleWindowMoved(identity: WindowIdentity, newFrame: CGRect) {
        guard let session = sessions[identity] else { return }
        session.info.frame = newFrame
        session.outlineController.updateFrame(newFrame)
        session.floatingController.updateFrame(newFrame)
    }

    private func handleWindowClosed(identity: WindowIdentity) {
        NSLog("[Topmost] Pinned source window closed: %@", identity.description)
        if let session = sessions.removeValue(forKey: identity) {
            session.close()
            updatePinnedIdentities()
        }
    }

    private func handleActiveAppChanged(activePID: pid_t) {
        for (identity, session) in sessions {
            let isSourceActive = (identity.processID == activePID)
            session.floatingController.updateSourceActiveState(isSourceActive: isSourceActive)
        }
    }

    private func updatePinnedIdentities() {
        pinnedIdentities = Array(sessions.keys)
    }
}
