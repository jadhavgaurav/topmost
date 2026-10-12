# Technical Feasibility & Architecture Decisions: Topmost

## 1. Executive Summary

The objective of **Topmost** is to recreate the user experience of Windows PowerToys *Always on Top* on macOS:
1. Focus any native window (Notes, TextEdit, Chrome, Finder, Terminal, VS Code, etc.).
2. Press `Control + Command + P`.
3. The window is visually pinned above ordinary application windows.
4. Switch to another application and continue working; the pinned window remains visible.
5. Focus the pinned window and press `Control + Command + P` again to unpin it.

This document details the architectural and systems investigation into macOS window-management APIs, security boundaries, and technical feasibility.

---

## 2. Investigation of Approaches

### Approach A: True Native Window Elevation (Third-Party Window Level Alteration)

We investigated whether a third-party unprivileged or Accessibility-authorized process can legitimately alter another application's native window level (`NSWindow.Level`) or WindowServer Z-order on modern macOS (macOS 14 Sonoma and macOS 15+ Sequoia).

#### Findings:
1. **WindowServer Process Isolation:**
   - On macOS, windows are owned by the process that created them (`NSWindow` in AppKit, backed by a WindowServer surface).
   - `NSWindow.level` is an instance property stored in the owning process's memory space and communicated over the process's private SkyLight/WindowServer connection (`CGSConnectionID`).
2. **macOS Accessibility API (`AXUIElement`):**
   - The Accessibility API allows inspecting UI elements, observing frame changes, querying window titles, and invoking actions (`AXRaise`, `AXPress`, `AXCancel`).
   - `AXRaise` brings the window to the front *within its application's current window level*. It does **not** change the window level to `.floating` or elevate it above other applications when switching away.
   - The Accessibility API deliberately does **not** expose a `kAXWindowLevelAttribute` or any attribute to mutate window levels.
3. **Private SkyLight / CGS APIs (`CGSSetWindowLevel`):**
   - Undocumented CGS functions (`CGSSetWindowLevel`, `SLSSetWindowLevel`) historically existed in private frameworks.
   - On modern macOS, calling these APIs for a window owned by another connection requires privileged WindowServer rights (`com.apple.private.skyLight.window-server` entitlement, restricted to Apple system daemons) or disabling System Integrity Protection (SIP) to inject code into the target process (`mach_inject` / `task_for_pid`).
   - Without SIP disabled or private entitlements, unentitled calls fail, crash, or are rejected during Apple Notarization and Gatekeeper evaluation.
4. **Conclusion for Approach A:**
   - **Approach A is technically impossible via supported, public, SIP-compatible APIs on macOS.**
   - Falsely claiming that an accessibility permission allows setting true native window levels on external processes is incorrect and violates Apple's security model.

---

### Approach B: Live Floating Window Representation via ScreenCaptureKit (Selected Approach)

Introduced in macOS 12.3 and refined in macOS 13/14/15, Apple provides **ScreenCaptureKit** (`SCStream`), specifically designed for high-performance, hardware-accelerated window capture.

#### Architecture:
1. **Per-Window Content Filter:**
   - Topmost discovers the target `CGWindowID` using the Accessibility API (`_AXUIElementGetWindow` with `CGWindowListCopyWindowInfo` fallback).
   - An `SCContentFilter(desktopIndependentWindow: scWindow)` is constructed targeting **only** the selected source window.
   - Topmost does **not** capture the entire display. Only the targeted window surface is streamed.
2. **Floating Nonactivating Panel:**
   - Topmost creates an `NSPanel` with style mask `[.borderless, .nonactivatingPanel]`, collection behavior `[.canJoinAllSpaces, .fullScreenAuxiliary]`, and window level `.floating` (`NSWindow.Level.floating`).
   - The panel frame matches the source window's coordinates on screen.
   - ScreenCaptureKit frame buffers (`CMSampleBuffer` / `CVPixelBuffer`) are rendered directly into a hardware-backed `CALayer` (or `AVSampleBufferDisplayLayer`), eliminating unnecessary CPU copies.
