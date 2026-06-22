#!/usr/bin/env bash

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Attempting to install jq..."

  if [[ "$(uname -s)" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install jq
    else
      echo "ERROR: Homebrew not found. Install jq manually: https://jqlang.org/download/"
      exit 1
    fi
  elif [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      ubuntu|debian)
        if command -v apt-get >/dev/null 2>&1; then
          sudo apt-get update
          sudo apt-get install -y jq
        else
          echo "ERROR: apt-get not found. Install jq manually: https://jqlang.org/download/"
          exit 1
        fi
        ;;
      rhel|centos|rocky|almalinux|fedora)
        if command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y jq
        elif command -v yum >/dev/null 2>&1; then
          sudo yum install -y jq
        else
          echo "ERROR: dnf/yum not found. Install jq manually: https://jqlang.org/download/"
          exit 1
        fi
        ;;
      *)
        echo "ERROR: Unsupported Linux distribution for automatic jq install."
        echo "Install jq manually: https://jqlang.org/download/"
        exit 1
        ;;
    esac
  else
    echo "ERROR: Could not detect platform for automatic jq install."
    echo "Install jq manually: https://jqlang.org/download/"
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq installation failed"
    exit 1
  fi

  echo "jq installed successfully."
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$REPO_ROOT/config/toolkit-version.lock"
CONFIG_TEMPLATE="$REPO_ROOT/config/opencode.template.json"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "ERROR: Lock file not found: $LOCK_FILE"
  exit 1
fi

LOCK_TOOLKIT_VERSION="$(jq -r '.version' "$LOCK_FILE")"
LOCK_REPO_URL="$(jq -r '."ai-toolkit".repo' "$LOCK_FILE")"
LOCK_AI_TOOLKIT_VERSION="$(jq -r '."ai-toolkit".version' "$LOCK_FILE")"
LOCK_COMMIT="$(jq -r '."ai-toolkit".commit' "$LOCK_FILE")"
TOOLKIT_ROOT_RELATIVE="toolkit"

REPO_URL="$LOCK_REPO_URL"
DEFAULT_SPARTAN="$HOME/Code/ai-toolkit"
TARGET="$HOME/.config/opencode"
LOG="$TARGET/toolkit-setup.log"

SPARTAN_REPO="$DEFAULT_SPARTAN"
SKIP_SPARTAN=0
SKIP_SUPERPOWERS=0
NO_ENHANCE=0
DRY_RUN=0
APPLY_CONFIG=0
VERIFY_INSTALL=0

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

merge_json_file(){
  local source_file="$1" target_file="$2" tmp_file
  tmp_file="$(mktemp)"

  if [[ ! -f "$target_file" ]]; then
    cp "$source_file" "$target_file"
    log "Copied config template to $target_file"
    return 0
  fi

  jq -s '
    def deepmerge(a; b):
      if (a | type) == "object" and (b | type) == "object" then
        reduce ((a | keys_unsorted[]) + (b | keys_unsorted[]) | unique[]) as $key
          ({};
            .[$key] = if (a[$key] == null) then b[$key]
              elif (b[$key] == null) then a[$key]
              elif ($key == "agent") then b[$key]
              else deepmerge(a[$key]; b[$key])
              end
          )
      elif (a | type) == "array" and (b | type) == "array" then
        (a + b | unique)
      else
        a
      end;
    deepmerge(.[0]; .[1])
  ' "$target_file" "$source_file" > "$tmp_file"

  mv "$tmp_file" "$target_file"
  log "Merged template config into $target_file"
}

validate_json_file(){
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo "ERROR: JSON file not found: $file_path"
    exit 1
  fi

  jq empty "$file_path" >/dev/null
}

