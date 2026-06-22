#!/usr/bin/env bash
# Portable CLAUDE.md enhancer (copied from existing script)
set -euo pipefail

CLAUDE="$HOME/.config/opencode/CLAUDE.md"
if [[ ! -f "$CLAUDE" ]]; then
  echo "ERROR: $CLAUDE not found"
  exit 1
fi

BACKUP="$HOME/.config/opencode/CLAUDE.md.backup-enhance-$(date +%Y%m%d-%H%M%S)"
cp -a "$CLAUDE" "$BACKUP"
echo "Backup created: $BACKUP"

TMP1=$(mktemp)
TMP2=$(mktemp)

cat > "$TMP1" <<'EOF'
---

> **⚠️ DECISION CHECKPOINT — Use Question Tool Proactively**  
> Before making ANY assumption about intent, approach, or preference:  
> 1. Can this be done 2+ ways? → Use question tool  
> 2. Is the requirement vague? → Use question tool   
> 3. Would different users want different things? → Use question tool  

---

EOF

cat > "$TMP2" <<'EOF'
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

# Step 1: Insert callout before the '### 2. Spec Before Code' line if present
awk -v callfile="$TMP1" 'BEGIN{ inserted=0 } /### 2\. Spec Before Code/ && inserted==0 { system("cat \""callfile"\"" ); inserted=1 } { print }' "$BACKUP" > "$CLAUDE.tmp"

# Step 2: Replace existing Question Tool section if present; otherwise append the new section near the top
awk -v newfile="$TMP2" 'BEGIN{ inblock=0; found=0 } /### Question Tool Usage \(Agent Behavior\)/{ inblock=1; found=1; system("cat \""newfile"\"" ); next } inblock==1 && /^---$/{ inblock=0; next } inblock==0{ print } END{ if(found==0){ print "\n"; system("cat \""newfile"\"" ) } }' "$CLAUDE.tmp" > "$CLAUDE"

rm -f "$CLAUDE.tmp" "$TMP1" "$TMP2"

echo "Enhanced $CLAUDE (backup at $BACKUP)"

exit 0