3. **No Recursive Capture:**
   - Because `SCContentFilter(desktopIndependentWindow:)` is scoped strictly to the foreign window ID, Topmost's floating overlay and outline panels are completely excluded by the WindowServer compositor from the capture stream.
4. **Lifecycle & Teardown:**
   - When the source window moves or resizes, `AXObserver` notifications update the panel geometry immediately.
   - When the user presses `Control + Command + P` to unpin, or when the source window closes, the stream is stopped asynchronously, the floating panel is closed, and memory is freed immediately.

---

### Approach C: Continuous Bring-to-Front (Rejected)

We evaluated an approach where Topmost does not mirror the window, but instead intercepts application-switch events (`NSWorkspace.didActivateApplicationNotification`) and repeatedly calls `AXUIElementPerformAction(window, kAXRaiseAction)` or `NSRunningApplication.activate`.

#### Why Approach C Fails:
- Steals keyboard and mouse focus from the application the user is attempting to work in.
- Causes visible window flickering and race conditions between WindowServer and the active app.
- Violates core acceptance criteria: "Does not steal focus when pinning; Maintains pinned windows while switching applications."

---

## 3. Window Interaction Model

When an external window is mirrored in a floating overlay:
- **When the source application is frontmost:** The user interacts directly with the real native window. The floating mirror panel is transparent or click-through (`ignoresMouseEvents = true`), guaranteeing 100% native responsiveness, full keyboard input, drag-and-drop, and context menus.
- **When another application is active:**
  - The floating mirror remains visible above the other application's windows.
  - **Primary / Default Interaction (Bring Forward on Click):** Clicking anywhere on the floating overlay instantly activates the source application (`sourceApp.activate(options: [.activateIgnoringOtherApps])`) and raises the source window (`kAXRaiseAction`). The real window instantly receives focus, allowing immediate typing and interaction.
  - **Secondary / Optional Forwarding:** If mouse forwarding is enabled in settings, mouse down/up events can be posted via `CGEventPost` to the source application's window coordinates.

This provides an honest, reliable user experience without making false claims about synthetic keyboard focus in mirrored layers.

---

## 4. Visual & Audio Feedback Architecture

### Pin Outline
- An auxiliary non-interactive `NSPanel` (`ignoresMouseEvents = true`) at `.floating` level draws a crisp 3px solid `#007AFF` blue outline with standard macOS rounded corners (10–12pt radius).
- Because `ignoresMouseEvents` is `true`, clicks pass through unaffected to the underlying window.
- The outline tracks source window geometry and remains visible across Spaces.

### Audio Feedback
- Confirmation sounds provide immediate sensory feedback.
- Pin success: Plays a crisp, subtle confirmation chime (`NSSound(named: "Tink")`).
- Unpin success: Plays a distinct descending confirmation chime (`NSSound(named: "Pop")`).
- Async execution: Audio playback is dispatched asynchronously so it never blocks the main thread or shortcut latency.
- Volume and enable/disable toggles are configurable in Settings.

---

## 5. Global Hotkey Implementation: Carbon vs Event Tap

| Criteria | Carbon `RegisterEventHotKey` | `CGEventTap` |
|---|---|---|
| Latency | Immediate hardware dispatch | Intercepts all keyboard events |
| Permissions | Standard User Session | Requires persistent Accessibility Hook |
| Reliability | Never drops keys or causes lag | Can be disabled if event queue overflows |
| Security | Minimal attack surface | Can log arbitrary keystrokes (keylogger risk) |
| Recommendation | **Selected (Standard for macOS utilities)** | Rejected for primary hotkey |

We selected the Carbon Event Manager `RegisterEventHotKey` API for `Control + Command + P`. It is efficient, battery-friendly, requires zero polling, and respects system security.

---

## 6. Security and Privacy

- **Zero Telemetry:** No analytics, tracking, or network requests.
- **Local-Only:** Capture streams exist only in GPU memory / display pipeline and are never saved to disk or network.
- **Minimal Permissions:**
  - Accessibility: Used only to detect focused window identity and observe geometry.
  - Screen Recording: Used strictly for `SCShareableContent` on explicitly user-pinned windows.
- **SIP Compatible:** 100% compliant with System Integrity Protection and Apple Notarization standards.
