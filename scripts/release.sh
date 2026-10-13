#!/bin/bash
# Cuts a release: checks everything is consistent, then creates and pushes the version tag.
# Pushing the tag starts the Release workflow, which tests, builds, and publishes the GitHub
# release with the DMG, the zip and the checksums.
#
#   scripts/release.sh             tag and push the version in Info.plist
#   scripts/release.sh --dry-run   run every check, change nothing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Topmost/Resources/Info.plist)"
TAG="v${VERSION}"

fail() { echo "error: $*" >&2; exit 1; }

echo "==> Releasing ${TAG}"

[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fail "releases are cut from main"
[ -z "$(git status --porcelain)" ] || fail "the working tree has uncommitted changes"

git fetch --quiet origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "main is not in sync with origin/main (push or pull first)"
git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null && fail "tag ${TAG} already exists"

echo "==> Checking the changelog entry"
"${SCRIPT_DIR}/release-notes.sh" "${VERSION}" >/dev/null || fail "add a ## [${VERSION}] section to CHANGELOG.md"

echo "==> Running lint and tests"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-/Library/Developer/CommandLineTools}" swiftlint lint --strict --quiet
"${SCRIPT_DIR}/test.sh"

if [ "${DRY_RUN}" = "1" ]; then
    echo "==> Dry run complete. ${TAG} is ready to tag."
    exit 0
fi

echo "==> Tagging and pushing ${TAG}"
git tag -a "${TAG}" -m "Topmost ${VERSION}"
git push origin "${TAG}"

echo "========================================="
echo "Pushed ${TAG}. The Release workflow now builds and publishes it:"
echo "https://github.com/jadhavgaurav/topmost/actions/workflows/release.yml"
echo "========================================="
