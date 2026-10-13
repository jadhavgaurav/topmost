import Cocoa
import ApplicationServices

/// Monitors pinned windows for movement, resizing, minimization, and closure.
public final class WindowObserver {
    public static let shared = WindowObserver()

    public typealias MoveCallback = (WindowIdentity, CGRect) -> Void
    public typealias CloseCallback = (WindowIdentity) -> Void
    public typealias ActiveAppCallback = (pid_t) -> Void

    private var moveCallbacks: [WindowIdentity: MoveCallback] = [:]
    private var closeCallbacks: [WindowIdentity: CloseCallback] = [:]
    private var activeAppCallbacks: [ActiveAppCallback] = []

    private var observedElements: [WindowIdentity: AXUIElement] = [:]
    private var axObservers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    /// AX move/resize notifications arrive in bursts during a drag. Geometry checks are coalesced
    /// to at most one per interval so the main thread and WindowServer are never flooded.
    private static let minCheckInterval: CFTimeInterval = 1.0 / 240.0
    private var lastCheckTime: CFTimeInterval = 0

    /// Idle tracking is cheap and slow. While a pinned window is moving, tracking speeds up so the
    /// outline stays glued to it, then relaxes again once the window has been still for a moment.
    private static let idleInterval: TimeInterval = 0.1
    private static let motionInterval: TimeInterval = 1.0 / 120.0
    private static let motionLinger: CFTimeInterval = 0.4
    private var lastMotionTime: CFTimeInterval = 0
    private var isTrackingMotion = false
    private var lastKnownFrames: [WindowIdentity: CGRect] = [:]
    private var dragMonitor: Any?

    public init() {
        setupWorkspaceNotifications()
    }

    deinit {
        stopAll()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        // Application terminated
        let termObs = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleAppTerminated(pid: app.processIdentifier)
        }
        workspaceObservers.append(termObs)

