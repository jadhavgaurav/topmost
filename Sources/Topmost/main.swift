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
                SettingsWindowController.shared.showSettings(initialTab: 0)
            },
            onOpenAbout: {
                SettingsWindowController.shared.showSettings(initialTab: 4)
            }
        )

        // 4. Show the settings window on launch
        let hasAllPermissions = PermissionManager.shared.hasAccessibilityPermission && PermissionManager.shared.hasScreenRecordingPermission
        let initialTab = hasAllPermissions ? 0 : 3
        SettingsWindowController.shared.showSettings(initialTab: initialTab)

        // 5. If permissions are missing on first run, prompt user
        if !PermissionManager.shared.hasAccessibilityPermission {
            NSLog("[Topmost] Accessibility permission missing, prompting...")
            PermissionManager.shared.requestAccessibility()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.showSettings(initialTab: 0)
        return true
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
