#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="debug"
EMBED_LOCAL_KEYS="${NEXVOICE_EMBED_LOCAL_KEYS:-0}"
for arg in "$@"; do
  case "$arg" in
    debug|release)
      CONFIGURATION="$arg"
      ;;
    --embed-local-keys)
      EMBED_LOCAL_KEYS="1"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done
PRODUCT_NAME="NexVoiceApp"
APP_NAME="NexVoice"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EMBEDDED_CONFIG_DIR="$RESOURCES_DIR/NexVoiceEmbeddedConfig"
INFO_PLIST="$ROOT_DIR/Resources/NexVoiceHost/Info.plist"
SIGN_IDENTITY="${NEXVOICE_CODESIGN_IDENTITY:-}"
APP_SUPPORT_DIR="$HOME/Library/Application Support/NexVoice"
SETTINGS_WEB_DIR="$ROOT_DIR/SettingsWeb"
SETTINGS_WEB_DIST_DIR="$SETTINGS_WEB_DIR/dist"

cd "$ROOT_DIR"
if [[ -f "$SETTINGS_WEB_DIR/package.json" ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to build SettingsWeb." >&2
    exit 1
  fi
  if [[ ! -d "$SETTINGS_WEB_DIR/node_modules" ]]; then
    (cd "$SETTINGS_WEB_DIR" && npm install)
  fi
  (cd "$SETTINGS_WEB_DIR" && npm run build)
fi
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/nexvoice-clang-cache}"
swift build --disable-sandbox -c "$CONFIGURATION" --product "$PRODUCT_NAME"
BUILD_BIN_DIR="$(swift build --disable-sandbox -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BUILD_BIN_DIR/$PRODUCT_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Built executable not found: $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$PRODUCT_NAME"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"
if [[ -f "$ROOT_DIR/Resources/NexVoiceHost/SenseVoiceTranscriber.py" ]]; then
  cp "$ROOT_DIR/Resources/NexVoiceHost/SenseVoiceTranscriber.py" "$RESOURCES_DIR/SenseVoiceTranscriber.py"
  chmod 755 "$RESOURCES_DIR/SenseVoiceTranscriber.py"
fi
if [[ -d "$SETTINGS_WEB_DIST_DIR" ]]; then
  mkdir -p "$RESOURCES_DIR/SettingsWeb"
  cp -R "$SETTINGS_WEB_DIST_DIR"/. "$RESOURCES_DIR/SettingsWeb/"
fi
if [[ "$EMBED_LOCAL_KEYS" == "1" || "$EMBED_LOCAL_KEYS" == "true" ]]; then
  mkdir -p "$EMBEDDED_CONFIG_DIR"

  for config_file in DeepSeek.json TencentCloudASR.json; do
    source_file="$APP_SUPPORT_DIR/$config_file"
    target_file="$EMBEDDED_CONFIG_DIR/$config_file"
    if [[ ! -s "$source_file" ]]; then
      echo "Missing local credential file: $source_file" >&2
      exit 1
    fi
    cp "$source_file" "$target_file"
    chmod 600 "$target_file"
  done

  echo "Embedded local credential files for private local app package." >&2
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application|Apple Development/ { print $2; exit }' || true)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null

echo "$APP_DIR"
