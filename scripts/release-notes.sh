#!/bin/bash
# Prints the CHANGELOG.md section for one version, followed by the standard install footer.
# Used by the Release workflow and by scripts/release.sh, so the GitHub release body always
# matches the changelog.
#
#   scripts/release-notes.sh 0.2.0
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?usage: release-notes.sh <version, for example 0.2.0>}"
VERSION="${VERSION#v}"

SECTION="$(awk -v version="${VERSION}" '
  /^## / {
    if (printing) { exit }
    heading = $0
    gsub(/^## \[?/, "", heading)
    sub(/[\] ].*$/, "", heading)
    if (heading == version) { printing = 1; next }
  }
  printing { print }
' "${ROOT_DIR}/CHANGELOG.md")"

if [ -z "$(printf '%s' "${SECTION}" | tr -d '[:space:]')" ]; then
    echo "CHANGELOG.md has no entry for version ${VERSION}" >&2
    exit 1
fi

printf '%s\n\n' "${SECTION}"
cat "${ROOT_DIR}/.github/release-footer.md"
