#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$REPO_ROOT/config/toolkit-version.lock"

TARGET="$HOME/.config/opencode"
COMMANDS_DIR="$TARGET/commands"
SKILLS_DIR="$TARGET/skills"
CLAUDE_FILE="$TARGET/CLAUDE.md"
OPENCODE_JSON="$TARGET/opencode.json"
VERSION_FILE="$TARGET/.spartan-version"
SPARTAN_REPO_FILE="$TARGET/.spartan-repo"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for verification"
  exit 1
fi

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "ERROR: Lock file not found: $LOCK_FILE"
  exit 1
fi

EXPECTED_COMMAND_COUNT="$(jq -r '.checksums.expected_command_count' "$LOCK_FILE")"
EXPECTED_SKILL_COUNT="$(jq -r '.checksums.expected_skill_count' "$LOCK_FILE")"
EXPECTED_SPARTAN_VERSION="$(jq -r '."ai-toolkit".version' "$LOCK_FILE")"

print_pass() {
  echo -e "${GREEN}✓ $1${NC}"
  PASS=$((PASS + 1))
}

print_fail() {
  echo -e "${RED}✗ $1${NC}"
  FAIL=$((FAIL + 1))
}

print_warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
  WARN=$((WARN + 1))
}

echo "=========================================="
echo "OpenCode Toolkit Verification Report"
echo "=========================================="
echo

if [[ -d "$TARGET" ]]; then
  print_pass "Directory structure exists"
else
  print_fail "Directory $TARGET missing"
fi

CMD_COUNT=0
if [[ -d "$COMMANDS_DIR" ]]; then
  CMD_COUNT="$(find "$COMMANDS_DIR" -type f | wc -l | tr -d ' ')"
fi
if [[ "$CMD_COUNT" == "$EXPECTED_COMMAND_COUNT" ]]; then
  print_pass "Commands: $CMD_COUNT found (expected $EXPECTED_COMMAND_COUNT)"
elif [[ "$CMD_COUNT" -gt 0 ]]; then
  print_warn "Commands: $CMD_COUNT found (expected $EXPECTED_COMMAND_COUNT) - WARNING"
else
  print_fail "Commands directory missing or empty"
fi

SKILL_COUNT=0
if [[ -d "$SKILLS_DIR" ]]; then
  SKILL_COUNT="$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
fi
if [[ "$SKILL_COUNT" == "$EXPECTED_SKILL_COUNT" ]]; then
  print_pass "Skills: $SKILL_COUNT found (expected $EXPECTED_SKILL_COUNT)"
elif [[ "$SKILL_COUNT" -gt 0 ]]; then
  print_warn "Skills: $SKILL_COUNT found (expected $EXPECTED_SKILL_COUNT) - WARNING"
else
  print_fail "Skills directory missing or empty"
fi

if [[ -f "$CLAUDE_FILE" ]] && grep -q "DECISION CHECKPOINT" "$CLAUDE_FILE"; then
  print_pass "CLAUDE.md: Decision checkpoint present"
else
  print_fail "CLAUDE.md: Decision checkpoint missing"
fi

if [[ -f "$CLAUDE_FILE" ]] && grep -q "Question Tool Usage" "$CLAUDE_FILE"; then
  print_pass "CLAUDE.md: Question tool section present"
else
  print_fail "CLAUDE.md: Question tool section missing"
fi

if [[ -f "$OPENCODE_JSON" ]] && grep -q "superpowers@git+https://github.com/obra/superpowers.git" "$OPENCODE_JSON"; then
  print_pass "Superpowers plugin installed"
else
  print_fail "Superpowers plugin missing"
fi

INSTALLED_VERSION=""
if [[ -f "$VERSION_FILE" ]]; then
  INSTALLED_VERSION="$(tr -d '\r\n' < "$VERSION_FILE")"
fi
if [[ "$INSTALLED_VERSION" == "$EXPECTED_SPARTAN_VERSION" ]]; then
  print_pass "Version lock: $INSTALLED_VERSION matches $EXPECTED_SPARTAN_VERSION"
else
  print_fail "Version lock: ${INSTALLED_VERSION:-missing} does not match $EXPECTED_SPARTAN_VERSION"
fi

if [[ -f "$SPARTAN_REPO_FILE" ]]; then
  AI_TOOLKIT_REPO="$(tr -d '\r\n' < "$SPARTAN_REPO_FILE")"
else
  AI_TOOLKIT_REPO="$HOME/Code/ai-toolkit"
fi

if [[ -d "$AI_TOOLKIT_REPO/.git" ]]; then
  if [[ -n "$(git -C "$AI_TOOLKIT_REPO" status --porcelain 2>/dev/null)" ]]; then
    print_warn "ai-toolkit repo: Has uncommitted changes - WARNING"
  else
    print_pass "ai-toolkit repo: Working tree clean"
  fi
else
  print_warn "ai-toolkit repo: Git repository not found at $AI_TOOLKIT_REPO - WARNING"
fi

echo
echo "=========================================="
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"

if [[ $FAIL -gt 0 ]]; then
  echo "Status: FAILED"
  exit 1
fi

if [[ $WARN -gt 0 ]]; then
  echo "Status: PASSED (with warnings)"
else
  echo "Status: PASSED"
fi

exit 0
