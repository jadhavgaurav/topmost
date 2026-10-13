# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-10-13

This release fixes serious problems in 0.1.0 that could leave windows unresponsive and put heavy load on the window server. Everyone on 0.1.0 should update.

### Fixed

- A pinned window could leave an invisible, click-blocking panel on screen when capture failed or the macOS permissions had gone stale. The mirror now ignores the mouse until it has shown its first frame, and the pin is removed if capture fails or stops.
- Pinning and unpinning quickly could leave a screen-capture stream running with nothing receiving it. Stopping a stream that is still starting now tears it down.
- Window tracking copied the system-wide window list ten times a second, and again for every move event. It now looks up only the pinned windows and coalesces bursts of events.
- Captured frames could pile up on the main thread while it was busy. Only the latest frame is kept.
- A frozen app could block Topmost's overlays for up to six seconds through an Accessibility call. Calls now give up after half a second.
- Clicking a pinned window while another app was active did nothing, because macOS 14 and later ignores activation requests from an app that is not frontmost. Topmost now activates the app through the Accessibility API, so the click brings it forward.
- A pinned window could not be dragged from another app. A press on its title bar now moves the real window in one motion, and a plain click is passed through to the window, so its buttons work.
- The settings window no longer floats above every other window.

### Changed

- When the pinned window is the focused window of the active app, the mirror is hidden and you use the real window directly. This removes the trailing copy you saw while dragging.
- The blue outline follows a moving window at about 120 updates a second, and the mirror and outline move instantly under the pointer when you drag a mirrored window.
- Passing the click through to the real window is now the default, and the Behavior setting names it "Bring Forward and Pass Click Through (Recommended)". Settings saved by 0.1.0 are migrated once so the new default applies. "Bring Real Window Forward Only" is still available.
- The About tab reads its version from the app instead of a fixed string.

### Added

- `install.sh`, a one-line installer that verifies the download against the release checksums.
- `scripts/setup-signing.sh`, which creates a stable local signing identity so macOS keeps the Accessibility and Screen Recording permissions across rebuilds.
- Strict SwiftLint in CI, a docs check for links and style, and a release workflow that publishes the changelog entry as the release notes.
- Documentation: a rewritten README with screenshots and diagrams, a troubleshooting guide, a releasing guide, and updated architecture, decisions, limitations and testing pages.
- Tests for window tracking, capture stop-before-start, the new default, the settings migration and the version string.

### Known issues

- While a window is captured, macOS draws a screen-sharing pill over its close and minimise buttons.
- The pinned window's shortcut cannot be changed from Settings yet.

## [0.1.0] - 2026-10-12

### Added
- Native macOS Always on Top utility inspired by Windows PowerToys.
- Global keyboard shortcut toggle: `Control + Command + P` (`⌃⌘P`).
- Optional secondary shortcut: `Control + Command + U` (`⌃⌘U`) to unpin most recent window.
- Accurate foreground window detection via macOS Accessibility APIs (`AXUIElement`) and `CGWindowID`.
- Hardware-accelerated window streaming via ScreenCaptureKit (`SCContentFilter(desktopIndependentWindow:)`).
- Native visual feedback: 3px solid `#007AFF` blue outline with rounded corners.
- Asynchronous native audio feedback chimes on pin and unpin.
- Native AppKit menu bar status item with pinned windows list and "Unpin All" action.
- Native SwiftUI Settings interface with General, Appearance & Feedback, Behavior, Permissions, and About tabs.
- Multi-window independent pinning support.
- Automatic stale pin cleanup when source windows close or terminate.
- Universal binary distribution (Apple Silicon arm64 + Intel x86_64).
