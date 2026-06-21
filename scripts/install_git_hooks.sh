#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_DIR="$(git -C "$ROOT_DIR" rev-parse --absolute-git-dir)"
HOOK_TARGET="$GIT_DIR/hooks/pre-commit"

mkdir -p "$(dirname "$HOOK_TARGET")"
cat > "$HOOK_TARGET" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
exec "$ROOT_DIR/.githooks/pre-commit" "$@"
HOOK

chmod +x "$HOOK_TARGET"
chmod +x "$ROOT_DIR/.githooks/pre-commit" "$ROOT_DIR/scripts/bump_version.sh"

echo "Installed NexVoice pre-commit hook at $HOOK_TARGET"
echo "Each commit with staged iteration changes will bump patch version by 0.0.1 and build by 1."
