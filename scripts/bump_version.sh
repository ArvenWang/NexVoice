#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

VERSION_PLISTS=(
  "Resources/NexVoiceHost/Info.plist"
)

if [[ "${NEXVOICE_SKIP_VERSION_BUMP:-0}" == "1" ]]; then
  echo "NexVoice version bump skipped by NEXVOICE_SKIP_VERSION_BUMP=1." >&2
  exit 0
fi

host_plist="$ROOT_DIR/${VERSION_PLISTS[0]}"
current_version="$("$PLIST_BUDDY" -c "Print CFBundleShortVersionString" "$host_plist")"
current_build="$("$PLIST_BUDDY" -c "Print CFBundleVersion" "$host_plist")"

IFS="." read -r major minor patch extra <<< "$current_version"
if [[ -n "${extra:-}" || -z "${major:-}" || -z "${minor:-}" || -z "${patch:-}" ]]; then
  echo "Unsupported CFBundleShortVersionString: $current_version" >&2
  exit 1
fi
if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
  echo "Version must use numeric major.minor.patch: $current_version" >&2
  exit 1
fi
if ! [[ "$current_build" =~ ^[0-9]+$ ]]; then
  echo "CFBundleVersion must be numeric: $current_build" >&2
  exit 1
fi

next_version="${major}.${minor}.$((patch + 1))"
next_build="$((current_build + 1))"

for relative_plist in "${VERSION_PLISTS[@]}"; do
  plist="$ROOT_DIR/$relative_plist"
  if [[ ! -f "$plist" ]]; then
    echo "Missing Info.plist: $relative_plist" >&2
    exit 1
  fi
  "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $next_version" "$plist"
  "$PLIST_BUDDY" -c "Set :CFBundleVersion $next_build" "$plist"
done

echo "NexVoice version bumped: $current_version -> $next_version (build $current_build -> $next_build)."
