import Cocoa
import SwiftUI

/// Window controller that presents the SwiftUI Settings window.
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    public init() {}

    public func showSettings(initialTab: Int = 0) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let w = NSWindow(contentViewController: hostingController)
        w.title = "Topmost Settings"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.setContentSize(NSSize(width: 520, height: 420))
        w.center()
        w.isReleasedWhenClosed = false

        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.close()
        window = nil
    }
}
