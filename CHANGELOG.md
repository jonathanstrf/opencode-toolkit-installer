# Changelog

## v2.0.0 (2026-06-22)

Major release: centralized toolkit management system.

### New Features
- Version pinning with `config/toolkit-version.lock`
- Auto-checkout of the locked `ai-toolkit` commit during installation
- jq auto-installation for bash installer flows
- Config template management with `--apply-config` and `-ApplyConfig`
- Comprehensive verification scripts with 8 automated checks
- Interactive update workflow with `update-toolkits.sh` and `update-toolkits.ps1`
- Full bash and PowerShell parity for install, verify, and update flows

### New Files
- `config/toolkit-version.lock`
- `config/opencode.template.json`
- `docs/SETUP.md`
- `docs/ARCHITECTURE.md`
- `scripts/verify-installation.sh`
- `scripts/verify-installation.ps1`
- `scripts/update-toolkits.sh`
- `scripts/update-toolkits.ps1`

### Enhancements
- `scripts/setup-opencode-toolkits.sh`: version lock enforcement, jq auto-install, config template merge, verify hook
- `scripts/setup-opencode-toolkits.ps1`: version lock enforcement, config template merge, verify hook
- `tests/smoke-test.sh`: v2 dry-run coverage for both installer families
- `TROUBLESHOOTING.md`: added jq, version lock, config template, and verification guidance

### Breaking Changes
- None

### Dependencies
- Bash scripts require `git`, `jq`, and `rsync`
- PowerShell scripts require `git`

### Migration Guide
No migration is required. Existing installs continue to work.

To adopt the new workflow:

1. Pull this repo
2. Run the installer in dry-run mode
3. Re-run with `--apply-config` / `-ApplyConfig` if you want the canonical config template merged
4. Use the update and verification scripts for ongoing maintenance

## v1.0.0 (2026-06-22)

Initial release.

Features
- Unified installer for Spartan + Superpowers
- Auto-clone ai-toolkit if missing
- Safe JSON merge for opencode.json
- CLAUDE.md enhancement (decision callout + question tool)
- Dry-run mode
- Verification script
- Bash + PowerShell support
