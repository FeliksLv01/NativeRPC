#!/bin/sh

# Builds the NativeRPCKitMacros executable for CocoaPods distribution.
# Usage: ./build.sh

set -e

cd "$(dirname "$0")"

MACRO_NAME="NativeRPCKitMacros"
OUTPUT_DIR="./Prebuilt"
BUILD_CONFIG="release"
mkdir -p "${OUTPUT_DIR}"

echo "Building ${MACRO_NAME}..."

swift build --product "${MACRO_NAME}" -c "${BUILD_CONFIG}" -Xswiftc -Osize

BIN_PATH_ROOT=$(swift build --product "${MACRO_NAME}" -c "${BUILD_CONFIG}" --show-bin-path)

FOUND_BINARY=$(find "${BIN_PATH_ROOT}" -name "${MACRO_NAME}" -type f -not -path "*.dSYM*" | head -n 1)
if [ -z "${FOUND_BINARY}" ]; then
    FOUND_BINARY=$(find "${BIN_PATH_ROOT}" -name "${MACRO_NAME}-tool" -type f -not -path "*.dSYM*" | head -n 1)
fi

if [ -n "${FOUND_BINARY}" ]; then
    echo "Found binary at ${FOUND_BINARY}"
    cp "${FOUND_BINARY}" "${OUTPUT_DIR}/${MACRO_NAME}"
    chmod u+x "${OUTPUT_DIR}/${MACRO_NAME}"
    strip -x "${OUTPUT_DIR}/${MACRO_NAME}"
    echo "Success! Macro executable is at ${OUTPUT_DIR}/${MACRO_NAME}"
else
    echo "Error: ${MACRO_NAME} executable not found in ${BIN_PATH_ROOT}"
    ls -F "${BIN_PATH_ROOT}"
    exit 1
fi
