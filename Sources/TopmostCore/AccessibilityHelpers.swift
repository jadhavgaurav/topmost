import Cocoa
import ApplicationServices

/// Shared Accessibility helpers. Attribute values come back as untyped CoreFoundation objects, so
/// every cast is guarded by a runtime type check here instead of being force-cast at each call site.
enum Accessibility {
    /// Accessibility calls block the calling thread until the target app answers (6s by default).
    /// A frozen target app must never be able to freeze Topmost's overlays with it.
    static let messagingTimeout: Float = 0.5

    /// An application element whose calls give up quickly if the app is unresponsive.
    static func applicationElement(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func element(from value: AnyObject?) -> AXUIElement? {
        guard let value = value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func point(from value: AnyObject?) -> CGPoint? {
        guard let value = value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    static func size(from value: AnyObject?) -> CGSize? {
        guard let value = value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }
}

extension SettingsManager {
    /// Whether overlay panels follow you across Spaces or stay on the Space they were created on.
    var overlayCollectionBehavior: NSWindow.CollectionBehavior {
        showAcrossSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.moveToActiveSpace, .fullScreenAuxiliary]
    }
}
