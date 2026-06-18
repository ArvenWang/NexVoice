#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${NEXVOICE_SENSEVOICE_DIR:-$HOME/Library/Application Support/NexVoice/SenseVoice}"
MODEL_NAME="sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
MODEL_ARCHIVE="$MODEL_NAME.tar.bz2"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$MODEL_ARCHIVE"
MODEL_DIR="$BACKEND_DIR/$MODEL_NAME"
PYTHON="$BACKEND_DIR/.venv/bin/python"

mkdir -p "$BACKEND_DIR"

if [[ ! -x "$PYTHON" ]]; then
  python3 -m venv "$BACKEND_DIR/.venv"
fi

"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install --upgrade sherpa-onnx soundfile numpy

if [[ ! -f "$MODEL_DIR/model.int8.onnx" || ! -f "$MODEL_DIR/tokens.txt" ]]; then
  TMP_ARCHIVE="$BACKEND_DIR/$MODEL_ARCHIVE"
  curl --fail --location --output "$TMP_ARCHIVE" "$MODEL_URL"
  tar -xjf "$TMP_ARCHIVE" -C "$BACKEND_DIR"
  rm -f "$TMP_ARCHIVE"
fi

if [[ ! -f "$ROOT_DIR/Resources/NexVoiceHost/SenseVoiceTranscriber.py" ]]; then
  echo "SenseVoiceTranscriber.py not found in project resources." >&2
  exit 1
fi

echo "$BACKEND_DIR"
