# Architecture

## Design Philosophy

This installer repo is meant to be the single canonical entry point for OpenCode toolkit setup.

Principles:

- Centralize installation behavior in one repo.
- Keep bash and PowerShell feature parity.
- Make updates reproducible with a committed lock file.
- Prefer additive changes over breaking workflow changes.
- Verify installs with explicit, repeatable checks.

## Component Overview

Core files:

- `config/toolkit-version.lock`: installer-controlled source/version metadata
- `config/opencode.template.json`: canonical OpenCode config template
- `scripts/setup-opencode-toolkits.{sh,ps1}`: main installers
- `scripts/verify-installation.{sh,ps1}`: health checks
- `scripts/update-toolkits.{sh,ps1}`: update workflow wrappers
- `scripts/enhance-claude-portable.{sh,ps1}`: CLAUDE.md enhancement helpers

## Version Management Strategy

The installer does not trust whatever state the local `ai-toolkit` checkout is in.

Instead it:

1. Reads `config/toolkit-version.lock`
2. Ensures the local checkout exists
3. Fetches upstream
4. Checks out the locked commit
5. Copies commands, skills, version metadata, and CLAUDE.md into `~/.config/opencode`

`update-toolkits` can either stay on the locked version or advance to latest and then rewrite the lock file.

## File Layout

```text
opencode-toolkit-installer/
├── config/
│   ├── toolkit-version.lock
│   └── opencode.template.json
├── docs/
│   ├── ARCHITECTURE.md
│   └── SETUP.md
├── scripts/
│   ├── setup-opencode-toolkits.sh
│   ├── setup-opencode-toolkits.ps1
│   ├── verify-installation.sh
│   ├── verify-installation.ps1
│   ├── update-toolkits.sh
│   ├── update-toolkits.ps1
│   ├── enhance-claude-portable.sh
│   └── enhance-claude-portable.ps1
└── tests/
    └── smoke-test.sh
```

## How the Installer Works

```text
Read lock file
  -> ensure ai-toolkit checkout exists
  -> fetch + checkout locked commit
  -> backup ~/.config/opencode
  -> sync Spartan assets
  -> merge Superpowers plugin
  -> optionally merge config template
  -> optionally run verification
```

## Bash vs PowerShell

Both platforms support:

- version-locked install
- config template merge
- post-install verification
- interactive update workflow

Main differences:

- Bash uses `jq` for JSON parsing and merging
- PowerShell uses `ConvertFrom-Json` and native object mutation
- Bash auto-installs `jq` when possible

## Testing Strategy

Primary checks:

- installer dry-run for both shells
- verification scripts against the current machine
- smoke-test coverage for expected repo files and dry-run commands

The verification scripts check directory structure, commands, skills, CLAUDE.md enhancements, plugin presence, locked version, and local `ai-toolkit` git state.

## Extension Points

- Update `config/opencode.template.json` to evolve default OpenCode config
- Update `config/toolkit-version.lock` to pin a new `ai-toolkit` release
- Extend verification scripts with more checks if the toolkit layout changes
- Keep new installer flags mirrored across bash and PowerShell
