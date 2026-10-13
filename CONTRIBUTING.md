# Contributing to Topmost

Thanks for helping. Before you start:

1. **Open an issue first** for anything bigger than a small fix, so we can agree on the approach. For a bug, say what you saw, on which macOS version.
2. **Build and test on macOS 14 or later:** `swift build` and `./scripts/test.sh`.
3. **Keep strict lint clean:** `TOOLCHAIN_DIR=/Library/Developer/CommandLineTools swiftlint lint --strict`. Set `TOOLCHAIN_DIR` to your Xcode or Command Line Tools path. Install SwiftLint with `brew install swiftlint`.
4. **Add or update tests** in `Tests/TopmostTests/main.swift` for logic changes. Put logic in `TopmostCore` so it can be tested without the UI.
5. **Update the docs.** User-visible changes get a line in `CHANGELOG.md` under an `[Unreleased]` heading, and any page in `docs/` that describes the changed behavior is updated in the same pull request. Run `./scripts/check-docs.sh`.
6. **Commit messages** use a short prefix: `feat:`, `fix:`, `docs:`, `style:`, `build:`, `test:` or `refactor:`.

Pull requests should describe what changed and how you tested it. The template asks for both.

## Setting up

You need macOS 14 or later and the Swift toolchain from Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/jadhavgaurav/topmost.git
cd topmost
swift build                  # debug build
./scripts/test.sh            # automated tests
```

Topmost needs the Accessibility and Screen Recording permissions to do anything useful, so you will want to run it as an app, not through `swift run`.

### Signing your own builds

macOS ties each permission to the app's code signature. A default build is signed ad hoc, and an ad-hoc signature changes with every build, so macOS treats every rebuild as a new app and asks for both permissions again. Run this once to avoid that:

```bash
./scripts/setup-signing.sh
```

It creates a self-signed identity in its own keychain at `~/.topmost-signing`, which leaves your login keychain alone. `./scripts/package.sh` then signs local builds with it, and macOS keeps your approvals across rebuilds. You grant the permissions once, after the first build signed this way. To remove it, run `./scripts/setup-signing.sh --remove`.

The identity is for your own Mac. Release builds ignore it (`TOPMOST_RELEASE=1` or running in CI), so published artifacts are always ad hoc signed.

### Build, install and run

```bash
./scripts/package.sh         # builds build/Topmost.app and the DMG and zip in dist/
./scripts/install-local.sh         # copies the app to /Applications (quits a running copy first)
open /Applications/Topmost.app
```

To see the app's own log lines while you test, start it from Terminal with its error output in a file:

```bash
pkill -x Topmost
open -a /Applications/Topmost.app --stderr "$HOME/topmost.log"
tail -f "$HOME/topmost.log"
```

## Project layout

- `Sources/TopmostCore`: the app's logic and UI, as a library. Start with `PinManager`.
- `Sources/Topmost`: the executable, `Info.plist`, entitlements and icon.
- `Tests/TopmostTests`: the test runner.
- `scripts/`: build, package, install, signing, release and docs checks.
- `docs/`: [architecture](docs/ARCHITECTURE.md), [decisions](docs/TECHNICAL_DECISIONS.md), [permissions](docs/PERMISSIONS.md), [limitations](docs/LIMITATIONS.md), [testing](docs/TESTING.md) and [releasing](docs/RELEASING.md).

## Code guidelines

- No third-party dependencies unless there is a strong reason. Topmost has none, and that is part of why it is easy to trust.
- Avoid force casts and force unwraps. Accessibility values are untyped, so use the helpers in `AccessibilityHelpers.swift`.
- Anything that calls into another app through Accessibility must have a timeout, and must not run in a tight loop on the main thread. A frozen app should not be able to freeze Topmost.
- A pinned window's overlays must never block the mouse without showing something. Read [TECHNICAL_DECISIONS.md](docs/TECHNICAL_DECISIONS.md#7-decision-records) before changing how the mirror handles input.
- Errors are specific. Say what failed and for which window.
- Settings that change a default for existing users need a schema version bump and a migration in `SettingsManager`.

## What to test before you open a pull request

Run the automated tests, lint and the docs check. For a change that touches pinning, dragging or capture, also walk through the relevant parts of the [manual test plan](docs/TESTING.md#manual-test-plan). The automated tests cannot show a window or move a pointer.

## Style for words

This applies to the README, the docs, commit messages, pull request descriptions and in-app text.

- Short sentences, plain words, active voice. Say the thing, give the number, name the file.
- No em dashes or en dashes. Use a comma, a colon, brackets or a full stop. `scripts/check-docs.sh` fails on them.
- No filler openers or hype words.

## Releasing

Maintainers cut releases. See [docs/RELEASING.md](docs/RELEASING.md).

## Conduct

Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