usage(){
  cat <<EOF
Usage: $0 [--spartan-repo PATH] [--skip-spartan] [--skip-superpowers] [--no-enhance] [--apply-config] [--verify] [--dry-run]
  --spartan-repo PATH    Path to ai-toolkit repo (default: $DEFAULT_SPARTAN)
  --skip-spartan         Install Superpowers only
  --skip-superpowers     Install Spartan only
  --no-enhance           Skip CLAUDE.md enhancement
  --apply-config         Merge config/opencode.template.json into $TARGET/opencode.json
  --verify               Run scripts/verify-installation.sh after install
  --dry-run              Preview actions without making changes
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --spartan-repo) SPARTAN_REPO="$2"; shift 2;;
    --skip-spartan) SKIP_SPARTAN=1; shift;;
    --skip-superpowers) SKIP_SUPERPOWERS=1; shift;;
    --no-enhance) NO_ENHANCE=1; shift;;
    --apply-config) APPLY_CONFIG=1; shift;;
    --verify) VERIFY_INSTALL=1; shift;;
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
echo "Toolkit lock version: $LOCK_TOOLKIT_VERSION"
echo "Locked ai-toolkit version: $LOCK_AI_TOOLKIT_VERSION"
echo "Locked ai-toolkit commit: $LOCK_COMMIT"
if [[ $DRY_RUN -eq 1 ]]; then echo "DRY RUN - no changes will be made"; fi

for cmd in git rsync jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
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
      mkdir -p "$(dirname "$SPARTAN_REPO")"
      git clone "$REPO_URL" "$SPARTAN_REPO"
      log "Cloned ai-toolkit to $SPARTAN_REPO"
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would fetch and checkout locked commit $LOCK_COMMIT in $SPARTAN_REPO"
  else
    git -C "$SPARTAN_REPO" fetch origin
    git -C "$SPARTAN_REPO" reset --hard "$LOCK_COMMIT"
    git -C "$SPARTAN_REPO" clean -fd
    git -C "$SPARTAN_REPO" checkout "$LOCK_COMMIT"
    log "Checked out ai-toolkit commit $LOCK_COMMIT"
  fi

  TOOLKIT_ROOT="$SPARTAN_REPO/$TOOLKIT_ROOT_RELATIVE"
  if [[ ! -d "$TOOLKIT_ROOT" ]]; then
    echo "ERROR: Expected toolkit root not found: $TOOLKIT_ROOT"
    exit 1
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

  copy_if_exists "$TOOLKIT_ROOT/commands/" "$TARGET/commands/"
  copy_if_exists "$TOOLKIT_ROOT/skills/" "$TARGET/skills/"
  copy_if_exists "$SPARTAN_REPO/CLAUDE.md" "$TARGET/CLAUDE.md"
  if [[ -f "$TOOLKIT_ROOT/VERSION" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Would copy $TOOLKIT_ROOT/VERSION -> $TARGET/.spartan-version"
    else
      cp "$TOOLKIT_ROOT/VERSION" "$TARGET/.spartan-version"
      log "Copied $TOOLKIT_ROOT/VERSION -> $TARGET/.spartan-version"
    fi
  else
    echo "Warning: $TOOLKIT_ROOT/VERSION not found, skipping"
  fi

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

if [[ $APPLY_CONFIG -eq 1 ]]; then
  echo "Applying config template"
  if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
    echo "Warning: Config template not found at $CONFIG_TEMPLATE, skipping"
  elif [[ $DRY_RUN -eq 1 ]]; then
    validate_json_file "$CONFIG_TEMPLATE"
    if [[ -f "$TARGET/opencode.json" ]]; then
      validate_json_file "$TARGET/opencode.json"
    fi
    echo "Would merge $CONFIG_TEMPLATE -> $TARGET/opencode.json"
  else
    if [[ ! -d "$TARGET" ]]; then
      echo "ERROR: Target directory missing: $TARGET"
      exit 1
    fi
    mkdir -p "$TARGET"
    O_JF="$TARGET/opencode.json"
    if [[ ! -f "$O_JF" ]]; then
      echo '{}' > "$O_JF"
      log "Created base $O_JF for template merge"
    fi
    merge_json_file "$CONFIG_TEMPLATE" "$O_JF"
    echo "Applied config template to $O_JF"
  fi
fi

echo "Installation complete. Logs: $LOG"
echo "Next: restart OpenCode to load plugins. Verify: ask 'Tell me about your superpowers' and test /spartan commands."

if [[ $VERIFY_INSTALL -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would run verification script"
  elif [[ -f "$SCRIPT_DIR/verify-installation.sh" ]]; then
    bash "$SCRIPT_DIR/verify-installation.sh"
  else
    echo "Warning: verification script not found at $SCRIPT_DIR/verify-installation.sh"
  fi
fi

exit 0
