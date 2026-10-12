import Cocoa
import ApplicationServices
import CoreGraphics

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Responsible for detecting the frontmost application and identifying its focused window.
public final class WindowDetector {
    public static let shared = WindowDetector()

    public init() {}

    /// Detects the currently focused window across all applications.
    public func detectFocusedWindow() -> (identity: WindowIdentity, info: WindowInfo, element: AXUIElement)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        // Avoid targeting Topmost itself
        let myPID = ProcessInfo.processInfo.processIdentifier
        if frontApp.processIdentifier == myPID {
            return nil
        }

        let pid = frontApp.processIdentifier
        let bundleID = frontApp.bundleIdentifier ?? "unknown.\(pid)"
        let appName = frontApp.localizedName ?? "Application"

        let appElement = AXUIElementCreateApplication(pid)

        // 1. Query kAXFocusedWindowAttribute
        var windowValue: AnyObject?
        var axResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)

        // Fallback: try kAXMainWindowAttribute if focused window is nil
        if axResult != .success || windowValue == nil {
            axResult = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &windowValue)
        }

        guard axResult == .success, let winObj = windowValue else {
            return nil
        }

        let winElement = winObj as! AXUIElement

        // 2. Query title
        var titleValue: AnyObject?
        var title = ""
        if AXUIElementCopyAttributeValue(winElement, kAXTitleAttribute as CFString, &titleValue) == .success,
           let t = titleValue as? String {
            title = t
        }
        if title.isEmpty {
            title = appName
        }

        // 3. Query frame from Accessibility (AX coordinates: origin at top-left of main screen)
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        var axPoint = CGPoint.zero
        var axSize = CGSize.zero

        if AXUIElementCopyAttributeValue(winElement, kAXPositionAttribute as CFString, &posValue) == .success,
           let val = posValue as! AXValue?,
           AXValueGetType(val) == .cgPoint {
            AXValueGetValue(val, .cgPoint, &axPoint)
        }

        if AXUIElementCopyAttributeValue(winElement, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let val = sizeValue as! AXValue?,
           AXValueGetType(val) == .cgSize {
            AXValueGetValue(val, .cgSize, &axSize)
        }

        guard axSize.width > 30, axSize.height > 30 else {
            return nil
        }

        let cocoaFrame = axFrameToCocoaFrame(axPoint: axPoint, axSize: axSize)

        // 4. Resolve CGWindowID
        var wid: CGWindowID = 0
        let getWidErr = _AXUIElementGetWindow(winElement, &wid)
        if getWidErr != .success || wid == 0 {
            wid = resolveWindowIDFromCGWindowList(pid: pid, axFrame: CGRect(origin: axPoint, size: axSize))
        }

        guard wid != 0 else {
            return nil
        }

        let identity = WindowIdentity(
            processID: pid,
            windowID: wid,
            bundleIdentifier: bundleID,
            applicationName: appName,
            windowTitle: title
        )

        let info = WindowInfo(
            identity: identity,
            frame: cocoaFrame,
            isMinimized: false,
            isOnScreen: true,
            windowLayer: 0
        )

        return (identity, info, winElement)
    }

    /// Converts AX top-left coordinates to Cocoa bottom-left coordinates
    public func axFrameToCocoaFrame(axPoint: CGPoint, axSize: CGSize) -> CGRect {
        // In Cocoa, the primary screen (screens.first) defines the 0,0 coordinate system at bottom-left
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaY = primaryScreenHeight - axPoint.y - axSize.height
        return CGRect(x: axPoint.x, y: cocoaY, width: axSize.width, height: axSize.height)
    }

    /// Converts Cocoa bottom-left coordinates to AX top-left coordinates
    public func cocoaFrameToAxFrame(cocoaFrame: CGRect) -> CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let axY = primaryScreenHeight - cocoaFrame.origin.y - cocoaFrame.size.height
        return CGRect(x: cocoaFrame.origin.x, y: axY, width: cocoaFrame.size.width, height: cocoaFrame.size.height)
    }

    /// Fallback matcher using CGWindowListCopyWindowInfo
    private func resolveWindowIDFromCGWindowList(pid: pid_t, axFrame: CGRect) -> CGWindowID {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }

        var candidateID: CGWindowID = 0
        var minDelta: CGFloat = .greatestFiniteMagnitude

        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else {
                continue
            }
            guard let wid = info[kCGWindowNumber as String] as? Int32 else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int32, layer == 0 else {
                continue
            }

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
                    candidateID = CGWindowID(wid)
                }
            }
        }

        return candidateID
    }
}
