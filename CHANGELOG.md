# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
