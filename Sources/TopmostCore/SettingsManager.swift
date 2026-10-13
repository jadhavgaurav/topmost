import Foundation
import Combine
import Carbon

/// Overlay interaction behavior when clicking the floating representation.
public enum OverlayClickBehavior: String, CaseIterable, Identifiable, Codable, Sendable {
    case bringSourceForward = "bringSourceForward"
    case forwardClick = "forwardClick"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bringSourceForward:
            return "Bring Real Window Forward Only"
        case .forwardClick:
            return "Bring Forward and Pass Click Through (Recommended)"
        }
    }
}

/// Central user preferences manager backed by UserDefaults.
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private let defaults: UserDefaults

    // MARK: - Keys
    private enum Keys {
        static let launchAtLogin = "topmost.launchAtLogin"
        static let hotkeyModifiers = "topmost.hotkeyModifiers"
        static let hotkeyCode = "topmost.hotkeyCode"
        static let unpinRecentEnabled = "topmost.unpinRecentEnabled"
        static let unpinRecentModifiers = "topmost.unpinRecentModifiers"
        static let unpinRecentCode = "topmost.unpinRecentCode"
        static let showMenuBarIcon = "topmost.showMenuBarIcon"
        static let multiWindowPinning = "topmost.multiWindowPinning"
        static let overlayClickBehavior = "topmost.overlayClickBehavior"
        static let showAcrossSpaces = "topmost.showAcrossSpaces"
        static let showOutline = "topmost.showOutline"
        static let outlineColorHex = "topmost.outlineColorHex"
        static let outlineThickness = "topmost.outlineThickness"
        static let playSounds = "topmost.playSounds"
        static let soundVolume = "topmost.soundVolume"
        static let maxFrameRate = "topmost.maxFrameRate"
        static let lowResourceMode = "topmost.lowResourceMode"
        static let schemaVersion = "topmost.settingsSchemaVersion"
    }

    /// Bump when a default changes in a way that must override values persisted by older builds.
    /// Version 2: the overlay click default changed to passing the click through. Earlier builds
    /// saved their old default on every launch, which would otherwise mask the new one forever.
    private static let currentSchemaVersion = 2

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
        migrateIfNeeded()
        loadSettings()
    }

    private func migrateIfNeeded() {
        guard defaults.integer(forKey: Keys.schemaVersion) < Self.currentSchemaVersion else { return }
        defaults.removeObject(forKey: Keys.overlayClickBehavior)
        defaults.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.launchAtLogin: false,
            Keys.hotkeyModifiers: Int(cmdKey | controlKey),
            Keys.hotkeyCode: 35, // 'P'
            Keys.unpinRecentEnabled: false,
            Keys.unpinRecentModifiers: Int(cmdKey | controlKey),
            Keys.unpinRecentCode: 32, // 'U'
            Keys.showMenuBarIcon: true,
            Keys.multiWindowPinning: true,
            Keys.overlayClickBehavior: OverlayClickBehavior.forwardClick.rawValue,
            Keys.showAcrossSpaces: true,
            Keys.showOutline: true,
            Keys.outlineColorHex: "#007AFF",
            Keys.outlineThickness: 3.0,
            Keys.playSounds: true,
            Keys.soundVolume: 0.8,
            Keys.maxFrameRate: 30,
            Keys.lowResourceMode: false
        ])
    }

    private func loadSettings() {
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.hotkeyModifiers = UInt32(defaults.integer(forKey: Keys.hotkeyModifiers))
        self.hotkeyCode = UInt32(defaults.integer(forKey: Keys.hotkeyCode))
        self.unpinRecentEnabled = defaults.bool(forKey: Keys.unpinRecentEnabled)
        self.unpinRecentModifiers = UInt32(defaults.integer(forKey: Keys.unpinRecentModifiers))
        self.unpinRecentCode = UInt32(defaults.integer(forKey: Keys.unpinRecentCode))
        self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        self.multiWindowPinning = defaults.bool(forKey: Keys.multiWindowPinning)
        if let raw = defaults.string(forKey: Keys.overlayClickBehavior),
           let behavior = OverlayClickBehavior(rawValue: raw) {
            self.overlayClickBehavior = behavior
        } else {
            self.overlayClickBehavior = .forwardClick
        }
        self.showAcrossSpaces = defaults.bool(forKey: Keys.showAcrossSpaces)
        self.showOutline = defaults.bool(forKey: Keys.showOutline)
        self.outlineColorHex = defaults.string(forKey: Keys.outlineColorHex) ?? "#007AFF"
        self.outlineThickness = defaults.double(forKey: Keys.outlineThickness)
        self.playSounds = defaults.bool(forKey: Keys.playSounds)
        self.soundVolume = defaults.double(forKey: Keys.soundVolume)
        self.maxFrameRate = defaults.integer(forKey: Keys.maxFrameRate)
        self.lowResourceMode = defaults.bool(forKey: Keys.lowResourceMode)
    }

    // MARK: - Published Properties
    @Published public var launchAtLogin: Bool = false {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published public var hotkeyModifiers: UInt32 = UInt32(cmdKey | controlKey) {
        didSet { defaults.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers) }
    }

    @Published public var hotkeyCode: UInt32 = 35 { // 'P'
        didSet { defaults.set(Int(hotkeyCode), forKey: Keys.hotkeyCode) }
    }

    @Published public var unpinRecentEnabled: Bool = false {
        didSet { defaults.set(unpinRecentEnabled, forKey: Keys.unpinRecentEnabled) }
    }

    @Published public var unpinRecentModifiers: UInt32 = UInt32(cmdKey | controlKey) {
        didSet { defaults.set(Int(unpinRecentModifiers), forKey: Keys.unpinRecentModifiers) }
    }

    @Published public var unpinRecentCode: UInt32 = 32 { // 'U'
        didSet { defaults.set(Int(unpinRecentCode), forKey: Keys.unpinRecentCode) }
    }

    @Published public var showMenuBarIcon: Bool = true {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    @Published public var multiWindowPinning: Bool = true {
        didSet { defaults.set(multiWindowPinning, forKey: Keys.multiWindowPinning) }
    }

    @Published public var overlayClickBehavior: OverlayClickBehavior = .forwardClick {
        didSet { defaults.set(overlayClickBehavior.rawValue, forKey: Keys.overlayClickBehavior) }
    }

    @Published public var showAcrossSpaces: Bool = true {
        didSet { defaults.set(showAcrossSpaces, forKey: Keys.showAcrossSpaces) }
    }

    @Published public var showOutline: Bool = true {
        didSet { defaults.set(showOutline, forKey: Keys.showOutline) }
    }

    @Published public var outlineColorHex: String = "#007AFF" {
        didSet { defaults.set(outlineColorHex, forKey: Keys.outlineColorHex) }
    }

    @Published public var outlineThickness: Double = 3.0 {
        didSet {
            let clamped = min(max(outlineThickness, 1.0), 5.0)
            if outlineThickness != clamped {
                outlineThickness = clamped
            }
            defaults.set(clamped, forKey: Keys.outlineThickness)
        }
    }

    @Published public var playSounds: Bool = true {
        didSet { defaults.set(playSounds, forKey: Keys.playSounds) }
    }

    @Published public var soundVolume: Double = 0.8 {
        didSet {
            let clamped = min(max(soundVolume, 0.0), 1.0)
            if soundVolume != clamped {
                soundVolume = clamped
            }
            defaults.set(clamped, forKey: Keys.soundVolume)
        }
    }

    @Published public var maxFrameRate: Int = 30 {
        didSet { defaults.set(maxFrameRate, forKey: Keys.maxFrameRate) }
    }

    @Published public var lowResourceMode: Bool = false {
        didSet { defaults.set(lowResourceMode, forKey: Keys.lowResourceMode) }
    }

    /// Reset all settings to defaults
    public func resetToDefaults() {
        for key in [
            Keys.launchAtLogin, Keys.hotkeyModifiers, Keys.hotkeyCode,
            Keys.unpinRecentEnabled, Keys.unpinRecentModifiers, Keys.unpinRecentCode,
            Keys.showMenuBarIcon, Keys.multiWindowPinning, Keys.overlayClickBehavior,
            Keys.showAcrossSpaces, Keys.showOutline, Keys.outlineColorHex,
            Keys.outlineThickness, Keys.playSounds, Keys.soundVolume,
            Keys.maxFrameRate, Keys.lowResourceMode
        ] {
            defaults.removeObject(forKey: key)
        }
        registerDefaults()
        loadSettings()

        LoginItemManager.shared.setEnabled(false)
        HotkeyManager.shared.registerCurrentHotkeys()
        PinManager.shared.refreshVisualPreferences()
        PinManager.shared.refreshSpaceBehavior()
        PinManager.shared.refreshCaptureSettings()
    }
}
