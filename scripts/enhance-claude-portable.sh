#!/usr/bin/env bash
# Portable CLAUDE.md enhancer (safer: work on a copy and update only when needed)
set -euo pipefail

CLAUDE="$HOME/.config/opencode/CLAUDE.md"
if [[ ! -f "$CLAUDE" ]]; then
  echo "ERROR: $CLAUDE not found"
  exit 1
fi

# Create a safe backup of the current file before making any changes
BACKUP="$HOME/.config/opencode/CLAUDE.md.backup-enhance-$(date +%Y%m%d-%H%M%S)"
cp -a "$CLAUDE" "$BACKUP"
echo "Backup created: $BACKUP"

# Work on a copy and only replace the original if changes are necessary
WORK=$(mktemp)
cp -p "$CLAUDE" "$WORK"

CALLFILE=$(mktemp)
QFILE=$(mktemp)

cat > "$CALLFILE" <<'EOF'
---

> **⚠️ DECISION CHECKPOINT — Use Question Tool Proactively**  
> Before making ANY assumption about intent, approach, or preference:  
> 1. Can this be done 2+ ways? → Use question tool  
> 2. Is the requirement vague? → Use question tool   
> 3. Would different users want different things? → Use question tool  

---

EOF

cat > "$QFILE" <<'EOF'
### Question Tool Usage (Agent Behavior)

**ALWAYS use the `question` tool when:**
- Multiple valid technical approaches exist
- User preference is needed (naming, structure, tech choices)
- Domain rules are ambiguous or missing
- Tradeoffs exist between options
- You're about to make an assumption that could be wrong
- Clarifying vague requirements before starting work

**Tool format guidelines:**
- Use the `question` tool (structured UI) instead of text-based questions
- Provide 2-4 clear options with descriptions explaining tradeoffs
- Mark one option as "(Recommended)" if you have a technical opinion
- Use `header` field for context (keep under 30 chars)
- Use `description` to explain each option's implications

---

EOF

# Ensure temporary files are removed on exit
cleanup(){ rm -f "$WORK" "$CALLFILE" "$QFILE"; }
trap cleanup EXIT

# 1) Insert decision callout if not already present
if ! grep -q "DECISION CHECKPOINT" "$WORK"; then
  awk -v callfile="$CALLFILE" 'BEGIN{ inserted=0 } /### 2\. Spec Before Code/ && inserted==0 { system("cat \""callfile"\"" ); inserted=1 } { print }' "$WORK" > "$WORK.tmp" && mv "$WORK.tmp" "$WORK"
  echo "Inserted decision callout"
else
  echo "Decision callout already present; skipping insertion"
fi

# 2) Replace existing Question Tool section if present; otherwise append it
if grep -q "### Question Tool Usage (Agent Behavior)" "$WORK"; then
  awk -v newfile="$QFILE" 'BEGIN{ inblock=0; found=0 } /### Question Tool Usage \(Agent Behavior\)/{ inblock=1; found=1; system("cat \""newfile"\"" ); next } inblock==1 && /^---$/{ inblock=0; next } inblock==0{ print } END{ if(found==0){ print "\n"; system("cat \""newfile"\"" ) } }' "$WORK" > "$WORK.tmp" && mv "$WORK.tmp" "$WORK"
  echo "Replaced existing Question Tool section"
else
  cat "$QFILE" >> "$WORK"
  echo "Appended Question Tool section"
fi

# 3) If changes were made, replace the original atomically; otherwise leave it untouched
if ! cmp -s "$BACKUP" "$WORK"; then
  mv "$WORK" "$CLAUDE"
  echo "Enhanced $CLAUDE (backup at $BACKUP)"
else
  echo "No changes required; original CLAUDE.md left untouched (backup at $BACKUP)"
fi

exit 0
