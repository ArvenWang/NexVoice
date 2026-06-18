#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
PRODUCT_NAME="NexVoiceApp"
APP_NAME="NexVoice"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$ROOT_DIR/Resources/NexVoiceHost/Info.plist"
SIGN_IDENTITY="${NEXVOICE_CODESIGN_IDENTITY:-}"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"
BUILD_BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BUILD_BIN_DIR/$PRODUCT_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Built executable not found: $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$PRODUCT_NAME"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
if [[ -f "$ROOT_DIR/Resources/NexVoiceHost/SenseVoiceTranscriber.py" ]]; then
  cp "$ROOT_DIR/Resources/NexVoiceHost/SenseVoiceTranscriber.py" "$RESOURCES_DIR/SenseVoiceTranscriber.py"
  chmod 755 "$RESOURCES_DIR/SenseVoiceTranscriber.py"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application|Apple Development/ { print $2; exit }' || true)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null

echo "$APP_DIR"
