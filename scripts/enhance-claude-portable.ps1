<#
PowerShell port of enhance-claude-portable.sh
Operates on ~/.config/opencode/CLAUDE.md: creates a backup, inserts decision callout
and replaces or appends the Question Tool section. Only writes the file if changes
are required.
#>
param()

Set-StrictMode -Version Latest

$claude = Join-Path $env:USERPROFILE ".config\opencode\CLAUDE.md"
if (-not (Test-Path $claude)) {
  Write-Error "ERROR: $claude not found"
  exit 1
}

$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$backup = Join-Path $env:USERPROFILE ".config\opencode\CLAUDE.md.backup-enhance-$timestamp"
Copy-Item -Path $claude -Destination $backup -Force
Write-Host "Backup created: $backup"

$orig = Get-Content -Raw -Path $claude
$work = $orig

$callout = @'
---

> **⚠️ DECISION CHECKPOINT — Use Question Tool Proactively**  
> Before making ANY assumption about intent, approach, or preference:  
> 1. Can this be done 2+ ways? → Use question tool  
> 2. Is the requirement vague? → Use question tool   
> 3. Would different users want different things? → Use question tool  

---

'@

$qsection = @'
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

'@

try {
  # Insert callout if not already present
  if ($work -notmatch 'DECISION CHECKPOINT') {
    $marker = '### 2. Spec Before Code'
    if ($work -match [regex]::Escape($marker)) {
      $work = $work -replace [regex]::Escape($marker), "$callout`n$marker"
      Write-Host "Inserted decision callout before '$marker'"
    } else {
      # Prepend at top
      $work = "$callout`n$work"
      Write-Host "Prepended decision callout at top"
    }
  } else {
    Write-Host "Decision callout already present; skipping"
  }

  # Replace or append Question Tool section
  $pattern = '### Question Tool Usage \(Agent Behavior\)'
  if ($work -match $pattern) {
    # Find start index
    $start = ([regex]::Match($work, $pattern)).Index
    # Find the next line that is exactly '---' after the start
    $tail = $work.Substring($start)
    $m = [regex]::Match($tail, "^---\s*$", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($m.Success) {
      $endIndex = $start + $m.Index + $m.Length
      $before = $work.Substring(0, $start)
      $after = $work.Substring($endIndex)
      $work = $before + $qsection + $after
      Write-Host "Replaced existing Question Tool section"
    } else {
      # couldn't find terminating '---', safest is to replace from heading to end
      $before = $work.Substring(0, $start)
      $work = $before + $qsection
      Write-Host "Replaced Question Tool section to end of file (no terminator found)"
    }
  } else {
    $work = $work + "`n" + $qsection
    Write-Host "Appended Question Tool section"
  }

  # Compare and write if changed
  if ($work -ne $orig) {
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $work -NoNewline -Force
    Move-Item -Path $tmp -Destination $claude -Force
    Write-Host "Enhanced $claude (backup at $backup)"
  } else {
    Write-Host "No changes required; original CLAUDE.md left untouched (backup at $backup)"
  }
} catch {
  Write-Error "Enhancement failed: $_"
  exit 1
}

exit 0
