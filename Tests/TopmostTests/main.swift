import Foundation
import CoreGraphics
import Cocoa
import Carbon
import TopmostCore

/// Deterministic permission source so pin logic is testable without real macOS privacy grants.
final class GrantedPermissions: PermissionProviding {
    let hasAccessibilityPermission = true
    let hasScreenRecordingPermission = true
    func checkPermissions() {}
    func requestAccessibility() {}
    func requestScreenRecording() {}
}

/// Collects the result of async work from a test, which runs on another thread.
final class AsyncOutcome: @unchecked Sendable {
    private let lock = NSLock()
    private var didThrow = false
    private var didFinish = false

    var threw: Bool { lock.withLock { didThrow } }
    var finished: Bool { lock.withLock { didFinish } }

    func recordThrow() { lock.withLock { didThrow = true } }
    func recordFinish() { lock.withLock { didFinish = true } }
}

let testPinManager = PinManager(permissions: GrantedPermissions())

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
    let id1 = WindowIdentity(
        processID: 100,
        windowID: 501,
        bundleIdentifier: "com.apple.TextEdit",
        applicationName: "TextEdit",
        windowTitle: "Notes.txt"
    )
    let id2 = WindowIdentity(
        processID: 100,
        windowID: 501,
        bundleIdentifier: "com.apple.TextEdit",
        applicationName: "TextEdit",
        windowTitle: "Renamed Title"
    )
    let id3 = WindowIdentity(
        processID: 101,
        windowID: 502,
        bundleIdentifier: "com.apple.Safari",
        applicationName: "Safari",
        windowTitle: "Apple"
    )

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
    let pinManager = testPinManager
    let id = WindowIdentity(
        processID: 2001,
        windowID: 9001,
        bundleIdentifier: "com.test.app",
        applicationName: "TestApp",
        windowTitle: "TestWin"
    )
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
    let pinManager = testPinManager
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
    let pinManager = testPinManager
    let idFirst = WindowIdentity(
        processID: 4001,
        windowID: 201,
        bundleIdentifier: "first.app",
        applicationName: "FirstApp",
        windowTitle: "First"
    )
    let idSecond = WindowIdentity(
        processID: 4002,
        windowID: 202,
        bundleIdentifier: "second.app",
        applicationName: "SecondApp",
        windowTitle: "Second"
    )

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
    let pinManager = testPinManager
    let id = WindowIdentity(
        processID: 5001,
        windowID: 301,
        bundleIdentifier: "rapid.app",
        applicationName: "RapidApp",
        windowTitle: "Rapid"
    )
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

// MARK: - Test 11: Hex Color Parsing Robustness
print("\n[Test 11] Hex Color Parsing Robustness")
do {
    assertTest(NSColor.from(hex: "#007AFF") != nil, "Standard #RRGGBB parsed")
    assertTest(NSColor.from(hex: "007AFF") != nil, "Hex without hash parsed")
    assertTest(NSColor.from(hex: "  #ff3b30  ") != nil, "Hex with whitespace and lowercase parsed")
    assertTest(NSColor.from(hex: "#123") == nil, "Short hex cleanly rejected")
    assertTest(NSColor.from(hex: "#GGGGGG") == nil, "Invalid hex chars cleanly rejected")
    assertTest(NSColor.from(hex: "") == nil, "Empty string rejected")
}

// MARK: - Test 12: Multi-Monitor Coordinate Conversions
print("\n[Test 12] Multi-Monitor Coordinate Conversions")
do {
    let detector = WindowDetector()
    // Test window located on secondary monitor to the right
    let secondaryAxPoint = CGPoint(x: 1920, y: 50)
    let secondaryAxSize = CGSize(width: 800, height: 600)
    let secondaryCocoa = detector.axFrameToCocoaFrame(axPoint: secondaryAxPoint, axSize: secondaryAxSize)
    assertTest(secondaryCocoa.origin.x == 1920, "Secondary monitor X coordinate matches")

    let convertedBack = detector.cocoaFrameToAxFrame(cocoaFrame: secondaryCocoa)
    assertTest(convertedBack.origin.x == secondaryAxPoint.x, "Converted back secondary X matches")
    assertTest(convertedBack.origin.y == secondaryAxPoint.y, "Converted back secondary Y matches")
}

// MARK: - Test 13: Settings Reset to Defaults
print("\n[Test 13] Settings Reset to Defaults")
do {
    let suiteName = "com.topmost.tests.reset.\(UUID().uuidString)"
    let testDefaults = UserDefaults(suiteName: suiteName)!
    let settings = SettingsManager(defaults: testDefaults)

    settings.outlineThickness = 4.0
    settings.outlineColorHex = "#FF3B30"
    settings.soundVolume = 0.3
    settings.maxFrameRate = 60
    settings.lowResourceMode = true

    assertTest(settings.outlineThickness == 4.0, "Modified outline thickness persisted")
    assertTest(settings.outlineColorHex == "#FF3B30", "Modified outline color persisted")

    settings.resetToDefaults()

    assertTest(settings.outlineThickness == 3.0, "Outline thickness reset to default 3.0")
    assertTest(settings.outlineColorHex == "#007AFF", "Outline color reset to default #007AFF")
    assertTest(settings.maxFrameRate == 30, "Frame rate reset to default 30")
    assertTest(!settings.lowResourceMode, "Low resource mode reset to default false")
    assertTest(settings.soundVolume == 0.8, "Sound volume reset to default 0.8")
    assertTest(settings.overlayClickBehavior == .forwardClick, "Overlay click behavior defaults to passing the click through")
}

