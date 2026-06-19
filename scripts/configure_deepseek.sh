#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/Library/Application Support/NexVoice"
CONFIG_FILE="$CONFIG_DIR/DeepSeek.json"

API_KEY="${NEXVOICE_DEEPSEEK_API_KEY:-}"

if [[ -z "$API_KEY" ]]; then
  read -r -s -p "DeepSeek API Key: " API_KEY
  printf '\n'
fi

if [[ -z "$API_KEY" ]]; then
  echo "DeepSeek API Key is required." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
umask 077
python3 - "$CONFIG_FILE" "$API_KEY" <<'PY'
import json
import sys

path, api_key = sys.argv[1:3]
with open(path, "w", encoding="utf-8") as file:
    json.dump(
        {
            "apiKey": api_key,
        },
        file,
        ensure_ascii=False,
        indent=2,
    )
    file.write("\n")
PY
chmod 600 "$CONFIG_FILE"
echo "DeepSeek config saved to $CONFIG_FILE"
