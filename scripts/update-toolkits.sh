#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$REPO_ROOT/config/toolkit-version.lock"
INSTALLER_SCRIPT="$SCRIPT_DIR/setup-opencode-toolkits.sh"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-installation.sh"
TARGET="$HOME/.config/opencode"
AI_TOOLKIT_REPO="$HOME/Code/ai-toolkit"

MODE=""

usage() {
  cat <<EOF
Usage: $0 [--latest | --locked | --verify-only]
  --latest       Update ai-toolkit to latest master, refresh lock file, reinstall, verify
  --locked       Re-run installer using the currently locked version, then verify
  --verify-only  Run verification only
EOF
}

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required"
  exit 1
fi

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "ERROR: Lock file not found: $LOCK_FILE"
  exit 1
fi

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --latest) MODE="latest"; shift ;;
    --locked) MODE="locked"; shift ;;
    --verify-only) MODE="verify-only"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

LOCKED_INSTALLER_VERSION="$(jq -r '.version' "$LOCK_FILE")"
LOCKED_AI_VERSION="$(jq -r '."ai-toolkit".version' "$LOCK_FILE")"
LOCKED_COMMIT="$(jq -r '."ai-toolkit".commit' "$LOCK_FILE")"

REPO_POINTER_FILE="$TARGET/.spartan-repo"
if [[ -f "$REPO_POINTER_FILE" ]]; then
  SAVED_REPO="$(tr -d '\r\n' < "$REPO_POINTER_FILE")"
  if [[ -n "$SAVED_REPO" ]]; then
    AI_TOOLKIT_REPO="$SAVED_REPO"
  fi
fi

echo "Current lock version: $LOCKED_INSTALLER_VERSION"
echo "Locked ai-toolkit version: $LOCKED_AI_VERSION"
echo "Locked ai-toolkit commit: $LOCKED_COMMIT"

if [[ "$MODE" == "verify-only" ]]; then
  bash "$VERIFY_SCRIPT"
  exit 0
fi

if [[ -d "$AI_TOOLKIT_REPO/.git" ]]; then
  echo "ai-toolkit repo status:"
  git -C "$AI_TOOLKIT_REPO" status --short || true
else
  echo "ai-toolkit repo not found at $AI_TOOLKIT_REPO"
fi

if [[ -z "$MODE" ]]; then
  echo
  echo "Choose update strategy:"
  echo "  1) Update to latest (git pull)"
  echo "  2) Stay on locked version (re-run installer)"
  echo "  3) Cancel"
  read -r -p "Enter choice [1-3]: " CHOICE
  case "$CHOICE" in
    1) MODE="latest" ;;
    2) MODE="locked" ;;
    3) echo "Cancelled."; exit 0 ;;
    *) echo "Invalid choice"; exit 2 ;;
  esac
fi

if [[ "$MODE" == "latest" ]]; then
  if [[ ! -d "$AI_TOOLKIT_REPO/.git" ]]; then
    echo "ERROR: ai-toolkit repo not found at $AI_TOOLKIT_REPO"
    exit 1
  fi

  git -C "$AI_TOOLKIT_REPO" fetch origin
  git -C "$AI_TOOLKIT_REPO" checkout master
  git -C "$AI_TOOLKIT_REPO" reset --hard origin/master
  git -C "$AI_TOOLKIT_REPO" clean -fd

  NEW_COMMIT="$(git -C "$AI_TOOLKIT_REPO" rev-parse HEAD)"
  VERSION_SOURCE="$AI_TOOLKIT_REPO/toolkit/VERSION"
  if [[ ! -f "$VERSION_SOURCE" ]]; then
    echo "ERROR: Version file missing: $VERSION_SOURCE"
    exit 1
  fi

  NEW_VERSION="$(tr -d '\r\n' < "$VERSION_SOURCE")"
  TODAY="$(date -u +%Y-%m-%d)"
  TMP_FILE="$(mktemp)"

  jq \
    --arg installerVersion "$LOCKED_INSTALLER_VERSION" \
    --arg aiVersion "$NEW_VERSION" \
    --arg commit "$NEW_COMMIT" \
    --arg date "$TODAY" \
    '
      # Lock metadata dates are stored in UTC.
      .version = $installerVersion
      | .last_updated = $date
      | .["ai-toolkit"].version = $aiVersion
      | .["ai-toolkit"].commit = $commit
      | .["ai-toolkit"].verified_date = $date
    ' "$LOCK_FILE" > "$TMP_FILE"
  mv "$TMP_FILE" "$LOCK_FILE"

  bash "$INSTALLER_SCRIPT"
  bash "$VERIFY_SCRIPT"
  exit 0
fi

if [[ "$MODE" == "locked" ]]; then
  bash "$INSTALLER_SCRIPT"
  bash "$VERIFY_SCRIPT"
  exit 0
fi

echo "ERROR: Unknown mode"
exit 1
