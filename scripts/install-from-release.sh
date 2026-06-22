#!/usr/bin/env bash
set -euo pipefail

OWNER="jonathanstrf"
REPO="opencode-toolkit-installer"
TAG="${1:-latest}"
OUTDIR="$HOME/Downloads/$REPO-$TAG"

command -v curl >/dev/null 2>&1 || { echo "curl required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "unzip required"; exit 1; }
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum/shasum required"; exit 1; }

if [[ "$TAG" == "latest" ]]; then
  API_URL="https://api.github.com/repos/$OWNER/$REPO/releases/latest"
else
  API_URL="https://api.github.com/repos/$OWNER/$REPO/releases/tags/$TAG"
fi

echo "Querying release info: $API_URL"
JSON=$(curl -sS "$API_URL")

ZIP_URL=$(echo "$JSON" | jq -r '.assets[] | select(.name | test("opencode-toolkit-installer-.*\\.zip$")) | .browser_download_url')
SHA_URL=$(echo "$JSON" | jq -r '.assets[] | select(.name | test(".*\\.zip\.sha256$")) | .browser_download_url')

if [[ -z "$ZIP_URL" || -z "$SHA_URL" ]]; then
  echo "Release assets not found (zip or sha256)." >&2
  exit 2
fi

mkdir -p "$OUTDIR"
ZIP_LOCAL="$OUTDIR/$(basename "$ZIP_URL")"
SHA_LOCAL="$OUTDIR/$(basename "$SHA_URL")"

echo "Downloading $ZIP_URL"
curl -sSL -o "$ZIP_LOCAL" "$ZIP_URL"
echo "Downloading $SHA_URL"
curl -sSL -o "$SHA_LOCAL" "$SHA_URL"

echo "Verifying checksum"
REMOTE_SUM=$(awk '{print $1}' "$SHA_LOCAL")
if command -v shasum >/dev/null 2>&1; then
  LOCAL_SUM=$(shasum -a 256 "$ZIP_LOCAL" | awk '{print $1}')
else
  LOCAL_SUM=$(sha256sum "$ZIP_LOCAL" | awk '{print $1}')
fi

if [[ "$LOCAL_SUM" != "$REMOTE_SUM" ]]; then
  echo "Checksum mismatch!" >&2
  echo "Local:  $LOCAL_SUM" >&2
  echo "Remote: $REMOTE_SUM" >&2
  exit 3
fi

echo "Checksum OK. Extracting to $OUTDIR"
unzip -q -o "$ZIP_LOCAL" -d "$OUTDIR"

echo "Done. Installer extracted to: $OUTDIR"
echo "To run (macOS/Linux):"
echo "  cd $OUTDIR && bash scripts/setup-opencode-toolkits.sh --dry-run" 
echo "Then run without --dry-run to perform installation."

exit 0
