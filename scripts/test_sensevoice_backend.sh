#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${NEXVOICE_SENSEVOICE_DIR:-$HOME/Library/Application Support/NexVoice/SenseVoice}"
MODEL_NAME="sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
MODEL_DIR="$BACKEND_DIR/$MODEL_NAME"
PYTHON="$BACKEND_DIR/.venv/bin/python"
SCRIPT="$ROOT_DIR/Resources/NexVoiceHost/SenseVoiceTranscriber.py"
TEST_WAV="${1:-$MODEL_DIR/test_wavs/zh.wav}"

if [[ ! -x "$PYTHON" ]]; then
  echo "SenseVoice Python environment is missing. Run scripts/install_sensevoice_backend.sh first." >&2
  exit 1
fi

"$PYTHON" "$SCRIPT" \
  --model "$MODEL_DIR/model.int8.onnx" \
  --tokens "$MODEL_DIR/tokens.txt" \
  --wave "$TEST_WAV" \
  --language auto \
  --use-itn 1 \
  --num-threads 4
