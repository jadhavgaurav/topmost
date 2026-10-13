import Cocoa
import ApplicationServices
import CoreGraphics

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

/// A window found by `WindowDetector`, with the accessibility element used to track and raise it.
public struct DetectedWindow {
    public let identity: WindowIdentity
    public let info: WindowInfo
    public let element: AXUIElement
}

/// Responsible for detecting the frontmost application and identifying its focused window.
public final class WindowDetector {
    public static let shared = WindowDetector()

    private var lastNonTopmostApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?

    public init() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            self.lastNonTopmostApp = front
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self?.lastNonTopmostApp = app
            }
        }
    }

    deinit {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    /// Resolves the application whose focused window should be targeted.
    private func resolveTargetApp() -> NSRunningApplication? {
        let myPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            return front
        }
        if let last = lastNonTopmostApp, !last.isTerminated {
            return last
        }
        // Fallback: inspect on-screen window list to find the frontmost non-Topmost application
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for entry in windowList {
                let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? (entry[kCGWindowLayer as String] as? Int) ?? -1
                guard layer == 0 else { continue }
                let pidVal = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? (entry[kCGWindowOwnerPID as String] as? Int32)
                guard let pid = pidVal, pid != myPID else { continue }
                if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
                    return app
                }
            }
        }
        return NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier != myPID && $0.activationPolicy == .regular
        })
    }

    /// Detects the currently focused window across all applications.
    public func detectFocusedWindow() -> DetectedWindow? {
        let myPID = ProcessInfo.processInfo.processIdentifier
        guard let frontApp = resolveTargetApp(), frontApp.processIdentifier != myPID else {
            NSLog("[Topmost] No target application could be resolved.")
            return nil
        }

        let pid = frontApp.processIdentifier
        let appElement = Accessibility.applicationElement(pid: pid)

        guard let winElement = focusedWindowElement(of: appElement) else { return nil }
        AXUIElementSetMessagingTimeout(winElement, Accessibility.messagingTimeout)

        // Frame from Accessibility (AX coordinates: origin at top-left of the main screen)
        guard let axPoint = Accessibility.point(from: Accessibility.copyAttribute(winElement, kAXPositionAttribute)),
              let axSize = Accessibility.size(from: Accessibility.copyAttribute(winElement, kAXSizeAttribute)),
              axSize.width > 30, axSize.height > 30 else {
            return nil
        }

        let windowID = resolveWindowID(of: winElement, pid: pid, axFrame: CGRect(origin: axPoint, size: axSize))
        guard windowID != 0 else { return nil }

        let appName = frontApp.localizedName ?? "Application"
        let identity = WindowIdentity(
            processID: pid,
            windowID: windowID,
            bundleIdentifier: frontApp.bundleIdentifier ?? "unknown.\(pid)",
            applicationName: appName,
            windowTitle: windowTitle(of: winElement, fallback: appName)
        )

        let info = WindowInfo(
            identity: identity,
            frame: axFrameToCocoaFrame(axPoint: axPoint, axSize: axSize),
            isMinimized: false,
            isOnScreen: true,
            windowLayer: 0
        )

        return DetectedWindow(identity: identity, info: info, element: winElement)
    }

    /// The focused window, falling back to the main window when the app reports no focused one.
    private func focusedWindowElement(of appElement: AXUIElement) -> AXUIElement? {
        if let focused = Accessibility.element(from: Accessibility.copyAttribute(appElement, kAXFocusedWindowAttribute)) {
            return focused
        }
        return Accessibility.element(from: Accessibility.copyAttribute(appElement, kAXMainWindowAttribute))
    }

    private func windowTitle(of element: AXUIElement, fallback: String) -> String {
        guard let title = Accessibility.copyAttribute(element, kAXTitleAttribute) as? String, !title.isEmpty else {
            return fallback
        }
        return title
    }

    private func resolveWindowID(of element: AXUIElement, pid: pid_t, axFrame: CGRect) -> CGWindowID {
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(element, &windowID) == .success, windowID != 0 {
            return windowID
        }
        return resolveWindowIDFromCGWindowList(pid: pid, axFrame: axFrame)
    }

    /// Converts AX top-left coordinates to Cocoa bottom-left coordinates
    public func axFrameToCocoaFrame(axPoint: CGPoint, axSize: CGSize) -> CGRect {
        // In Cocoa, the primary screen (screens.first) defines the 0,0 coordinate system at bottom-left
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 900
        let cocoaY = primaryScreenHeight - axPoint.y - axSize.height
        return CGRect(x: axPoint.x, y: cocoaY, width: axSize.width, height: axSize.height)
    }

    /// Converts Cocoa bottom-left coordinates to AX top-left coordinates
    public func cocoaFrameToAxFrame(cocoaFrame: CGRect) -> CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 900
        let axY = primaryScreenHeight - cocoaFrame.origin.y - cocoaFrame.size.height
        return CGRect(x: cocoaFrame.origin.x, y: axY, width: cocoaFrame.size.width, height: cocoaFrame.size.height)
    }

    /// Fallback matcher using CGWindowListCopyWindowInfo
    private func resolveWindowIDFromCGWindowList(pid: pid_t, axFrame: CGRect) -> CGWindowID {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }

        var candidateID: CGWindowID = 0
        var minDelta: CGFloat = .greatestFiniteMagnitude

        for info in list {
            let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? (info[kCGWindowOwnerPID as String] as? Int32)
            guard ownerPID == pid else { continue }

            let widVal = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? (info[kCGWindowNumber as String] as? UInt32)
            guard let wid = widVal, wid > 0 else { continue }

            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.int32Value ?? (info[kCGWindowLayer as String] as? Int32) ?? -1
            guard layer == 0 else { continue }

            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let winBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                // Compare bounds proximity
                let dx = abs(winBounds.origin.x - axFrame.origin.x)
                let dy = abs(winBounds.origin.y - axFrame.origin.y)
                let dw = abs(winBounds.size.width - axFrame.size.width)
                let dh = abs(winBounds.size.height - axFrame.size.height)
                let totalDelta = dx + dy + dw + dh

                if totalDelta < minDelta {
                    minDelta = totalDelta
                    candidateID = wid
                }
            }
        }

        // Proximity threshold: reject candidates that differ by more than 200px
        guard minDelta < 200 else { return 0 }
        return candidateID
    }
}
