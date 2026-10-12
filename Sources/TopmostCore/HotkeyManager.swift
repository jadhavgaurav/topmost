import Cocoa
import Carbon

/// Global hotkey manager using Carbon RegisterEventHotKey.
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    public typealias HotkeyAction = () -> Void

    private var primaryHotKeyRef: EventHotKeyRef?
    private var unpinRecentHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private var onPrimaryTriggered: HotkeyAction?
    private var onUnpinRecentTriggered: HotkeyAction?

    private let signature: OSType = 0x544F504D // "TOPM"
    private let primaryID: UInt32 = 1
    private let unpinRecentID: UInt32 = 2

    private let settings: SettingsManager

    public init(settings: SettingsManager = .shared) {
        self.settings = settings
    }

    deinit {
        unregisterAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }

    /// Install the event dispatcher handler once
    public func setup(
        onPrimary: @escaping HotkeyAction,
        onUnpinRecent: HotkeyAction? = nil
    ) {
        self.onPrimaryTriggered = onPrimary
        self.onUnpinRecentTriggered = onUnpinRecent

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let event = event, let userData = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if err == noErr {
                    DispatchQueue.main.async {
                        if hotKeyID.id == manager.primaryID {
                            manager.onPrimaryTriggered?()
                        } else if hotKeyID.id == manager.unpinRecentID {
                            manager.onUnpinRecentTriggered?()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        if status != noErr {
            NSLog("[Topmost] Failed to install Carbon event handler: %d", status)
        }

        registerCurrentHotkeys()
    }

    /// Registers the current hotkeys according to settings
    public func registerCurrentHotkeys() {
        unregisterAll()

        // Register primary toggle hotkey
        let primaryStatus = register(
            keyCode: settings.hotkeyCode,
            modifiers: settings.hotkeyModifiers,
            id: primaryID,
            refOut: &primaryHotKeyRef
        )
        if primaryStatus != noErr {
            NSLog("[Topmost] Failed to register primary hotkey: %d", primaryStatus)
        }

        // Register optional unpin-recent hotkey if enabled
        if settings.unpinRecentEnabled {
            let unpinStatus = register(
                keyCode: settings.unpinRecentCode,
                modifiers: settings.unpinRecentModifiers,
                id: unpinRecentID,
                refOut: &unpinRecentHotKeyRef
            )
            if unpinStatus != noErr {
                NSLog("[Topmost] Failed to register unpin-recent hotkey: %d", unpinStatus)
            }
        }
    }

    private func register(
        keyCode: UInt32,
        modifiers: UInt32,
        id: UInt32,
        refOut: inout EventHotKeyRef?
    ) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        return RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &refOut
        )
    }

    public func unregisterAll() {
        if let ref = primaryHotKeyRef {
            UnregisterEventHotKey(ref)
            primaryHotKeyRef = nil
        }
        if let ref = unpinRecentHotKeyRef {
            UnregisterEventHotKey(ref)
            unpinRecentHotKeyRef = nil
        }
    }

    /// Format modifiers and key code into human-readable string
    public static func stringRepresentation(modifiers: UInt32, keyCode: UInt32) -> String {
        var str = ""
        if modifiers & UInt32(controlKey) != 0 { str += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { str += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { str += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { str += "⌘" }

        str += keyString(for: keyCode)
        return str
    }

    private static func keyString(for keyCode: UInt32) -> String {
        switch keyCode {
        case 35: return "P"
        case 32: return "U"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 33: return "["
        case 34: return "I"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 41: return ";"
        case 45: return "N"
        case 46: return "M"
        case 48: return "⇥"
        case 49: return "Space"
        default: return "Key(\(keyCode))"
        }
    }
}
