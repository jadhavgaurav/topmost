# Topmost v0.1.0 Release Notes

**Topmost** is a native macOS utility that recreates the core user experience of Windows PowerToys *Always on Top* for macOS.

---

## ✨ Features

- **Global Shortcut:** Press `Control + Command + P` (`⌃⌘P`) to pin or unpin any active window instantly.
- **Accurate Window Targeting:** Pins only the specifically focused window, never entire applications.
- **Persistent Visibility:** Pinned windows remain visible above other apps as you switch contexts.
- **Native Visual Feedback:** Displays a 3px solid blue outline (`#007AFF`) with smooth rounded corners tracking the pinned window.
- **Audio Confirmation:** Plays subtle native audio chimes upon pinning (`Tink`) and unpinning (`Pop`).
- **Secondary Recovery:** Manage active pins or unpin all windows directly from the native menu bar icon.
- **Universal Binary:** Native performance on Apple Silicon (M1/M2/M3/M4) and Intel Macs.
- **Zero Telemetry & 100% Offline:** Operates entirely locally with no network calls or disk frame persistence.

---

## 💻 System Requirements

- **macOS Version:** macOS 14.0 (Sonoma) or later (including macOS 15 Sequoia).
- **Architecture:** Universal (Apple Silicon & Intel 64-bit).
- **Permissions:** Accessibility (for window tracking) & Screen Recording (for ScreenCaptureKit stream).

---

## 📦 Installation

1. Download `Topmost-v0.1.0-macos-universal.dmg` from the Assets below.
2. Open the disk image and drag **Topmost.app** to your **/Applications** folder.
3. Launch **Topmost** from Applications.
4. Grant Accessibility and Screen Recording permissions when prompted in System Settings.
5. Focus any window and press `Control + Command + P`!

---

## 🛡️ Code Signing & Gatekeeper Note

This initial release is built with Apple Hardened Runtime and ad-hoc signed for open-source distribution. If macOS displays a Gatekeeper prompt on first launch:
- Right-click (or Control-click) `Topmost.app` in Finder and select **Open**, then click **Open**.
- Alternatively, run:
  ```bash
  xattr -dr com.apple.quarantine /Applications/Topmost.app
  ```

---

## 📄 Verified Checksums

See `SHA256SUMS` attached to this release for cryptographic verification.
