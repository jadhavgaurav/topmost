import Foundation
import CoreGraphics
import Cocoa
import Carbon
import TopmostCore

var passedCount = 0
var failedCount = 0

func assertTest(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passedCount += 1
        print("  ✓ \(message)")
    } else {
        failedCount += 1
        print("  ✗ FAILED: \(message) (\(file):\(line))")
    }
}

print("========================================")
print("Running Topmost Automated Test Suite")
print("========================================")

// MARK: - Test 1: Window Identity Matching & Deterministic Hashing
print("\n[Test 1] Window Identity Matching & Deterministic Hashing")
do {
    let id1 = WindowIdentity(processID: 100, windowID: 501, bundleIdentifier: "com.apple.TextEdit", applicationName: "TextEdit", windowTitle: "Notes.txt")
    let id2 = WindowIdentity(processID: 100, windowID: 501, bundleIdentifier: "com.apple.TextEdit", applicationName: "TextEdit", windowTitle: "Renamed Title")
    let id3 = WindowIdentity(processID: 101, windowID: 502, bundleIdentifier: "com.apple.Safari", applicationName: "Safari", windowTitle: "Apple")

    assertTest(id1 == id2, "Identities with same PID and windowID are equal")
    assertTest(id1 != id3, "Identities with different PID/WID are not equal")

    var set = Set<WindowIdentity>()
    set.insert(id1)
    assertTest(set.contains(id2), "Set recognizes identity regardless of title change")
    assertTest(!set.contains(id3), "Set does not falsely match different identity")
}

// MARK: - Test 2: WindowInfo Dimensions & Coordinate Conversions
print("\n[Test 2] WindowInfo Dimensions & Coordinate Conversions")
do {
    let detector = WindowDetector()
    let axPoint = CGPoint(x: 50, y: 100)
    let axSize = CGSize(width: 400, height: 300)

    let cocoaFrame = detector.axFrameToCocoaFrame(axPoint: axPoint, axSize: axSize)
    assertTest(cocoaFrame.origin.x == 50, "X coordinate matches")
    assertTest(cocoaFrame.size.width == 400, "Width matches")
    assertTest(cocoaFrame.size.height == 300, "Height matches")

    let convertedBack = detector.cocoaFrameToAxFrame(cocoaFrame: cocoaFrame)
    assertTest(convertedBack.origin.x == axPoint.x, "Converted back X matches")
    assertTest(convertedBack.origin.y == axPoint.y, "Converted back Y matches")
}

// MARK: - Test 3: Hotkey String Formatting & Normalization
print("\n[Test 3] Hotkey String Formatting & Normalization")
do {
    let pMods = UInt32(cmdKey | controlKey)
    let pStr = HotkeyManager.stringRepresentation(modifiers: pMods, keyCode: 35)
    assertTest(pStr.contains("⌃"), "Contains Control symbol")
    assertTest(pStr.contains("⌘"), "Contains Command symbol")
    assertTest(pStr.contains("P"), "Contains 'P' key")

    let uMods = UInt32(optionKey)
    let uStr = HotkeyManager.stringRepresentation(modifiers: uMods, keyCode: 32)
    assertTest(uStr.contains("⌥"), "Contains Option symbol")
    assertTest(uStr.contains("U"), "Contains 'U' key")
}

// MARK: - Test 4: Settings Persistence & Clamping
print("\n[Test 4] Settings Persistence & Clamping")
do {
    let testDefaults = UserDefaults(suiteName: "com.topmost.tests.\(UUID().uuidString)")!
    let settings = SettingsManager(defaults: testDefaults)

    settings.outlineThickness = 12.0
    assertTest(settings.outlineThickness == 5.0, "Thickness clamped to max 5.0")

    settings.outlineThickness = 0.2
    assertTest(settings.outlineThickness == 1.0, "Thickness clamped to min 1.0")

    settings.soundVolume = 2.0
    assertTest(settings.soundVolume == 1.0, "Volume clamped to max 1.0")

    settings.soundVolume = -0.5
    assertTest(settings.soundVolume == 0.0, "Volume clamped to min 0.0")

    let blue = NSColor.from(hex: "#007AFF")
    assertTest(blue != nil, "Valid hex parsed successfully")

    let invalid = NSColor.from(hex: "not-a-color")
    assertTest(invalid == nil, "Invalid hex rejected cleanly")
}

