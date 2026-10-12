import Foundation
import CoreGraphics

/// Snapshot of window dimensions and system properties.
public struct WindowInfo: Sendable, Equatable, CustomStringConvertible {
    public let identity: WindowIdentity
    public var frame: CGRect // Screen coordinates (Cocoa bottom-left origin)
    public var isMinimized: Bool
    public var isOnScreen: Bool
    public var windowLayer: Int32

    public init(
        identity: WindowIdentity,
        frame: CGRect,
        isMinimized: Bool = false,
        isOnScreen: Bool = true,
        windowLayer: Int32 = 0
    ) {
        self.identity = identity
        self.frame = frame
        self.isMinimized = isMinimized
        self.isOnScreen = isOnScreen
        self.windowLayer = windowLayer
    }

    public var description: String {
        return "WindowInfo(\(identity.applicationName) frame: \(frame), layer: \(windowLayer))"
    }
}

/// Errors that can occur during window pinning or unpinning.
public enum PinError: Error, LocalizedError, Sendable, Equatable {
    case noFocusedWindow
    case unsupportedWindow(String)
    case permissionDenied(String)
    case captureFailed(String)
    case alreadyPinned(WindowIdentity)
    case notPinned(WindowIdentity)

    public var errorDescription: String? {
        switch self {
        case .noFocusedWindow:
            return "No focused application window was detected."
        case .unsupportedWindow(let reason):
            return "The selected window cannot be pinned: \(reason)"
        case .permissionDenied(let permission):
            return "Required permission is not granted: \(permission)"
        case .captureFailed(let details):
            return "Failed to initialize window capture: \(details)"
        case .alreadyPinned(let identity):
            return "Window is already pinned: \(identity.windowTitle)"
        case .notPinned(let identity):
            return "Window is not currently pinned: \(identity.windowTitle)"
        }
    }
}
