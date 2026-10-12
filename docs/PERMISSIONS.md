# Permissions & Privacy: Topmost

## Principle of Least Privilege

Topmost is built strictly around user privacy and security:
- **No telemetry, analytics, or background network calls.**
- **No persistent disk storage of window frames or content.**
- **No broad screen recording before explicit user action.**
- **No administrator privileges, kernel extensions, or SIP modifications.**

---

## Required macOS Permissions

### 1. Accessibility (`AXIsProcessTrusted`)

#### Why is it needed?
- **Focused Window Discovery:** To identify which application and window is currently active when you press `Control + Command + P`.
- **Window Geometry Tracking:** To observe window moves and resizes (`kAXMovedNotification`, `kAXResizedNotification`) so the pin outline and floating overlay remain aligned.
- **Window Activation:** To raise the real window to the front when you click on the pinned overlay.

#### What it does NOT do:
- It does **not** log keystrokes.
- It does **not** read text contents or credentials inside windows.

---

### 2. Screen Recording (`CGPreflightScreenCaptureAccess`)

#### Why is it needed?
- **ScreenCaptureKit:** Required by Apple to capture and stream the visual surface of a window into the floating overlay panel.

#### Scope of Capture:
- Capture is strictly initiated **only** after you explicitly pin a window.
- The capture filter is configured with `SCContentFilter(desktopIndependentWindow:)` targeting **only that specific window ID**.
- Topmost does **not** capture your entire display, desktop icons, or other windows.
- When a window is unpinned or closed, the stream is stopped and released immediately.

---

## How to Grant Permissions

When launched for the first time, Topmost prompts for permissions. You can also grant them manually:

1. Open **System Settings** on your Mac.
2. Navigate to **Privacy & Security**.
3. Under **Accessibility**, enable **Topmost**.
4. Under **Screen Recording**, enable **Topmost**.
5. Relaunch Topmost if prompted by macOS.
