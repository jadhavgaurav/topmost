#!/bin/bash
# Installs the latest Topmost release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/jadhavgaurav/topmost/main/install.sh | bash
#
# It downloads the DMG from the GitHub release, checks it against the release's SHA256SUMS,
# copies Topmost.app to /Applications, and clears the quarantine flag so macOS does not block the
# first launch of this ad-hoc signed build. Set TOPMOST_VERSION (for example v0.2.0) to install
# a specific release instead of the latest. Set TOPMOST_DRY_RUN=1 to download and verify only.
set -euo pipefail

REPO="jadhavgaurav/topmost"
APP="Topmost"
DEST="/Applications/${APP}.app"

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Topmost only runs on macOS."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "${MAJOR}" -ge 14 ] || fail "Topmost needs macOS 14 or later (this Mac runs $(sw_vers -productVersion))."

TAG="${TOPMOST_VERSION:-}"
if [ -z "${TAG}" ]; then
    TAG="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
    [ -n "${TAG}" ] || fail "could not find the latest release of ${REPO}."
fi

BASE="https://github.com/${REPO}/releases/download/${TAG}"
DMG="${APP}-${TAG}-macos-universal.dmg"

WORK="$(mktemp -d)"
MOUNT="${WORK}/mount"
cleanup() {
    hdiutil detach "${MOUNT}" -quiet 2>/dev/null || true
    rm -rf "${WORK}"
}
trap cleanup EXIT

say "==> Downloading ${APP} ${TAG}"
curl -fsSL -o "${WORK}/${DMG}" "${BASE}/${DMG}" || fail "could not download ${BASE}/${DMG}"
curl -fsSL -o "${WORK}/SHA256SUMS" "${BASE}/SHA256SUMS" || fail "could not download the checksums for ${TAG}."

say "==> Verifying the download"
EXPECTED="$(awk -v name="${DMG}" '$2 == name { print $1 }' "${WORK}/SHA256SUMS")"
ACTUAL="$(shasum -a 256 "${WORK}/${DMG}" | awk '{ print $1 }')"
[ -n "${EXPECTED}" ] || fail "${DMG} is not listed in SHA256SUMS."
[ "${EXPECTED}" = "${ACTUAL}" ] || fail "checksum mismatch, refusing to install. Expected ${EXPECTED}, got ${ACTUAL}."

if [ -n "${TOPMOST_DRY_RUN:-}" ]; then
    say "==> Verified ${DMG} (${ACTUAL}). Dry run, nothing installed."
    exit 0
fi

say "==> Installing to ${DEST}"
mkdir -p "${MOUNT}"
hdiutil attach "${WORK}/${DMG}" -nobrowse -readonly -quiet -mountpoint "${MOUNT}"
pkill -x "${APP}" 2>/dev/null || true
rm -rf "${DEST}"
cp -R "${MOUNT}/${APP}.app" "${DEST}"
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

say "==> Done. Opening ${APP}"
open "${DEST}"
say ""
say "Grant Accessibility and Screen Recording when asked (System Settings > Privacy & Security),"
say "then focus any window and press Control + Command + P."