// MARK: - Test 5: Pin State Transitions
print("\n[Test 5] Pin State Transitions")
do {
    let pinManager = PinManager.shared
    let id = WindowIdentity(processID: 2001, windowID: 9001, bundleIdentifier: "com.test.app", applicationName: "TestApp", windowTitle: "TestWin")
    let info = WindowInfo(identity: id, frame: CGRect(x: 10, y: 10, width: 300, height: 200))

    assertTest(!pinManager.isPinned(id), "Window initially not pinned")

    pinManager.pin(identity: id, info: info, element: nil)
    assertTest(pinManager.isPinned(id), "Window is pinned after pin()")
    assertTest(pinManager.pinnedIdentities.contains(id), "Identity listed in active pins")

    pinManager.unpin(id)
    assertTest(!pinManager.isPinned(id), "Window is unpinned after unpin()")
    assertTest(!pinManager.pinnedIdentities.contains(id), "Identity removed from active pins")
}

// MARK: - Test 6: Multiple Pinned Windows & Unpin All
print("\n[Test 6] Multiple Pinned Windows & Unpin All")
do {
    let pinManager = PinManager.shared
    let idA = WindowIdentity(processID: 3001, windowID: 101, bundleIdentifier: "app.A", applicationName: "AppA", windowTitle: "WinA")
    let idB = WindowIdentity(processID: 3002, windowID: 102, bundleIdentifier: "app.B", applicationName: "AppB", windowTitle: "WinB")

    let infoA = WindowInfo(identity: idA, frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    let infoB = WindowInfo(identity: idB, frame: CGRect(x: 210, y: 0, width: 200, height: 200))

    pinManager.pin(identity: idA, info: infoA, element: nil)
    pinManager.pin(identity: idB, info: infoB, element: nil)

    assertTest(pinManager.isPinned(idA), "Window A is pinned")
    assertTest(pinManager.isPinned(idB), "Window B is pinned")
    assertTest(pinManager.pinnedIdentities.count >= 2, "Multiple pins supported concurrently")

    pinManager.unpinAll()
    assertTest(!pinManager.isPinned(idA), "Window A unpinned after unpinAll")
    assertTest(!pinManager.isPinned(idB), "Window B unpinned after unpinAll")
    assertTest(pinManager.pinnedIdentities.isEmpty, "Active pins list is empty")
}

// MARK: - Test 7: Unpin Most Recent
print("\n[Test 7] Unpin Most Recent")
do {
    let pinManager = PinManager.shared
    let idFirst = WindowIdentity(processID: 4001, windowID: 201, bundleIdentifier: "first.app", applicationName: "FirstApp", windowTitle: "First")
    let idSecond = WindowIdentity(processID: 4002, windowID: 202, bundleIdentifier: "second.app", applicationName: "SecondApp", windowTitle: "Second")

    let info1 = WindowInfo(identity: idFirst, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let info2 = WindowInfo(identity: idSecond, frame: CGRect(x: 50, y: 50, width: 100, height: 100))

    pinManager.pin(identity: idFirst, info: info1, element: nil)
    Thread.sleep(forTimeInterval: 0.05)
    pinManager.pin(identity: idSecond, info: info2, element: nil)

    pinManager.unpinMostRecent()
    assertTest(!pinManager.isPinned(idSecond), "Most recent window unpinned")
    assertTest(pinManager.isPinned(idFirst), "First window remains pinned")

    pinManager.unpinAll()
}

// MARK: - Test 8: Repeated Rapid Pin / Unpin Cycles (Idempotency & Race Safety)
print("\n[Test 8] Repeated Rapid Pin / Unpin Cycles")
do {
    let pinManager = PinManager.shared
    let id = WindowIdentity(processID: 5001, windowID: 301, bundleIdentifier: "rapid.app", applicationName: "RapidApp", windowTitle: "Rapid")
    let info = WindowInfo(identity: id, frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    for _ in 1...10 {
        pinManager.pin(identity: id, info: info, element: nil)
        pinManager.unpin(id)
    }
    assertTest(!pinManager.isPinned(id), "Final state after 10 rapid cycles is cleanly unpinned")
    assertTest(pinManager.pinnedIdentities.isEmpty, "Zero lingering pinned sessions")
}

// MARK: - Test 9: Permission Manager Queries
print("\n[Test 9] Permission Manager Queries")
do {
    let permissions = PermissionManager.shared
    permissions.checkPermissions()
    // Accessible via public properties without crashes
    _ = permissions.hasAccessibilityPermission
    _ = permissions.hasScreenRecordingPermission
    assertTest(true, "PermissionManager queried safely without throwing")
}

// MARK: - Test 10: PinError Formatted Descriptions
print("\n[Test 10] PinError Formatted Descriptions")
do {
    let err1 = PinError.noFocusedWindow
    assertTest(err1.localizedDescription.contains("focused"), "Error message contains 'focused'")

    let err2 = PinError.permissionDenied("Accessibility")
    assertTest(err2.localizedDescription.contains("Accessibility"), "Error message specifies permission")
}

print("\n========================================")
print("Test Results: \(passedCount) passed, \(failedCount) failed")
print("========================================")

if failedCount > 0 {
    exit(1)
} else {
    exit(0)
}
