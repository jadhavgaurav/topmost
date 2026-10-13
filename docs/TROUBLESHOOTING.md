# Troubleshooting

Start with the symptom. Most problems are a missing or stale permission.

## A pin disappears right after I create it

The pin was removed because capture could not start. The usual cause is a stale Screen Recording approval: macOS shows Topmost as allowed, but the approval belongs to an older build of the app.

1. Open **System Settings > Privacy & Security > Screen Recording**.
2. Select **Topmost**, press the minus button to remove it, and relaunch Topmost.
3. Grant Screen Recording again. Do the same under **Accessibility**.
4. Pin the window again.

If it still disappears, the window may belong to an app that blocks screen capture. See [LIMITATIONS.md](LIMITATIONS.md#9-apps-that-block-capture).

## Nothing happens when I press Control + Command + P

- Check the **Permissions** tab in Settings. Pinning needs both permissions, and a missing one opens that tab.
- Another app may already use `Control + Command + P`. Quit it, or check **System Settings > Keyboard > Keyboard Shortcuts**.
- A window with no title bar, or a very small one (under 30 points), is ignored. Focus a normal window.
- You pressed the shortcut while Topmost itself was in front. Focus the window you want first.

## I granted the permissions but Topmost still says they are missing

Permissions are read when the app starts, and a relaunch picks up a new grant. Quit Topmost from its menu bar icon and open it again, then press **Re-check Permissions**.

## macOS asks for permissions again after every update

Topmost releases are signed ad hoc, so macOS sees each version as a new app. Remove the old **Topmost** entry from both lists and grant them again. See [PERMISSIONS.md](PERMISSIONS.md#permissions-disappear-after-an-update-or-a-rebuild).

If you build from source and rebuild often, run `./scripts/setup-signing.sh` once, and macOS will keep your approvals.

## The close and minimise buttons are gone

macOS draws a screen-sharing pill over the traffic lights of any captured window. Use `Command + W` to close, `Command + M` to minimise, or unpin first. See [LIMITATIONS.md](LIMITATIONS.md#2-a-screen-sharing-pill-covers-the-close-and-minimise-buttons).

## The pinned window does not drag, or my click does nothing

- Check **Settings > Behavior > When Clicking Floating Overlay**. With **Bring Real Window Forward Only**, the first press only switches apps, and a drag needs a second press. Choose **Bring Forward and Pass Click Through** for a single motion.
- A drag moves the window only if it starts in the top 44 points of the window, the title bar and toolbar. Dragging in the body does not move it.
- If the press does nothing at all, the Accessibility permission may be stale. See the first section.

## The outline or mirror is in the wrong place

Topmost follows the window through Accessibility notifications and a timer, and corrects itself within a moment. If it is still wrong:

1. Press `Control + Command + P` twice to unpin and pin again.
2. If you changed display arrangement while a window was pinned, unpin and pin it again.

## A pinned window stays on screen after I minimise it or hide its app

Minimised and hidden windows are not handled specially. Unpin it, or restore the window. See [LIMITATIONS.md](LIMITATIONS.md#4-minimised-and-hidden-windows).

## A sheet or popover is hidden behind the pinned window

While another app is active, sheets and popovers of the pinned app can sit under the mirror. Press the pinned window to bring its app forward. See [LIMITATIONS.md](LIMITATIONS.md#3-sheets-popovers-and-menus-of-the-pinned-app).

## The pinned window does not show over a full-screen app

That depends on your Spaces setup. See [LIMITATIONS.md](LIMITATIONS.md#8-full-screen-apps-and-spaces).

## Topmost uses a lot of CPU

- Lower the frame rate under **Settings > Behavior > Maximum Frame Rate**, or turn on **Low Resource Mode**, which caps capture at 15 FPS.
- Every pinned window runs its own capture stream. Unpin the ones you do not need.
- Idle, with a window pinned and nothing moving, Topmost should use about 1% of one core. If it is much higher, [open an issue](https://github.com/jadhavgaurav/topmost/issues/new?template=bug_report.yml) with the details below.

## Reading the log

Topmost writes short lines prefixed `[Topmost]` to the system log. To see them while you reproduce a problem, run this in Terminal:

```bash
/usr/bin/log stream --predicate 'process == "Topmost"' --info
```

Some messages are redacted by macOS. To capture all of them, launch the app from Terminal with its error output in a file:

```bash
pkill -x Topmost
open -a /Applications/Topmost.app --stderr "$HOME/topmost.log"
```

The lines to look for are `Capture start error`, `Capture failed, removing pin` and `Missing permissions to pin window`.

## Reporting a bug

Please include:

- Your macOS version and whether the Mac is Apple Silicon or Intel.
- The Topmost version, shown on the **About** tab.
- The app whose window you pinned.
- What you did, what you expected, and what happened.
- Lines from the log above, if you can.

Open the issue with the [bug report form](https://github.com/jadhavgaurav/topmost/issues/new?template=bug_report.yml).
