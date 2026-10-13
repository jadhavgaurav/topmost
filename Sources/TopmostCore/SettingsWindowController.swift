import Cocoa
import SwiftUI

extension Notification.Name {
    public static let topmostSwitchTab = Notification.Name("topmostSwitchTab")
}

/// Window controller that presents the SwiftUI Settings window.
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    public override init() {
        super.init()
    }

    public func showSettings(initialTab: Int = 0) {
        SettingsNavigationModel.shared.selectedTab = initialTab

        // Elevate to regular application so window pops right to the front
        NSApplication.shared.setActivationPolicy(.regular)

        if let w = window {
            w.center()
            w.orderFrontRegardless()
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
        w.delegate = self

        self.window = w
        w.orderFrontRegardless()
        w.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
        // Return to accessory mode when the window is closed
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    public func close() {
        window?.close()
        window = nil
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
