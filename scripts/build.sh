#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "========================================="
echo "Building Topmost (Universal Release)"
echo "========================================="

BUILD_DIR="${ROOT_DIR}/build"
mkdir -p "${BUILD_DIR}"

# Build one architecture and print the path of the product. SwiftPM decides where the binary goes,
# and that differs between toolchains, so ask it with --show-bin-path instead of guessing.
build_arch() {
    local arch="$1"
    local scratch="${BUILD_DIR}/scratch-${arch}"
    local triple="${arch}-apple-macosx14.0"
    echo "==> Compiling for ${arch}..." >&2
    swift build -c release --triple "${triple}" --scratch-path "${scratch}" >&2
    local bin_dir
    bin_dir="$(swift build -c release --triple "${triple}" --scratch-path "${scratch}" --show-bin-path)"
    echo "${bin_dir}/Topmost"
}

ARM64_BIN="$(build_arch arm64)"
X86_BIN="$(build_arch x86_64)"

for bin in "${ARM64_BIN}" "${X86_BIN}"; do
    [ -f "${bin}" ] || { echo "error: expected a built binary at ${bin}" >&2; exit 1; }
done

# Combine into Universal binary
OUTPUT_BIN="${BUILD_DIR}/Topmost"
echo "==> Creating universal binary with lipo..."
lipo -create "${ARM64_BIN}" "${X86_BIN}" -output "${OUTPUT_BIN}"

echo "==> Binary verified:"
lipo -info "${OUTPUT_BIN}"
file "${OUTPUT_BIN}"

echo "========================================="
echo "Build succeeded: ${OUTPUT_BIN}"
echo "========================================="
