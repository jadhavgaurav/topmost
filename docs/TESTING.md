# Testing

Topmost has an automated test suite for its logic and a manual plan for what only a real desktop can show.

## Automated tests

```bash
./scripts/test.sh
```

The tests live in `Tests/TopmostTests/main.swift` and run as an executable (`swift run TopmostTests`), not through `swift test`. The runner prints each check and exits with a non-zero status if any fails.

The suite needs no macOS permissions. `PinManager` takes its permission source through the `PermissionProviding` protocol, and the pin tests use one that always grants, so they behave the same on a laptop and in CI.

| Test | What it checks |
| --- | --- |
| 1 | Window identity equality and hashing ignore the title |
| 2 | Accessibility and Cocoa coordinate conversions round-trip |
| 3 | Shortcut strings are formatted correctly |
| 4 | Outline thickness and sound volume are clamped to their limits |
| 5 | Pin, unpin and the pinned list |
| 6 | Several pins at once, and Unpin All |
| 7 | Unpin Most Recent removes the newest pin only |
| 8 | Ten quick pin and unpin cycles leave a clean state |
| 9 | The permission manager answers without throwing |
| 10 | Error descriptions are readable |
| 11 | Hex color parsing accepts valid input and rejects bad input |
| 12 | Coordinates are correct on a second display |
| 13 | Reset to defaults restores every setting, including the click behavior |
| 14 | Space behavior and capture preferences propagate to live pins |
| 15 | The observer reports a vanished window as closed, and never as moved |
| 16 | Stopping a capture before it starts is quiet, and stopping twice is safe |
| 17 | The settings migration replaces the old default once, and keeps later choices |
| 18 | The version string falls back to `development` outside an app bundle |

**66 checks, 0 failures** at version 0.2.0.

### Lint and docs

```bash
TOOLCHAIN_DIR=/Library/Developer/CommandLineTools swiftlint lint --strict
./scripts/check-docs.sh
```

CI runs both, plus the test suite, a universal build and packaging, on every push and pull request.

## What the tests do not cover

The suite cannot press a key, show a window or stream a screen. These are checked by hand, using the plan below, before a release.

## Manual test plan

Use a Mac with Accessibility and Screen Recording granted. Two TextEdit documents and Safari are enough for most of it.

### Pin and unpin

1. Focus a TextEdit window and press `Control + Command + P`. Expect a blue outline and a chime.
2. Switch to Safari. Expect the TextEdit window to stay on top.
3. Press `Control + Command + P` with the TextEdit window focused. Expect the outline to go and a different chime.

### One window, not the app

1. Open two TextEdit documents and pin the first.
2. Expect the second to behave as a normal window and not to be outlined.

### Working in a pinned window from another app

1. Pin a window, then make another app active.
2. Press the pinned window. Expect its app to come forward and its window to be focused.
3. Press on its title bar and drag in one motion. Expect the window to follow the pointer, with the outline attached throughout, and to land where you let go.
4. Press a button in the pinned window, for example a toolbar button. Expect the click to act, not only to switch apps.
5. Switch **Settings > Behavior > When Clicking Floating Overlay** to **Bring Real Window Forward Only**. Expect the first press to switch apps and a second press to be needed for a drag.

### Dragging a pinned window while its app is active

1. Pin a window and keep its app active.
2. Drag it by the title bar. Expect no second copy of the window, and the outline to follow closely.

### Following the window

- Resize the pinned window from a corner. Expect the outline and the mirror to resize with it.
- Move it to another display. Expect the outline to stay aligned.
- Close it with `Command + W`. Expect the outline and mirror to disappear at once.
- Quit its app with `Command + Q`. Expect no overlay to be left behind.

### Several pins

1. Pin three windows, then choose **Unpin All Windows** in the menu bar. Expect all three to release.
2. Turn off **Allow Multiple Pinned Windows**, pin one window, then pin another. Expect the first to release.

### Spaces and appearance

- Pin a window and switch Spaces. With **Keep Pinned Windows Visible Across Spaces** on, it should follow you. With it off, it should stay on its Space.
- Switch between light and dark mode. Settings and the menu should adapt.

### Failure handling

1. Remove Topmost from **Screen Recording** in System Settings, relaunch it, and press the shortcut. Expect an error sound and the Permissions tab, not an empty overlay.
2. Pin a window and quit and relaunch Topmost. Expect no overlay to remain from the old run.

### Resource use

Pin a window and leave it. Expect Topmost to use about 1% of one CPU core, and a few percent while you drag. Check with **Activity Monitor**.

## Measuring drag smoothness

For a repeatable check, sample the position of the real window, the outline and the mirror several hundred times a second while a scripted drag runs, then report how far each trails. The 0.2.0 numbers, measured on an Apple Silicon Mac with a 300 by 80 point drag at about 120 events a second:

| Case | Outline behind the real window |
| --- | --- |
| Pinned app active (native drag) | 3.6 px on average, 19 px at worst |
| Another app active (drag through the mirror) | 0.7 to 1.0 px on average, 13 px at worst. Mirror and outline never differ |

These are guides for spotting a regression, not guarantees. They depend on the Mac and on how responsive the pinned app is.
