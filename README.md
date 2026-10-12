<p align="center">
  <img src="Sources/Topmost/Resources/AppIcon.icns" width="128" height="128" alt="Topmost Icon" />
</p>

<h1 align="center">Topmost</h1>

<p align="center">
  <b>A lightweight, native macOS utility that keeps any window Always on Top.</b><br />
  Recreating the core Windows PowerToys Always on Top experience for macOS.
</p>

<p align="center">
  <a href="https://github.com/jadhavgaurav/topmost/actions/workflows/ci.yml"><img src="https://github.com/jadhavgaurav/topmost/actions/workflows/ci.yml/badge.svg" alt="CI Status" /></a>
  <a href="https://github.com/jadhavgaurav/topmost/releases"><img src="https://img.shields.io/github/v/release/jadhavgaurav/topmost" alt="Release" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-orange.svg" alt="Universal Binary" />
</p>

---

## ⚡ Primary Interaction

1. Open any normal window (Notes, TextEdit, Terminal, Chrome, Safari, VS Code, Finder).
2. Focus that window.
3. Press **`Control + Command + P`** (`⌃⌘P`).
4. That specific window becomes pinned above ordinary application windows with a subtle **3px blue outline** (`#007AFF`) and a confirmation chime.
5. Switch to another application and continue working: the pinned window **remains visible on top**.
6. Return to the window and press **`Control + Command + P`** again to unpin it.

No need to open a configuration window or select windows from a menu.

---

## ✨ Features

- **Global Keyboard Shortcut:** Instant toggle via hardware-dispatched Carbon hotkey (`⌃⌘P`).
- **Visual Feedback:** 3px solid blue outline (`#007AFF`) conforming to window borders and rounded corners.
- **Audio Feedback:** Subtle native confirmation sounds on pin (`Tink`) and unpin (`Pop`).
- **Accurate Window Targeting:** Pins only the specifically focused window, never an entire application or multi-window stack.
- **Multi-Window Pinning:** Pin multiple independent windows across screens and desktop Spaces.
- **Auto-Cleanup:** Stale pins automatically dismiss when the source window is closed or its application quits.
- **Native Menu Bar Utility:** Lightweight status bar item (`pin.fill`) with active window list, quick unpin, and "Unpin All".
- **SwiftUI Settings:** Easily customize outline color, outline thickness (1–5px), sound volume, frame rate, and shortcuts.
- **100% Native & Private:** Built with Swift, AppKit, ScreenCaptureKit, and SwiftUI. Zero analytics, zero tracking, zero disk caching, completely offline.

---

## 💻 Compatibility

| Property | Requirement |
|---|---|
| **Operating System** | macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or later |
| **CPU Architectures** | Universal: Apple Silicon (M1/M2/M3/M4) & Intel (x86_64) |
| **Integrations** | AppKit, ScreenCaptureKit, Carbon Event Manager, SwiftUI |

---

## 🚀 Installation

### Option 1: Download Release (Recommended)
1. Download **`Topmost-v0.1.0-macos-universal.dmg`** from [GitHub Releases](https://github.com/jadhavgaurav/topmost/releases).
2. Open the DMG and drag **Topmost.app** to your **/Applications** folder.
3. Launch Topmost from Applications.

### Option 2: Build & Install from Source
```bash
git clone https://github.com/jadhavgaurav/topmost.git
cd topmost
./scripts/package.sh
./scripts/install.sh
```

---

## 🔐 Permissions

Topmost follows the principle of least privilege:
- **Accessibility:** Used exclusively to identify the frontmost focused window and observe its position/size when moved or resized.
- **Screen Recording:** Used by Apple's `ScreenCaptureKit` to stream the visual surface of explicitly pinned windows into the floating overlay.

To verify or grant permissions:
- **System Settings → Privacy & Security → Accessibility → Enable Topmost**
- **System Settings → Privacy & Security → Screen Recording → Enable Topmost**

Read more in [docs/PERMISSIONS.md](docs/PERMISSIONS.md).

---

## 🛠️ How It Works & Architecture

On macOS, the WindowServer strictly enforces process isolation and does not provide an unprivileged public API for a third-party application to mutate another application's native window level.

Topmost bridges this gap using modern macOS APIs:
1. **Window Identification:** Resolves `CGWindowID` using Accessibility (`_AXUIElementGetWindow` with `CGWindowListCopyWindowInfo` fallback).
2. **Hardware Streaming:** Creates an isolated `SCStream` with `SCContentFilter(desktopIndependentWindow:)` targeting *only* that specific window.
3. **Floating Overlay:** Renders the hardware stream into an AppKit `NSPanel` at `NSWindow.Level.floating` with `.canJoinAllSpaces`.
4. **Interaction Model:** When clicking the floating overlay, Topmost immediately brings the real application and window forward with native keyboard focus.

Read the complete engineering investigation in [docs/TECHNICAL_DECISIONS.md](docs/TECHNICAL_DECISIONS.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## ⌨️ Shortcuts & Settings

| Action | Shortcut | Configurable |
|---|---|---|
| **Pin / Unpin Current Window** | `⌃⌘P` (`Control + Command + P`) | Yes (Settings) |
| **Unpin Most Recent Window** | `⌃⌘U` (`Control + Command + U`) | Optional (disabled by default) |

Open Settings via the menu bar icon or `Command + ,`:
- **Appearance & Feedback:** Outline toggle, color picker (Blue, Green, Orange, Purple, Yellow, Red), thickness slider (1–5px), audio toggles, and volume control.
- **Window Behavior:** Multi-window pinning, Space behavior, and overlay interaction mode.
- **Performance:** Frame rate limiter (15, 30, 60 FPS) and low resource usage mode.

---

## 🧪 Testing

Topmost comes with an automated test suite verifying window identity hashing, coordinate transformations, settings clamping, and multi-pin lifecycle:

```bash
./scripts/test.sh
```

See [docs/TESTING.md](docs/TESTING.md) for the automated results and manual test matrix.

---

## 📄 License

Topmost is open-source software licensed under the [MIT License](LICENSE).  
Developed and maintained by **Gaurav Jadhav** ([@jadhavgaurav](https://github.com/jadhavgaurav)).
