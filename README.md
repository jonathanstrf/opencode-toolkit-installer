# OpenCode Toolkit Installer

Unified installer for Spartan AI Toolkit + Superpowers on OpenCode.

Platform support

| Script | macOS / Linux | Windows (native PowerShell) | Windows (Git Bash / WSL) |
|---|---:|---:|---:|
| scripts/setup-opencode-toolkits.sh | Yes | No | Yes |
| scripts/setup-opencode-toolkits.ps1 | Yes* | Yes | Yes |
| scripts/enhance-claude-portable.sh | Yes | No | Yes |
| scripts/enhance-claude-portable.ps1 | Yes* | Yes | No |

*PowerShell runs on macOS/Linux too, but the bash scripts are the canonical path on those platforms.

Quick start

Clone the installer repo:

```
git clone git@github.com:jonathanstrf/opencode-toolkit-installer.git ~/Code/opencode-toolkit-installer
cd ~/Code/opencode-toolkit-installer/scripts
```

macOS / Linux (recommended)

1. Preview (dry run):
   ```bash
   bash setup-opencode-toolkits.sh --dry-run
   ```

2. Real install:
   ```bash
   bash setup-opencode-toolkits.sh
   ```

Windows (PowerShell)

1. Preview (dry run):
   ```powershell
   Set-Location "$env:USERPROFILE\Code\opencode-toolkit-installer\scripts"
   .\setup-opencode-toolkits.ps1 -SpartanRepo "$env:USERPROFILE\Code\ai-toolkit" -DryRun
   ```

2. Real install:
   ```powershell
   .\setup-opencode-toolkits.ps1 -SpartanRepo "$env:USERPROFILE\Code\ai-toolkit"
   ```

Flags (both scripts)

--spartan-repo / -SpartanRepo PATH   Path to ai-toolkit repo (default: ~/Code/ai-toolkit)
--skip-spartan / -SkipSpartan        Install Superpowers only
--skip-superpowers / -SkipSuperpowers  Install Spartan only
--no-enhance / -NoEnhance            Skip CLAUDE.md enhancement
--dry-run / -DryRun                  Preview actions without writing files

Verification

After install, verify the key artifacts:

- Commands count (expected ~71):
  - macOS/Linux: `find ~/.config/opencode/commands -type f | wc -l`
  - Windows PowerShell: `(Get-ChildItem -Path "$env:USERPROFILE\.config\opencode\commands" -Recurse -File).Count`
- Skills count (expected ~38):
  - macOS/Linux: `find ~/.config/opencode/skills -mindepth 1 -maxdepth 2 -type d | wc -l`
  - Windows PowerShell: `(Get-ChildItem -Path "$env:USERPROFILE\.config\opencode\skills" -Directory -Depth 2).Count`
- CLAUDE.md enhancement: `~/.config/opencode/CLAUDE.md` should contain the "DECISION CHECKPOINT" callout and a "Question Tool Usage" section.
- Superpowers plugin: `~/.config/opencode/opencode.json` should include `"superpowers@git+https://github.com/obra/superpowers.git"` in the plugin array.

Restart OpenCode to load plugins and test:

- Ask: "Tell me about your superpowers"
- Use a Spartan command: `/spartan` or `/spartan:build`

Troubleshooting

See TROUBLESHOOTING.md for common issues, including running .sh files on Windows and enhancer failures.
