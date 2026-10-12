import Cocoa
import ApplicationServices
import CoreGraphics

/// Manages macOS Accessibility and Screen Recording privacy permissions.
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var hasAccessibilityPermission: Bool = false
    @Published public private(set) var hasScreenRecordingPermission: Bool = false

    private var pollTimer: Timer?

    public init() {
        checkPermissions()
    }

    /// Check current permission statuses
    public func checkPermissions() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    /// Start a periodic check timer while onboarding or settings is open
    public func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    /// Stop the check timer
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Request Accessibility permission from macOS
    public func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    /// Request Screen Recording permission from macOS
    public func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    /// Open macOS Accessibility Privacy Settings directly
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open macOS Screen Recording Privacy Settings directly
    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
