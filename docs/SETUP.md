# Setup Guide

## Overview

This repo centralizes OpenCode toolkit installation across machines. It pins the `ai-toolkit` source version, installs or refreshes Spartan and Superpowers, optionally merges a canonical `opencode.json` template, and provides verification/update scripts for both bash and PowerShell.

## Quick Start (New Machine)

Clone the repo:

```bash
git clone git@github.com:jonathanstrf/opencode-toolkit-installer.git ~/Code/opencode-toolkit-installer
cd ~/Code/opencode-toolkit-installer
```

macOS / Linux:

```bash
cd scripts
bash setup-opencode-toolkits.sh --dry-run --apply-config --verify
bash setup-opencode-toolkits.sh --apply-config --verify
```

Windows PowerShell:

```powershell
Set-Location "$env:USERPROFILE\Code\opencode-toolkit-installer\scripts"
.\setup-opencode-toolkits.ps1 -DryRun -ApplyConfig -Verify
.\setup-opencode-toolkits.ps1 -ApplyConfig -Verify
```

## Updating Existing Installation

Stay on the locked toolkit version:

```bash
bash scripts/update-toolkits.sh --locked
```

```powershell
.\scripts\update-toolkits.ps1 -Locked
```

Update to latest upstream and refresh the lock file:

```bash
bash scripts/update-toolkits.sh --latest
```

```powershell
.\scripts\update-toolkits.ps1 -Latest
```

Run verification only:

```bash
bash scripts/update-toolkits.sh --verify-only
```

```powershell
.\scripts\update-toolkits.ps1 -VerifyOnly
```

## Config Template Customization

The canonical OpenCode config lives at `config/opencode.template.json`.

Use `--apply-config` or `-ApplyConfig` to merge it into `~/.config/opencode/opencode.json`.

Merge rules:

- Existing user model and provider settings are preserved.
- Missing plugins from the template are added.
- Missing agent definitions from the template are added.
- If no `opencode.json` exists yet, the template is copied directly.

## Version Lock Management

`config/toolkit-version.lock` is the source of truth for installer behavior.

It records:

- Installer version
- `ai-toolkit` repo URL
- Locked `ai-toolkit` version and commit
- Expected command and skill counts
- Runtime dependency notes

Installers auto-checkout the locked `ai-toolkit` commit before syncing files.

## Platform-Specific Notes

- Bash scripts require `git`, `rsync`, and `jq`.
- If `jq` is missing, the bash installer attempts to install it automatically.
- PowerShell scripts require `git` and use native JSON handling.
- On Windows, prefer the `.ps1` path unless you explicitly want Git Bash or WSL.

## Common Workflows

Fresh install with config merge and verification:

```bash
bash scripts/setup-opencode-toolkits.sh --apply-config --verify
```

Repair an existing machine without changing the locked version:

```powershell
.\scripts\update-toolkits.ps1 -Locked
```

Check current machine health:

```bash
bash scripts/verify-installation.sh
```

## Troubleshooting

See `TROUBLESHOOTING.md` for jq install problems, version lock issues, template merge conflicts, and verification failures.
