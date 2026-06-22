#!/usr/bin/env bash
set -euo pipefail

echo "Running smoke test (v2 dry-run coverage)"

[[ -f config/toolkit-version.lock ]]
[[ -f config/opencode.template.json ]]
[[ -f scripts/verify-installation.sh ]]
[[ -f scripts/update-toolkits.sh ]]

if command -v jq >/dev/null 2>&1; then
  jq empty config/toolkit-version.lock
  jq empty config/opencode.template.json
else
  echo "Skipping jq JSON validation: jq not available in this shell"
fi

if command -v bash >/dev/null 2>&1 && bash -lc 'exit 0' >/dev/null 2>&1; then
  bash scripts/setup-opencode-toolkits.sh --dry-run --apply-config --verify
  bash scripts/update-toolkits.sh --help >/dev/null
else
  echo "Skipping bash execution checks: bash not available or not runnable"
fi

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File scripts/setup-opencode-toolkits.ps1 -DryRun -ApplyConfig -Verify
  pwsh -NoProfile -File scripts/update-toolkits.ps1 -VerifyOnly
else
  echo "ERROR: pwsh is required for this smoke test"
  exit 1
fi

echo "Smoke test completed successfully"
