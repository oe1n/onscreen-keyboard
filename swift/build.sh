#!/usr/bin/env bash
# Build OnScreenKeyboard.app bundle from the SwiftPM executable.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-release}"
APP_NAME="OnScreen Keyboard"
APP_DIR="build/${APP_NAME}.app"
EXEC_NAME="OnScreenKeyboard"

echo ">> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}/${EXEC_NAME}" "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"
cp Info.plist "${APP_DIR}/Contents/Info.plist"

# Ad-hoc sign so CGEventTap / CoreMIDI permissions stick to a stable identity.
codesign --force --deep --sign - "${APP_DIR}"

echo
echo "✅ Built: ${APP_DIR}"
echo "   Size: $(du -sh "${APP_DIR}" | awk '{print $1}')"
echo
echo "Run with:  open \"${APP_DIR}\""
