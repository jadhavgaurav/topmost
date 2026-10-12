#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_NAME="Topmost"
APP_BUNDLE="${ROOT_DIR}/build/${APP_NAME}.app"
DEST_PATH="/Applications/${APP_NAME}.app"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> Application bundle not found, packaging now..."
    "${SCRIPT_DIR}/package.sh"
fi

echo "==> Installing ${APP_NAME}.app into /Applications..."
# Terminate running instances if any
pkill -x "${APP_NAME}" 2>/dev/null || true

rm -rf "${DEST_PATH}"
cp -R "${APP_BUNDLE}" "${DEST_PATH}"

# Clear quarantine attribute for local development installation
xattr -dr com.apple.quarantine "${DEST_PATH}" 2>/dev/null || true

echo "========================================="
echo "Successfully installed: ${DEST_PATH}"
echo "Launch with: open /Applications/${APP_NAME}.app"
echo "========================================="
