# Permissions and privacy

## What Topmost promises

- No telemetry, no analytics and no network calls. The only network use is `install.sh`, which you run yourself.
- Nothing about your windows is written to disk. Settings are the only thing saved, in `UserDefaults`.
- Screen capture starts only after you pin a window, and covers that window alone.
- No administrator rights, kernel extensions or changes to System Integrity Protection.

## The two permissions

### Accessibility

Used for:

- Finding the focused window when you press the shortcut.
- Following the pinned window as it moves, resizes or closes.
- Bringing the real app forward and raising its window when you press the mirror.
- Moving the real window when you drag a mirrored window by its title bar.

Not used for: reading text, passwords or the contents of any window, and not for watching the keyboard. The global shortcut is registered with the Carbon Event Manager (`RegisterEventHotKey`), which delivers only your one shortcut to Topmost. There is no event tap.

### Screen Recording

Used for: ScreenCaptureKit, to show a live picture of the pinned window in the mirror.

Scope:

- The capture filter is `SCContentFilter(desktopIndependentWindow:)` for one window ID. Topmost does not capture your display, your desktop or other windows.
- Frames go straight from the capture stream to the screen. They are not saved, encoded or sent anywhere.
- The stream stops as soon as you unpin the window, the window closes, or the app quits.

## Granting the permissions

1. Open **System Settings > Privacy & Security**.
2. Under **Accessibility**, turn on **Topmost**.
3. Under **Screen Recording**, turn on **Topmost**.
4. Relaunch Topmost if macOS asks.

The **Permissions** tab in Topmost Settings shows the live status of both and has a **Re-check Permissions** button. Pinning with a permission missing opens that tab.

## Permissions disappear after an update or a rebuild

macOS ties a permission to the app's code signature. Topmost releases are signed ad hoc, which means the signature is a hash of the exact binary, so a new version counts as a new app and macOS asks again. To fix a stale entry:

1. Open the relevant list in **System Settings > Privacy & Security**.
2. Select **Topmost** and press the minus button to remove it.
3. Relaunch Topmost and grant the permission again.

**If you build Topmost yourself**, run `./scripts/setup-signing.sh` once. It creates a local signing identity, and `./scripts/package.sh` uses it, so macOS keeps your approvals across rebuilds. See [CONTRIBUTING.md](../CONTRIBUTING.md#signing-your-own-builds).

A stale permission is also the usual reason a pin disappears right after you create it. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## What the app can see

Topmost has no way to read the contents of a window beyond the pixels it shows in the mirror, and does not look at them. It reads a window's title, position and size through Accessibility, and uses the title only to label the window in the menu.
