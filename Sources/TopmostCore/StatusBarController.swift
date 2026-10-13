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

        let titleItem = NSMenuItem(title: "Topmost", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeToggleItem())
        menu.addItem(makePinnedWindowsItem())
        menu.addItem(makeUnpinAllItem())
        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(title: "Settings…", action: #selector(openSettingsAction), key: ","))
        menu.addItem(makeItem(title: "About Topmost", action: #selector(openAboutAction)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "Quit Topmost", action: #selector(quitAction), key: "q"))
    }

    private func makeItem(title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func makeToggleItem() -> NSMenuItem {
        let shortcut = HotkeyManager.stringRepresentation(
            modifiers: settings.hotkeyModifiers,
            keyCode: settings.hotkeyCode
        )
        let item = makeItem(title: "Pin / Unpin Current Window", action: #selector(togglePinAction))
        item.toolTip = "Toggle Always on Top for focused window (\(shortcut))"
        return item
    }

    private func makePinnedWindowsItem() -> NSMenuItem {
        let pinnedItem = NSMenuItem(title: "Pinned Windows", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()

        if pinManager.pinnedIdentities.isEmpty {
            let emptyItem = NSMenuItem(title: "No Pinned Windows", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            subMenu.addItem(emptyItem)
        } else {
            for identity in pinManager.pinnedIdentities {
                let windowTitle = identity.windowTitle.isEmpty ? identity.applicationName : identity.windowTitle
                let item = makeItem(
                    title: "\(identity.applicationName) – \(windowTitle)",
                    action: #selector(unpinSpecificWindow(_:))
                )
                item.representedObject = identity
                subMenu.addItem(item)
            }
        }

        pinnedItem.submenu = subMenu
        return pinnedItem
    }

    private func makeUnpinAllItem() -> NSMenuItem {
        let item = makeItem(title: "Unpin All Windows", action: #selector(unpinAllAction))
        item.isEnabled = !pinManager.pinnedIdentities.isEmpty
        return item
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
