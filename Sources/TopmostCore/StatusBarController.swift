import Cocoa
import Combine

/// Manages the native macOS menu bar status item and context menu.
public final class StatusBarController: NSObject, NSMenuDelegate {
    public static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private let pinManager: PinManager
    private let settings: SettingsManager
    private var cancellables = Set<AnyCancellable>()
    private var onOpenSettings: (() -> Void)?
    private var onOpenAbout: (() -> Void)?

    public init(
        pinManager: PinManager = .shared,
        settings: SettingsManager = .shared
    ) {
        self.pinManager = pinManager
        self.settings = settings
        super.init()

        setupSubscriptions()
    }

    public func setup(onOpenSettings: @escaping () -> Void, onOpenAbout: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout

        if settings.showMenuBarIcon {
            createStatusItem()
        }
    }

    private func setupSubscriptions() {
        settings.$showMenuBarIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show {
                    self?.createStatusItem()
                } else {
                    self?.removeStatusItem()
                }
            }
            .store(in: &cancellables)

        pinManager.$pinnedIdentities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
    }

    private func createStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Topmost")
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let hasPins = !pinManager.pinnedIdentities.isEmpty
        let iconName = hasPins ? "pin.fill" : "pin"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Topmost")
    }

    // MARK: - NSMenuDelegate
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. App Title Header
        let titleItem = NSMenuItem(title: "Topmost", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Pin/Unpin Current Window Action
        let shortcutStr = HotkeyManager.stringRepresentation(
            modifiers: settings.hotkeyModifiers,
            keyCode: settings.hotkeyCode
        )
        let toggleItem = NSMenuItem(
            title: "Pin / Unpin Current Window",
            action: #selector(togglePinAction),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.toolTip = "Toggle Always on Top for focused window (\(shortcutStr))"
        menu.addItem(toggleItem)

        // 3. Pinned Windows Submenu
        let pinnedItem = NSMenuItem(title: "Pinned Windows", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()

        if pinManager.pinnedIdentities.isEmpty {
            let emptyItem = NSMenuItem(title: "No Pinned Windows", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            subMenu.addItem(emptyItem)
        } else {
            for identity in pinManager.pinnedIdentities {
                let winTitle = identity.windowTitle.isEmpty ? identity.applicationName : identity.windowTitle
                let item = NSMenuItem(
                    title: "\(identity.applicationName) – \(winTitle)",
                    action: #selector(unpinSpecificWindow(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = identity
                subMenu.addItem(item)
            }
        }
        pinnedItem.submenu = subMenu
        menu.addItem(pinnedItem)

        // 4. Unpin All
        let unpinAllItem = NSMenuItem(
            title: "Unpin All Windows",
            action: #selector(unpinAllAction),
            keyEquivalent: ""
        )
        unpinAllItem.target = self
        unpinAllItem.isEnabled = !pinManager.pinnedIdentities.isEmpty
        menu.addItem(unpinAllItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Settings
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 6. About
        let aboutItem = NSMenuItem(
            title: "About Topmost",
            action: #selector(openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // 7. Quit
        let quitItem = NSMenuItem(
            title: "Quit Topmost",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func togglePinAction() {
        // Dispatch with brief delay to allow status menu to dismiss and keyboard/window focus to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.pinManager.togglePinCurrentWindow()
        }
    }

    @objc private func unpinSpecificWindow(_ sender: NSMenuItem) {
        if let identity = sender.representedObject as? WindowIdentity {
            pinManager.unpin(identity)
        }
    }

    @objc private func unpinAllAction() {
        pinManager.unpinAll()
    }

    @objc private func openSettingsAction() {
        onOpenSettings?()
    }

    @objc private func openAboutAction() {
        onOpenAbout?()
    }

    @objc private func quitAction() {
        pinManager.unpinAll()
        NSApplication.shared.terminate(nil)
    }
}
