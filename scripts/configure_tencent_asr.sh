#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/Library/Application Support/NexVoice"
CONFIG_FILE="$CONFIG_DIR/TencentCloudASR.json"

APP_ID="${NEXVOICE_TENCENT_ASR_APP_ID:-}"
SECRET_ID="${NEXVOICE_TENCENT_ASR_SECRET_ID:-}"
SECRET_KEY="${NEXVOICE_TENCENT_ASR_SECRET_KEY:-}"

if [[ -z "$APP_ID" ]]; then
  read -r -p "Tencent Cloud AppID: " APP_ID
fi

if [[ -z "$SECRET_ID" ]]; then
  read -r -p "Tencent Cloud SecretId: " SECRET_ID
fi

if [[ -z "$SECRET_KEY" ]]; then
  read -r -s -p "Tencent Cloud SecretKey: " SECRET_KEY
  printf '\n'
fi

if [[ -z "$APP_ID" || -z "$SECRET_ID" || -z "$SECRET_KEY" ]]; then
  echo "AppID, SecretId, and SecretKey are all required." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
umask 077
python3 - "$CONFIG_FILE" "$APP_ID" "$SECRET_ID" "$SECRET_KEY" <<'PY'
import json
import sys

path, app_id, secret_id, secret_key = sys.argv[1:5]
with open(path, "w", encoding="utf-8") as file:
    json.dump(
        {
            "appID": app_id,
            "secretID": secret_id,
            "secretKey": secret_key,
        },
        file,
        ensure_ascii=False,
        indent=2,
    )
    file.write("\n")
PY
chmod 600 "$CONFIG_FILE"
echo "Tencent Cloud ASR config saved to $CONFIG_FILE"
