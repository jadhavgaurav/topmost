#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION="v0.1.0"
REPO="jadhavgaurav/topmost"
DIST_DIR="${ROOT_DIR}/dist"

echo "========================================="
echo "Preparing Release ${VERSION} for ${REPO}"
echo "========================================="

# 1. Run Tests
echo "==> Running automated test suite..."
"${SCRIPT_DIR}/test.sh"

# 2. Package App
echo "==> Building and packaging release..."
"${SCRIPT_DIR}/package.sh"

# 3. Verify gh CLI authentication
echo "==> Verifying GitHub CLI status..."
gh auth status

# 4. Publish Release
echo "==> Publishing release ${VERSION}..."
gh release create "${VERSION}" \
    --repo "${REPO}" \
    --title "Topmost ${VERSION} – Native macOS Always on Top" \
    --notes-file "${ROOT_DIR}/docs/RELEASE.md" \
    "${DIST_DIR}"/Topmost-*.zip \
    "${DIST_DIR}"/Topmost-*.dmg \
    "${DIST_DIR}"/SHA256SUMS

echo "========================================="
echo "Release published successfully!"
echo "View release at: https://github.com/${REPO}/releases/tag/${VERSION}"
echo "========================================="
