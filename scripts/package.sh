#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

INFO_PLIST="${ROOT_DIR}/Sources/Topmost/Resources/Info.plist"
# The version lives in Info.plist only. Set VERSION in the environment to override it for a test build.
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")}"
APP_NAME="Topmost"
APP_BUNDLE="${ROOT_DIR}/build/${APP_NAME}.app"
DIST_DIR="${ROOT_DIR}/dist"

echo "========================================="
echo "Packaging ${APP_NAME} v${VERSION}"
echo "========================================="

# 1. Ensure build is ready
if [ ! -f "${ROOT_DIR}/build/Topmost" ]; then
    echo "==> Building executable first..."
    "${SCRIPT_DIR}/build.sh"
fi

# 2. Assemble App Bundle
echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${ROOT_DIR}/build/Topmost" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cp "${ROOT_DIR}/Sources/Topmost/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${ROOT_DIR}/Sources/Topmost/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# 3. Code Signing
#
# Which identity signs the app:
#   1. SIGNING_IDENTITY, if set (for example a Developer ID Application certificate).
#   2. The local development identity from ./scripts/setup-signing.sh, if it exists. It keeps
#      macOS's Accessibility and Screen Recording approvals across rebuilds, which an ad-hoc
#      signature cannot. Skipped for release builds (TOPMOST_RELEASE=1 or CI), so published
#      artifacts never depend on one person's keychain.
#   3. Ad-hoc otherwise. First launch on another Mac needs "Open Anyway" in System Settings.
echo "==> Signing ${APP_NAME}.app..."
ENTITLEMENTS="${ROOT_DIR}/Sources/Topmost/Resources/Topmost.entitlements"
SIGN_DIR="${HOME}/.topmost-signing"
LOCAL_KEYCHAIN="${SIGN_DIR}/topmost-signing.keychain-db"
LOCAL_IDENTITY="Topmost Local Signing"

if [ -n "${SIGNING_IDENTITY:-}" ]; then
    echo "    identity: ${SIGNING_IDENTITY}"
    codesign --force --options runtime --deep --sign "${SIGNING_IDENTITY}" \
        --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"
elif [ -z "${TOPMOST_RELEASE:-}" ] && [ -z "${CI:-}" ] && [ -f "${LOCAL_KEYCHAIN}" ]; then
    echo "    identity: local development identity (${LOCAL_IDENTITY})"
    security unlock-keychain -p "$(<"${SIGN_DIR}/keychain-password")" "${LOCAL_KEYCHAIN}"
    codesign --force --options runtime --deep --keychain "${LOCAL_KEYCHAIN}" --sign "${LOCAL_IDENTITY}" \
        --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"
else
    echo "    identity: ad-hoc"
    codesign --force --options runtime --deep --sign - \
        --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"
fi

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

# 4. Packaging Release Artifacts
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR:?}"/*

ZIP_NAME="Topmost-v${VERSION}-macos-universal.zip"
DMG_NAME="Topmost-v${VERSION}-macos-universal.dmg"

echo "==> Creating ZIP archive: ${ZIP_NAME}..."
ditto -c -k --keepParent "${APP_BUNDLE}" "${DIST_DIR}/${ZIP_NAME}"

echo "==> Creating DMG image: ${DMG_NAME}..."
DMG_STAGING="${ROOT_DIR}/build/dmg_staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"
rm -rf "${DMG_STAGING}"

# 5. Checksums
echo "==> Generating SHA256 checksums..."
cd "${DIST_DIR}"
shasum -a 256 *.zip *.dmg > SHA256SUMS
cat SHA256SUMS

echo "========================================="
echo "Packaging complete!"
echo "Artifacts available in: ${DIST_DIR}"
echo "========================================="
