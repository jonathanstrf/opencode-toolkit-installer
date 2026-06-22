#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/c0x12c/ai-toolkit.git"
DEFAULT_SPARTAN="$HOME/Code/ai-toolkit"
TARGET="$HOME/.config/opencode"
LOG="$TARGET/toolkit-setup.log"

SPARTAN_REPO="$DEFAULT_SPARTAN"
SKIP_SPARTAN=0
SKIP_SUPERPOWERS=0
NO_ENHANCE=0
DRY_RUN=0

usage(){
  cat <<EOF
Usage: $0 [--spartan-repo PATH] [--skip-spartan] [--skip-superpowers] [--no-enhance] [--dry-run]
  --spartan-repo PATH    Path to ai-toolkit repo (default: $DEFAULT_SPARTAN)
  --skip-spartan         Install Superpowers only
  --skip-superpowers     Install Spartan only
  --no-enhance           Skip CLAUDE.md enhancement
  --dry-run              Preview actions without making changes
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --spartan-repo) SPARTAN_REPO="$2"; shift 2;;
    --skip-spartan) SKIP_SPARTAN=1; shift;;
    --skip-superpowers) SKIP_SUPERPOWERS=1; shift;;
    --no-enhance) NO_ENHANCE=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

log(){
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"
}

echo "OpenCode Toolkit Installer"
echo "Target: $TARGET"
if [[ $DRY_RUN -eq 1 ]]; then echo "DRY RUN - no changes will be made"; fi

for cmd in git rsync jq; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "ERROR: $cmd is required"; exit 1
  fi
done

if [[ ! -d "$TARGET" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would create $TARGET"
  else
    mkdir -p "$TARGET"
    log "Created $TARGET"
  fi
fi

########################
# Spartan installation
########################
if [[ $SKIP_SPARTAN -eq 0 ]]; then
  echo "Installing Spartan (ai-toolkit)"
  if [[ ! -d "$SPARTAN_REPO" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Would clone $REPO_URL -> $SPARTAN_REPO"
    else
      git clone "$REPO_URL" "$SPARTAN_REPO"
      log "Cloned ai-toolkit to $SPARTAN_REPO"
    fi
  fi

  BACKUP="$HOME/.config/opencode.backup-toolkits-$(date +%Y%m%d-%H%M%S)"
  if [[ -d "$TARGET" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Would create backup $BACKUP"
    else
      cp -a "$TARGET" "$BACKUP"
      log "Backup created: $BACKUP"
    fi
  fi

  copy_if_exists(){
    local src="$1" dst="$2"
    if [[ -e "$src" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "Would rsync $src -> $dst"
      else
        mkdir -p "$(dirname "$dst")"
        rsync -a --delete "$src" "$dst"
        log "Synced $src -> $dst"
      fi
    else
      echo "Warning: $src not found, skipping"
    fi
  }

  copy_if_exists "$SPARTAN_REPO/.opencode/commands/" "$TARGET/commands/"
  copy_if_exists "$SPARTAN_REPO/commands/" "$TARGET/commands/"
  copy_if_exists "$SPARTAN_REPO/.opencode/skills/" "$TARGET/skills/"
  copy_if_exists "$SPARTAN_REPO/skills/" "$TARGET/skills/"
  copy_if_exists "$SPARTAN_REPO/CLAUDE.md" "$TARGET/CLAUDE.md"
  copy_if_exists "$SPARTAN_REPO/.opencode/.spartan-version" "$TARGET/.spartan-version"
  copy_if_exists "$SPARTAN_REPO/.opencode/.spartan-packs" "$TARGET/.spartan-packs"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would write .spartan-repo -> $SPARTAN_REPO"
  else
    echo "$SPARTAN_REPO" > "$TARGET/.spartan-repo"
    log "Wrote .spartan-repo -> $SPARTAN_REPO"
  fi

  if [[ $NO_ENHANCE -eq 0 ]]; then
    if [[ -f "$(dirname "$0")/enhance-claude-portable.sh" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "Would run enhancement script"
      else
        bash "$(dirname "$0")/enhance-claude-portable.sh"
        log "Ran enhancer"
      fi
    else
      echo "Enhancer script not found, skipping enhancement"
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would count commands/skills in $TARGET"
  else
    CMD_COUNT=$(find "$TARGET/commands" -type f 2>/dev/null | wc -l || true)
    SKILL_COUNT=$(find "$TARGET/skills" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | wc -l || true)
    log "Spartan verification: commands=$CMD_COUNT, skills=$SKILL_COUNT"
    echo "Spartan installed. Commands: $CMD_COUNT; Skills (dirs): $SKILL_COUNT"
  fi
fi

########################
# Superpowers installation
########################
if [[ $SKIP_SUPERPOWERS -eq 0 ]]; then
  echo "Installing Superpowers (OpenCode plugin)"
  O_JF="$TARGET/opencode.json"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would merge superpowers entry into $O_JF"
  else
    # Ensure opencode.json exists
    if [[ ! -f "$O_JF" ]]; then
      echo '{"plugin": []}' > "$O_JF"
      log "Created minimal $O_JF"
    fi

    # Merge plugin safely using jq
    TMP=$(mktemp)
    jq '.plugin += ["superpowers@git+https://github.com/obra/superpowers.git"] | .plugin |= (unique)' "$O_JF" > "$TMP"
    mv "$TMP" "$O_JF"
    log "Merged superpowers plugin into $O_JF"
    echo "Added superpowers plugin to $O_JF"
  fi
fi

echo "Installation complete. Logs: $LOG"
echo "Next: restart OpenCode to load plugins. Verify: ask 'Tell me about your superpowers' and test /spartan commands."

exit 0
