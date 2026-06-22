#!/usr/bin/env bash
set -euo pipefail

echo "Running smoke test (dry-run)"
bash scripts/setup-opencode-toolkits.sh --dry-run
echo "Smoke test completed successfully"
