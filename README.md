![release](https://img.shields.io/github/v/release/jonathanstrf/opencode-toolkit-installer?label=release)

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

Version Management

`config/toolkit-version.lock` is the central source of truth for this repo.

It pins:

- the installer release version
- the upstream `ai-toolkit` repo URL
- the exact `ai-toolkit` version and commit to install
- expected command and skill counts for verification

Both installers auto-checkout the locked `ai-toolkit` commit before syncing files into `~/.config/opencode`.

Use `scripts/update-toolkits.sh` or `scripts/update-toolkits.ps1` when you want to refresh an existing machine consistently.

Config Templates

`config/opencode.template.json` stores the canonical OpenCode config for this repo.

Use:

- bash: `bash setup-opencode-toolkits.sh --apply-config`
- PowerShell: `.\setup-opencode-toolkits.ps1 -ApplyConfig`

The template merge adds missing plugins and agents while preserving existing model and provider settings.

Flags (both scripts)

--spartan-repo / -SpartanRepo PATH   Path to ai-toolkit repo (default: ~/Code/ai-toolkit)
--skip-spartan / -SkipSpartan        Install Superpowers only
--skip-superpowers / -SkipSuperpowers  Install Spartan only
--no-enhance / -NoEnhance            Skip CLAUDE.md enhancement
--apply-config / -ApplyConfig        Merge config/opencode.template.json into opencode.json
--verify / -Verify                   Run verification after install
--dry-run / -DryRun                  Preview actions without writing files

Update scripts

- `--latest` / `-Latest` update the local `ai-toolkit` checkout, rewrite the lock file, reinstall, then verify.
- `--locked` / `-Locked` reinstall using the currently locked version.
- `--verify-only` / `-VerifyOnly` run health checks without reinstalling.

Verification

After install, verify the key artifacts:

- Commands count (expected ~71):
  - macOS/Linux: `find ~/.config/opencode/commands -type f | wc -l`
  - Windows PowerShell: `(Get-ChildItem -Path "$env:USERPROFILE\.config\opencode\commands" -Recurse -File).Count`
- Skills count (expected ~38):
  - macOS/Linux: `find ~/.config/opencode/skills -mindepth 1 -maxdepth 2 -type d | wc -l`
  - Windows PowerShell: `(Get-ChildItem -Path "$env:USERPROFILE\.config\opencode\skills" -Directory -Depth 2).Count`
- Version pin: `~/.config/opencode/.spartan-version` should match `config/toolkit-version.lock` -> `ai-toolkit.version`
- CLAUDE.md enhancement: `~/.config/opencode/CLAUDE.md` should contain the "DECISION CHECKPOINT" callout and a "Question Tool Usage" section.
- Superpowers plugin: `~/.config/opencode/opencode.json` should include `"superpowers@git+https://github.com/obra/superpowers.git"` in the plugin array.

Automated verification is also available:

- bash: `bash scripts/verify-installation.sh`
- PowerShell: `.\scripts\verify-installation.ps1`

The verification scripts check 8 items: directory structure, commands count, skills count, CLAUDE.md decision checkpoint, CLAUDE.md question tool section, Superpowers plugin, locked Spartan version, and local `ai-toolkit` git state.

jq requirement

The bash installer requires `jq` and will try to auto-install it when missing. The PowerShell installer uses native JSON support and has no extra JSON dependency.

Update Workflow

Use the update scripts when you want repeatable multi-machine maintenance:

```bash
bash scripts/update-toolkits.sh --locked
bash scripts/update-toolkits.sh --latest
bash scripts/update-toolkits.sh --verify-only
```

```powershell
.\scripts\update-toolkits.ps1 -Locked
.\scripts\update-toolkits.ps1 -Latest
.\scripts\update-toolkits.ps1 -VerifyOnly
```

See `docs/SETUP.md` for more detailed machine setup and maintenance workflows.

Restart OpenCode to load plugins and test:

- Ask: "Tell me about your superpowers"
- Use a Spartan command: `/spartan` or `/spartan:build`

Troubleshooting

See `TROUBLESHOOTING.md` for common issues, including running `.sh` files on Windows, jq installation failures, version lock mismatches, and enhancer failures.

Install From Release (recommended)

If you prefer a single downloadable package instead of cloning the repo, use the GitHub Release artifacts. Replace `<TAG>` with a specific tag (for example `v2.0.0`) or use `latest`.

```bash
# Example (replace TAG if needed)
TAG=${TAG:-v2.0.0}
BASE="https://github.com/jonathanstrf/opencode-toolkit-installer/releases/download/$TAG"
ZIP="opencode-toolkit-installer-$TAG.zip"
SHA="$ZIP.sha256"
DEST="$HOME/Downloads/$ZIP"

mkdir -p "$HOME/Downloads"
curl -sSL -o "$DEST" "$BASE/$ZIP"
curl -sSL -o "$HOME/Downloads/$SHA" "$BASE/$SHA"
cd "$HOME/Downloads"
# verify checksum (the .sha256 file is expected to contain: <sha256>  <filename>)
shasum -a 256 -c "$SHA"
if [[ $? -ne 0 ]]; then echo "Checksum verification failed"; exit 1; fi
unzip -q -o "$ZIP" -d "$HOME/Downloads/opencode-toolkit-installer-$TAG"
echo "Extracted to: $HOME/Downloads/opencode-toolkit-installer-$TAG"
echo "Run the installer (dry-run first):"
echo "  cd $HOME/Downloads/opencode-toolkit-installer-$TAG/scripts && bash setup-opencode-toolkits.sh --dry-run"
```

Or use the included helper (if you have cloned the repo):

```bash
./scripts/install-from-release.sh v2.0.0
```
