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

# Build arm64
echo "==> Compiling for arm64..."
swift build -c release --triple arm64-apple-macosx14.0 --scratch-path "${BUILD_DIR}/scratch-arm64"
ARM64_BIN="${BUILD_DIR}/scratch-arm64/out/Products/Release/Topmost"

# Build x86_64
echo "==> Compiling for x86_64..."
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "${BUILD_DIR}/scratch-x86_64"
X86_BIN="${BUILD_DIR}/scratch-x86_64/out/Products/Release/Topmost"

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
