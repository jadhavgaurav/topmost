# Technical Limitations & Operating System Boundaries

Topmost operates strictly within the security model of modern macOS (macOS 14 Sonoma and macOS 15+ Sequoia) without requiring System Integrity Protection (SIP) to be disabled.

Below is an honest summary of platform boundaries and behaviors.

---

## 1. Native Window Level Elevation vs. Live Representation

- **macOS WindowServer Isolation:**
  - On Windows, `SetWindowPos(hwnd, HWND_TOPMOST)` allows any process to elevate another window's Z-order.
  - On macOS, `NSWindow.level` is an instance property stored inside the owning process's memory space. WindowServer does **not** provide a supported public API for a third-party process to alter foreign window levels.
  - Private APIs (e.g. `CGSSetWindowLevel`) require Apple system entitlements (`com.apple.private.skyLight.window-server`) or disabling SIP.
- **Topmost Solution:**
  - Topmost utilizes **ScreenCaptureKit** hardware-accelerated streams hosted inside an AppKit `NSPanel` at `NSWindow.Level.floating`.
  - This keeps the window visually pinned on top across desktop applications and Spaces without violating macOS security.

---

## 2. Keyboard Focus in Mirrored Representations

- When clicking on the floating mirror representation, Topmost immediately brings the real application and window forward (`app.activate()` and `kAXRaiseAction`).
- Keyboard focus cannot be synthetically assigned to a foreign process's window while keeping another application active; macOS WindowServer routes keyboard focus to the frontmost active application.
- Topmost provides direct access to the real window on click, ensuring 100% native keyboard typing, IME support, and shortcut routing.

---

## 3. Protected System Windows & Overlays

- Topmost sets its floating panel level to `NSWindow.Level.floating`.
- It will **not** obscure system-critical interfaces such as:
  - macOS Lock Screen / Screen Saver
  - Touch ID and Password authorization dialogs
  - Mission Control and Stage Manager management views
  - Critical system alerts and kernel panic notices
- This is intentional to ensure system security and stability.

---

## 4. Fullscreen Applications

- Pinned windows use `.canJoinAllSpaces` and `.fullScreenAuxiliary` collection behaviors, allowing them to remain visible across desktop Spaces.
- Native macOS fullscreen apps (which create dedicated fullscreen Spaces) may restrict non-system auxiliary windows depending on macOS Spaces configuration ("Displays have separate Spaces").