// MARK: - Test 14: Dynamic Space Behavior & Preferences Propagation
print("\n[Test 14] Dynamic Space Behavior & Preferences Propagation")
do {
    let pinManager = testPinManager
    let id = WindowIdentity(processID: 6001, windowID: 401, bundleIdentifier: "dyn.app", applicationName: "DynApp", windowTitle: "DynWin")
    let info = WindowInfo(identity: id, frame: CGRect(x: 100, y: 100, width: 400, height: 300))

    pinManager.pin(identity: id, info: info, element: nil)

    // Test that space behavior and capture preferences propagate cleanly without crashing
    pinManager.refreshSpaceBehavior()
    pinManager.refreshCaptureSettings()
    pinManager.refreshVisualPreferences()

    assertTest(pinManager.isPinned(id), "Window remains pinned throughout dynamic refreshes")
    pinManager.unpin(id)
    assertTest(!pinManager.isPinned(id), "Window unpinned cleanly after tests")
}

// MARK: - Test 15: Window Observer Reports Vanished Windows Without Full-List Scans
print("\n[Test 15] Window Observer Reports Vanished Windows")
do {
    let observer = WindowObserver()
    let ghost = WindowIdentity(
        processID: 1,
        windowID: 0x7FFF_FFF0,
        bundleIdentifier: "ghost.app",
        applicationName: "Ghost",
        windowTitle: "Ghost"
    )
    var closedIdentity: WindowIdentity?
    var moveCount = 0

    observer.observe(
        identity: ghost,
        axElement: nil,
        onMoved: { _, _ in moveCount += 1 },
        onClosed: { closedIdentity = $0 }
    )

    let deadline = Date().addingTimeInterval(2.0)
    while closedIdentity == nil && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    assertTest(closedIdentity == ghost, "Close callback fires for a window that does not exist")
    assertTest(moveCount == 0, "Move callback never fires for a vanished window")
}

// MARK: - Test 16: Capture Manager Stop-Before-Start Never Leaves A Running Stream
print("\n[Test 16] Capture Manager Stop-Before-Start")
do {
    let capture = WindowCaptureManager(windowID: 0x7FFF_FFF1)
    capture.stop()

    let outcome = AsyncOutcome()
    Task {
        do {
            try await capture.start(initialSize: CGSize(width: 200, height: 200), scaleFactor: 2.0)
        } catch {
            outcome.recordThrow()
        }
        outcome.recordFinish()
    }

    let captureDeadline = Date().addingTimeInterval(5.0)
    while !outcome.finished && Date() < captureDeadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    assertTest(outcome.finished, "start() after stop() completes promptly")
    assertTest(!outcome.threw, "start() after stop() returns quietly instead of probing for the window")

    capture.stop()
    assertTest(true, "Repeated stop() is safe")
}

// MARK: - Test 17: Settings Migration Overrides Stale Persisted Defaults
print("\n[Test 17] Settings Migration")
do {
    let suiteName = "topmost.tests.migration.\(UUID().uuidString)"
    guard let suite = UserDefaults(suiteName: suiteName) else {
        fatalError("Could not create isolated UserDefaults suite")
    }
    defer { suite.removePersistentDomain(forName: suiteName) }

    // A v0.1.0 install: the old default was persisted and no schema version exists.
    suite.set("bringSourceForward", forKey: "topmost.overlayClickBehavior")
    let migrated = SettingsManager(defaults: suite)
    assertTest(migrated.overlayClickBehavior == .forwardClick, "Stale old default is replaced by the new default")

    // After migration, a deliberate user choice must stick.
    migrated.overlayClickBehavior = .bringSourceForward
    let reloaded = SettingsManager(defaults: suite)
    assertTest(reloaded.overlayClickBehavior == .bringSourceForward, "A choice made after migration is preserved")
}

// MARK: - Test 18: Version Description Falls Back Outside An App Bundle
print("\n[Test 18] Version Description")
do {
    assertTest(!AppInfo.versionDescription.isEmpty, "Version description is never empty")
    assertTest(AppInfo.versionDescription == "development", "Running outside an app bundle reports development")
}

print("\n========================================")
print("Test Results: \(passedCount) passed, \(failedCount) failed")
print("========================================")

if failedCount > 0 {
    exit(1)
} else {
    exit(0)
}
