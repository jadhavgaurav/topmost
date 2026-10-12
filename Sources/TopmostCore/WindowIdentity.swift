import Foundation
import CoreGraphics

/// Stable runtime identity for an application window.
public struct WindowIdentity: Hashable, Identifiable, Sendable, Codable, CustomStringConvertible {
    public let id: String
    public let processID: pid_t
    public let windowID: CGWindowID
    public let bundleIdentifier: String
    public let applicationName: String
    public let windowTitle: String

    public init(
        processID: pid_t,
        windowID: CGWindowID,
        bundleIdentifier: String,
        applicationName: String,
        windowTitle: String
    ) {
        self.processID = processID
        self.windowID = windowID
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.id = "\(bundleIdentifier):\(processID):\(windowID)"
    }

    public var description: String {
        return "WindowIdentity(\(applicationName) [PID: \(processID), WID: \(windowID)] \"\(windowTitle)\")"
    }

    public func hash(into hasher: inout Hasher) {
        // Hash based on owning process and window ID for deterministic matching
        hasher.combine(processID)
        hasher.combine(windowID)
        hasher.combine(bundleIdentifier)
    }

    public static func == (lhs: WindowIdentity, rhs: WindowIdentity) -> Bool {
        return lhs.processID == rhs.processID &&
               lhs.windowID == rhs.windowID &&
               lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
