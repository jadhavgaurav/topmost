# Limitations

Topmost works inside the macOS security model on macOS 14 (Sonoma) and later, with System Integrity Protection on. This page lists what that costs. Each item says what you will see and what to do about it.

## 1. A mirror, not a real window level

- **Why:** On Windows, any process can ask for another window to be topmost. On macOS, a window's level belongs to the app that owns it, and the private calls that change another app's levels need Apple-only entitlements or SIP turned off. See [TECHNICAL_DECISIONS.md](TECHNICAL_DECISIONS.md#2-investigation-of-approaches).
- **What Topmost does instead:** it shows a live picture of the window in a panel at the floating level, and uses the real window whenever you work in it.
- **What you will see:** while another app is active, the thing on top is a picture of the window, not the window. It updates at up to 60 frames a second and is sharp, but it is a picture.

## 2. A screen-sharing pill covers the close and minimise buttons

- **What you will see:** while a window is pinned, macOS draws a small purple screen-sharing indicator over the window's traffic lights. macOS draws it on windows that are being captured, and there is no setting in ScreenCaptureKit that Topmost knows of to turn it off.
- **What to do:** close with `Command + W`, minimise with `Command + M`, or unpin first with `Control + Command + P`.
- **Related:** the purple capture indicator in the menu bar is also macOS. It shows whenever any app is capturing the screen, and goes away when you unpin everything.

## 3. Sheets, popovers and menus of the pinned app

- **What you will see:** the mirror shows the pinned window only. A sheet, popover or menu that the pinned app opens is a separate window, and while another app is active it can sit under the mirror.
- **What to do:** press the mirror to bring the app forward. In that state you are using the real windows, and they behave normally.

## 4. Minimised and hidden windows

- **What you may see:** Topmost does not treat a minimised window or a hidden app as a special case, so the mirror can stay on screen showing the last picture it received.
- **What to do:** restore the window or unpin it.

## 5. Keyboard focus

- **How it works:** keyboard input goes to the active app. A mirrored window cannot receive typing, because it is only a picture.
- **What Topmost does:** the first press on the mirror activates the real app, so your next key press goes to it. Input methods, shortcuts and drag and drop all work normally from then on.

## 6. Shortcuts cannot be changed in the app yet

The pin shortcut is `Control + Command + P` and the optional unpin shortcut is `Control + Command + U`. Settings shows them, and the values are stored in preferences, but there is no control for rebinding them in this version.

## 7. Protected system interfaces

Pinned panels use the floating level, which is below the lock screen, the screen saver, password and Touch ID prompts, and Mission Control. Topmost cannot cover these and should not.

## 8. Full-screen apps and Spaces

- Pinned windows join all Spaces by default, and can be limited to the Space they were pinned on under **Settings, Behavior**.
- A native full-screen app lives in its own Space. Whether a pinned panel shows over it depends on your Spaces settings, in particular **Displays have separate Spaces**. If a pinned window does not show over a full-screen app, that is the cause.

## 9. Apps that block capture

Some apps mark their windows as protected from screen capture, for example video players with copy protection, and some password managers. ScreenCaptureKit may show nothing for them, so Topmost may not be able to mirror them. If capture fails, the pin is removed with an error sound.

## 10. Not notarized

Topmost is signed ad hoc, not with an Apple Developer ID, and is not notarized. macOS shows an "Open Anyway" prompt on first launch. See [Install in the README](../README.md#install).
