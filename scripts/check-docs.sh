#!/bin/bash
# Checks the documentation: relative Markdown links resolve, no em or en dashes in prose, and the
# current version has a changelog entry. Runs in CI and is safe to run locally.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

FAILED=0
fail() { echo "docs check: $*" >&2; FAILED=1; }

FILES="$(find . -name '*.md' -not -path './.build/*' -not -path './build/*' -not -path './dist/*' -not -path './node_modules/*')"

# 1. Relative links and images must point at files that exist.
BROKEN=0
while IFS= read -r file; do
    dir="$(dirname "${file}")"
    # grep exits 1 for a file with no links, which is fine.
    targets="$({ grep -oE '\]\(([^)#]+)(#[^)]*)?\)' "${file}" || true; } | sed -E 's/^\]\(//; s/\)$//; s/#.*$//')"
    while IFS= read -r target; do
        case "${target}" in
            http://*|https://*|mailto:*|"") continue ;;
        esac
        if [ ! -e "${dir}/${target}" ]; then
            echo "docs check: ${file}: broken link: ${target}" >&2
            BROKEN=1
        fi
    done <<< "${targets}"
done <<< "${FILES}"
[ "${BROKEN}" -eq 0 ] || FAILED=1

# 2. No em dashes or en dashes in prose.
if grep -nE '—|–' ${FILES}; then
    fail "em or en dashes found above; use a comma, colon, brackets or a full stop instead"
fi

# 3. The version in Info.plist has a changelog entry.
VERSION="$(sed -n '/CFBundleShortVersionString/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' Sources/Topmost/Resources/Info.plist)"
grep -qE "^## \[${VERSION}\]" CHANGELOG.md || fail "CHANGELOG.md has no entry for version ${VERSION}"

if [ "${FAILED}" -ne 0 ]; then
    exit 1
fi
echo "docs check: ok (${VERSION})"
