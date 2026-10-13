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

A mirror is only useful if the real window is easy to reach. Topmost treats the mirror as a stand-in that gets out of the way.

- **Pinned window focused in the active app (Native).** The mirror is hidden. You use the real window, with real dragging, typing and window controls, and there is no copy to lag behind it.
- **Anything else (Mirrored).** The mirror floats above other apps and takes the first press. Topmost activates the real app, then either moves the real window (a drag that starts in the title strip) or replays the click onto it.

The mirror was previously click-through whenever the source app was active, and always visible. That left a second, slightly delayed copy of the window on top of the real one while you dragged it, which is where the lag came from. Hiding the mirror in the Native state removes the copy.

The states and the press handling are described in [ARCHITECTURE.md](ARCHITECTURE.md#interaction-states).

---

## 4. Visual & Audio Feedback Architecture

### Pin Outline
- An auxiliary non-interactive `NSPanel` (`ignoresMouseEvents = true`) at `.floating` level draws a crisp 3px solid `#007AFF` blue outline with standard macOS rounded corners (10 to 12 pt radius).
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

---

## 7. Decision Records

Short records of choices made after the first release. Each one names the problem, the choice, and what it costs.

### D1. Activate with `AXFrontmost`, not `NSRunningApplication.activate()`

- **Problem:** On macOS 14 and later, `activate()` is ignored when the calling app is not frontmost, and Topmost never is. Pressing a mirrored window did nothing, so the pinned window was unreachable.
- **Choice:** Set the `AXFrontmost` attribute on the app's Accessibility element, then raise the window. This needs the Accessibility permission Topmost already has. `activate()` remains as a fallback.
- **Cost:** An Accessibility call that can block, which is why every call has a 0.5 second timeout.

### D2. Move the real window through Accessibility instead of replaying drag events

- **Problem:** A press on the mirror belongs to the mirror for its whole length. Replaying the mouse-down and the drag onto the real window did not work reliably while the window was still activating.
- **Choice:** Treat a drag that starts in the top 44 points as a window move. Write the new position with `kAXPositionAttribute`. Replay only plain clicks, after the real window is active.
- **Cost:** Dragging from the body of a mirrored window only activates the app. It is not forwarded, so text selection by dragging needs a second press. This avoids fighting the app over what a drag means.

### D3. Move the mirror and outline first, the real window second

- **Problem:** Waiting for the real window to report its new position before moving the overlays made them trail the pointer.
- **Choice:** During a drag, move the mirror and outline under the pointer immediately. Send position writes to the real app at most 60 times a second, and write the exact final position on release. Ignore position reports from the real window while the drag lasts.
- **Cost:** For a moment the real window can be a few pixels behind the mirror. It is hidden under the mirror, so it is not seen.

### D4. Look up pinned windows by ID instead of listing every window

- **Problem:** Tracking copied the whole window list ten times a second and once more for each move event. On a busy desktop that is real load on the window server.
- **Choice:** `CGWindowListCreateDescriptionFromArray` for just the pinned window IDs, about 0.1 ms each. Coalesce events, and track fast only while something is moving.
- **Cost:** More states in `WindowObserver` (idle, motion, linger) to reason about.

### D5. Never intercept the mouse without a picture

- **Problem:** If capture failed, the mirror was a transparent panel that still swallowed every click, and the user could not reach the window underneath.
- **Choice:** The mirror ignores the mouse until its first frame has been shown. If capture cannot start or stops, the pin is removed.
- **Cost:** A failed capture silently ends the pin, with an error sound. Troubleshooting covers why this happens.

### D6. Version the settings schema

- **Problem:** `SettingsManager` writes every value to `UserDefaults` on launch, so a changed default never reaches anyone who already ran the app. The old click behavior stayed in force after the code changed.
- **Choice:** A `settingsSchemaVersion` key and a `migrateIfNeeded()` step that resets the affected keys once.
- **Cost:** A deliberate choice made before a migration is reset once. Later choices are kept.

### D7. A stable local signing identity for development

- **Problem:** An ad-hoc signature changes with every build, so macOS treats each rebuild as a new app and drops its Accessibility and Screen Recording approvals.
- **Choice:** `scripts/setup-signing.sh` creates a self-signed identity in a dedicated keychain, and `package.sh` uses it for local builds. Release builds stay ad hoc so they never depend on one person's keychain.
- **Cost:** Releases still need "Open Anyway" on first launch until the app is signed with a paid Developer ID and notarized.

