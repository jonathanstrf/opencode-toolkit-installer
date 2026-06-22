# TROUBLESHOOTING

1) "ERROR: rsync is required"
   - Install rsync (macOS: preinstalled; on some minimal systems install via package manager).

2) Repo not found
   - Ensure ai-toolkit is cloned to the path you passed with --spartan-repo, or allow auto-clone.

3) Commands not discovered by OpenCode
   - Verify files landed in ~/.config/opencode/commands/
   - Restart OpenCode or your terminal session.

4) CLAUDE.md not enhanced
   - Ensure enhance-claude-portable.sh is present and executable in the package.

5) Running .sh files on Windows
   - .sh files require a bash interpreter. Options:
     a) Use the native PowerShell installer instead (recommended):
        .\scripts\setup-opencode-toolkits.ps1
     b) Git Bash — open Git Bash and run:
        bash ~/Code/opencode-toolkit-installer/scripts/setup-opencode-toolkits.sh
     c) WSL — open a WSL terminal and run:
        bash ~/Code/opencode-toolkit-installer/scripts/setup-opencode-toolkits.sh

6) enhance-claude-portable.sh fails on Windows
   - Run the native PowerShell version instead:
     .\scripts\enhance-claude-portable.ps1

7) jq installation issues
   - The bash installer requires `jq` and attempts to auto-install it.
   - macOS: install manually with `brew install jq` if Homebrew is unavailable.
   - Ubuntu/Debian: install manually with `sudo apt-get update && sudo apt-get install -y jq`.
   - RHEL/Fedora family: install manually with `sudo dnf install -y jq` or `sudo yum install -y jq`.
   - Verify with: `jq --version`

8) Version lock conflicts
   - The installer now reads `config/toolkit-version.lock` and checks out the locked `ai-toolkit` commit.
   - If your local repo is on the wrong commit, re-run the installer or run:
     `git -C ~/Code/ai-toolkit fetch origin && git -C ~/Code/ai-toolkit checkout <locked-commit>`
   - If `toolkit-version.lock` is missing or corrupted, restore it from git and rerun the installer.
   - To intentionally advance to the latest upstream version, use the update scripts with `--latest` or `-Latest`.

9) Config template issues
   - The template file is `config/opencode.template.json`.
   - Use `--apply-config` or `-ApplyConfig` to merge it into `~/.config/opencode/opencode.json`.
   - Existing provider/model settings are preserved; missing plugins and agents are added.
   - If merge results look wrong, restore your backup or your previous `opencode.json`, then rerun without apply-config.

10) Verification failures
   - `scripts/verify-installation.sh` and `scripts/verify-installation.ps1` check 8 items.
   - Commands mismatch: confirm files exist in `~/.config/opencode/commands/` and rerun the installer.
   - Skills mismatch: confirm files exist in `~/.config/opencode/skills/`; a warning can also mean upstream counts changed.
   - CLAUDE.md checks failing: rerun the enhancer script or rerun the installer without `--no-enhance` / `-NoEnhance`.
   - Superpowers plugin missing: inspect `~/.config/opencode/opencode.json` for the plugin entry and rerun the installer.
   - Version mismatch: confirm `~/.config/opencode/.spartan-version` matches `config/toolkit-version.lock` -> `ai-toolkit.version`.
