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

    private var axObservers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

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
    }

    /// Stop observing a specific window
    public func stopObserving(identity: WindowIdentity) {
        moveCallbacks.removeValue(forKey: identity)
        closeCallbacks.removeValue(forKey: identity)

        // Check if any other windows for this PID exist
        let remainingForPID = moveCallbacks.keys.filter { $0.processID == identity.processID }
        if remainingForPID.isEmpty {
            if let obs = axObservers.removeValue(forKey: identity.processID) {
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

        if axObservers[pid] == nil {
            var observer: AXObserver?
            let err = AXObserverCreate(pid, { (observer, element, notification, refcon) in
                guard let refcon = refcon else { return }
                let observerSelf = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()
                observerSelf.handleAXNotification(notification: notification as String, element: element)
            }, &observer)

            if err == .success, let obs = observer {
                let selfPtr = Unmanaged.passUnretained(self).toOpaque()
                AXObserverAddNotification(obs, winElement, kAXMovedNotification as CFString, selfPtr)
                AXObserverAddNotification(obs, winElement, kAXResizedNotification as CFString, selfPtr)
                AXObserverAddNotification(obs, winElement, kAXUIElementDestroyedNotification as CFString, selfPtr)

                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
                axObservers[pid] = obs
            }
        }
    }

    private func handleAXNotification(notification: String, element: AXUIElement) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if notification == (kAXUIElementDestroyedNotification as String) {
                self.checkWindowStates()
            } else if notification == (kAXMovedNotification as String) || notification == (kAXResizedNotification as String) {
                self.checkWindowStates()
            }
        }
    }

    private func startTrackingTimerIfNeeded() {
        guard pollTimer == nil else { return }
        // 10Hz lightweight poll only when windows are pinned
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkWindowStates()
        }
    }

    private func stopTrackingTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func stopAll() {
        stopTrackingTimer()
        for (_, obs) in axObservers {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        axObservers.removeAll()
        moveCallbacks.removeAll()
        closeCallbacks.removeAll()
    }

    private func handleAppTerminated(pid: pid_t) {
        let targets = closeCallbacks.keys.filter { $0.processID == pid }
        for target in targets {
            let cb = closeCallbacks[target]
            stopObserving(identity: target)
            cb?(target)
        }
    }

    private func handleAppActivated(pid: pid_t) {
        for callback in activeAppCallbacks {
            callback(pid)
        }
    }

    /// Query window list to verify geometry and active status
    private func checkWindowStates() {
        guard !moveCallbacks.isEmpty else { return }

        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0

        for (identity, callback) in moveCallbacks {
            // Find window by CGWindowID
            if let match = list.first(where: {
                ($0[kCGWindowNumber as String] as? Int32) == Int32(identity.windowID) &&
                ($0[kCGWindowOwnerPID as String] as? Int32) == identity.processID
            }) {
                if let boundsDict = match[kCGWindowBounds as String] as? [String: Any],
                   let winBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                    // Convert CGWindowBounds (top-left) to Cocoa screen coordinates (bottom-left)
                    let cocoaY = primaryScreenHeight - winBounds.origin.y - winBounds.size.height
                    let cocoaFrame = CGRect(x: winBounds.origin.x, y: cocoaY, width: winBounds.size.width, height: winBounds.size.height)
                    callback(identity, cocoaFrame)
                }
            } else {
                // Window disappeared / closed
                let closeCb = closeCallbacks[identity]
                stopObserving(identity: identity)
                closeCb?(identity)
            }
        }
    }
}
