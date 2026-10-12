#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION="0.1.0"
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
echo "==> Signing ${APP_NAME}.app..."
SIGN_ID="${SIGNING_IDENTITY:--}"
ENTITLEMENTS="${ROOT_DIR}/Sources/Topmost/Resources/Topmost.entitlements"

codesign --force --options runtime --deep --sign "${SIGN_ID}" \
    --entitlements "${ENTITLEMENTS}" \
    "${APP_BUNDLE}"

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