        // Application activated
        let actObs = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleAppActivated(pid: app.processIdentifier)
        }
        workspaceObservers.append(actObs)
    }

    /// Register callbacks for a pinned window
    public func observe(
        identity: WindowIdentity,
        axElement: AXUIElement?,
        onMoved: @escaping MoveCallback,
        onClosed: @escaping CloseCallback
    ) {
        moveCallbacks[identity] = onMoved
        closeCallbacks[identity] = onClosed

        // Register AXObserver if possible
        registerAXObserver(for: identity, axElement: axElement)

        // Ensure lightweight tracking timer runs only when windows are pinned
        startTrackingTimerIfNeeded()
        installDragMonitorIfNeeded()
    }

    /// Stop observing a specific window
    public func stopObserving(identity: WindowIdentity) {
        moveCallbacks.removeValue(forKey: identity)
        closeCallbacks.removeValue(forKey: identity)
        lastKnownFrames.removeValue(forKey: identity)

        let pid = identity.processID
        if let obs = axObservers[pid], let element = observedElements.removeValue(forKey: identity) {
            AXObserverRemoveNotification(obs, element, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(obs, element, kAXResizedNotification as CFString)
            AXObserverRemoveNotification(obs, element, kAXUIElementDestroyedNotification as CFString)
        }

        // Check if any other windows for this PID exist
        let remainingForPID = moveCallbacks.keys.filter { $0.processID == pid }
        if remainingForPID.isEmpty {
            if let obs = axObservers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
            }
        }

        if moveCallbacks.isEmpty {
            stopTrackingTimer()
        }
    }

    public func onActiveAppChanged(_ callback: @escaping ActiveAppCallback) {
        activeAppCallbacks.append(callback)
    }

    private func registerAXObserver(for identity: WindowIdentity, axElement: AXUIElement?) {
        guard let winElement = axElement else { return }
        let pid = identity.processID
        observedElements[identity] = winElement

        let obs: AXObserver
        if let existing = axObservers[pid] {
            obs = existing
        } else {
            var newObserver: AXObserver?
            let err = AXObserverCreate(pid, { (observer, element, notification, refcon) in
                guard let refcon = refcon else { return }
                let observerSelf = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()
                observerSelf.handleAXNotification(notification: notification as String, element: element)
            }, &newObserver)

            guard err == .success, let created = newObserver else { return }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
            axObservers[pid] = created
            obs = created

            // Lets pinned overlays react when a different window of the same app takes focus.
            AXObserverAddNotification(created, AXUIElementCreateApplication(pid), kAXFocusedWindowChangedNotification as CFString,
                                      Unmanaged.passUnretained(self).toOpaque())
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(obs, winElement, kAXMovedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, winElement, kAXResizedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, winElement, kAXUIElementDestroyedNotification as CFString, selfPtr)
    }

    private func handleAXNotification(notification: String, element: AXUIElement) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if notification == (kAXFocusedWindowChangedNotification as String) {
                var pid: pid_t = 0
                if AXUIElementGetPid(element, &pid) == .success {
                    self.handleAppActivated(pid: pid)
                }
            } else if notification == (kAXUIElementDestroyedNotification as String) {
                self.checkWindowStates()
            } else if notification == (kAXMovedNotification as String) || notification == (kAXResizedNotification as String) {
                self.checkWindowStates()
            }
        }
    }

    private func startTrackingTimerIfNeeded() {
        guard pollTimer == nil else { return }
        installTrackingTimer(interval: Self.idleInterval)
    }

    private func installTrackingTimer(interval: TimeInterval) {
        pollTimer?.invalidate()
        // Common run loop mode so tracking continues during window drags and menu tracking.
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkWindowStates()
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        isTrackingMotion = (interval == Self.motionInterval)
    }

    private func stopTrackingTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
        isTrackingMotion = false
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
        }
    }

    /// A pointer drag anywhere is the earliest sign a pinned window may start moving, well before
    /// the window server reports new geometry. Switching to fast tracking at that moment keeps the
    /// outline attached from the very first frame. Mouse monitoring needs no extra permission.
    private func installDragMonitorIfNeeded() {
        guard dragMonitor == nil else { return }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.engageMotionTracking()
        }
    }

    private func engageMotionTracking() {
        guard pollTimer != nil else { return }
        lastMotionTime = CACurrentMediaTime()
        if !isTrackingMotion { installTrackingTimer(interval: Self.motionInterval) }
        checkWindowStates()
    }

    private func stopAll() {
        stopTrackingTimer()
        for (identity, element) in observedElements {
            if let obs = axObservers[identity.processID] {
                AXObserverRemoveNotification(obs, element, kAXMovedNotification as CFString)
                AXObserverRemoveNotification(obs, element, kAXResizedNotification as CFString)
                AXObserverRemoveNotification(obs, element, kAXUIElementDestroyedNotification as CFString)
            }
        }
        observedElements.removeAll()
        lastKnownFrames.removeAll()

        for (_, obs) in axObservers {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        axObservers.removeAll()
        moveCallbacks.removeAll()
        closeCallbacks.removeAll()
    }

    private func handleAppTerminated(pid: pid_t) {
        let targets = closeCallbacks.keys.filter { $0.processID == pid }
        var callbacksToInvoke: [(WindowIdentity, CloseCallback)] = []
        for target in targets {
            if let cb = closeCallbacks[target] {
                callbacksToInvoke.append((target, cb))
            }
            stopObserving(identity: target)
        }
        for (target, cb) in callbacksToInvoke {
            cb(target)
        }
    }

    private func handleAppActivated(pid: pid_t) {
        for callback in activeAppCallbacks {
            callback(pid)
        }
    }

    private enum WindowLookup {
        case gone
        case present(CGRect?)
    }

    /// Looks up a single window by ID. Targeted lookups avoid copying the system-wide window list,
    /// which would otherwise be repeated at the polling rate for every pinned window.
    private func lookupWindow(_ identity: WindowIdentity) -> WindowLookup {
        var rawID = UnsafeRawPointer(bitPattern: UInt(identity.windowID))
        guard let ids = CFArrayCreate(nil, &rawID, 1, nil),
              let descriptions = CGWindowListCreateDescriptionFromArray(ids) as? [[String: Any]],
              let entry = descriptions.first else {
            return .gone
        }

        let ownerPID = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        guard ownerPID == identity.processID else { return .gone }

        guard let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            return .present(nil)
        }
        return .present(bounds)
    }

    /// Verifies geometry of every observed window and reports closed ones.
    private func checkWindowStates() {
        guard !moveCallbacks.isEmpty else { return }

        let now = CACurrentMediaTime()
        guard now - lastCheckTime >= Self.minCheckInterval else { return }
        lastCheckTime = now

        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 900
        var closedTargets: [WindowIdentity] = []
        var anyMotion = false

        // Iterate over a snapshot so callbacks can never mutate the collection being enumerated.
        for (identity, callback) in Array(moveCallbacks) {
            switch lookupWindow(identity) {
            case .gone:
                closedTargets.append(identity)
            case .present(let bounds?):
                // Convert CGWindowBounds (top-left) to Cocoa screen coordinates (bottom-left)
                let cocoaY = primaryScreenHeight - bounds.origin.y - bounds.size.height
                let frame = CGRect(x: bounds.origin.x, y: cocoaY, width: bounds.size.width, height: bounds.size.height)
                if lastKnownFrames[identity] != frame {
                    lastKnownFrames[identity] = frame
                    anyMotion = true
                }
                callback(identity, frame)
            case .present(nil):
                continue
            }
        }

        for identity in closedTargets {
            let closeCb = closeCallbacks[identity]
            stopObserving(identity: identity)
            closeCb?(identity)
        }

        updateTrackingRate(anyMotion: anyMotion, now: now)
    }

    private func updateTrackingRate(anyMotion: Bool, now: CFTimeInterval) {
        guard pollTimer != nil else { return }
        if anyMotion {
            lastMotionTime = now
            if !isTrackingMotion { installTrackingTimer(interval: Self.motionInterval) }
        } else if isTrackingMotion, now - lastMotionTime > Self.motionLinger {
            installTrackingTimer(interval: Self.idleInterval)
        }
    }
}
