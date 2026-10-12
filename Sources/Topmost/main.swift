import Cocoa
import TopmostCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Topmost] Application launched.")

        // 1. Initial permission check
        PermissionManager.shared.checkPermissions()

        // 2. Setup Global Hotkey
        HotkeyManager.shared.setup(
            onPrimary: {
                PinManager.shared.togglePinCurrentWindow()
            },
            onUnpinRecent: {
                PinManager.shared.unpinMostRecent()
            }
        )

        // 3. Setup Status Bar Controller
        StatusBarController.shared.setup(
            onOpenSettings: {
                SettingsWindowController.shared.showSettings()
            },
            onOpenAbout: {
                SettingsWindowController.shared.showSettings()
            }
        )

        // 4. If permissions are missing on first run, show settings to guide user
        if !PermissionManager.shared.hasAccessibilityPermission {
            NSLog("[Topmost] Accessibility permission missing, prompting...")
            PermissionManager.shared.requestAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[Topmost] Application terminating, cleaning up active pins...")
        PinManager.shared.unpinAll()
        HotkeyManager.shared.unregisterAll()
    }
}

// MARK: - Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Run as menu bar accessory without Dock icon
app.run()
