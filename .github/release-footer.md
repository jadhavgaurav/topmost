---

## Install

One line:

```bash
curl -fsSL https://raw.githubusercontent.com/jadhavgaurav/topmost/main/install.sh | bash
```

Or by hand: download the `.dmg` below, open it, and drag **Topmost** onto **Applications**.

macOS will refuse the first launch, because this build is signed ad hoc rather than with a paid Apple Developer ID. Click **Done** (never Move to Trash), then open **System Settings > Privacy & Security** and click **Open Anyway**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Topmost.app
```

Topmost needs two permissions: **Accessibility** and **Screen Recording**. Grant both under **System Settings > Privacy & Security**, then focus any window and press **Control + Command + P**.

Check a download against the published checksums:

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing
```

Requires macOS 14 or later. Apple Silicon and Intel.
