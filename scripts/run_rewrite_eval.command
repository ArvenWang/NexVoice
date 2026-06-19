#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/nefish/Desktop/Coding/NexVoice"
REPORT_DIR="$PROJECT_DIR/eval_reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_FILE="$REPORT_DIR/deepseek-rewrite-eval-$TIMESTAMP.md"

cd "$PROJECT_DIR"

.build/debug/NexVoiceRewriteEval --output "$REPORT_FILE"

echo
echo "Report saved to $REPORT_FILE"
echo "Press any key to close..."
read -k 1
