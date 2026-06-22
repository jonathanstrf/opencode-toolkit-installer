#!/usr/bin/env bash
set -euo pipefail

# create-semver-release.sh
# Helper to create a semantic version tag (v<major>.<minor>.<patch>) and push it.
# Usage:
#   ./create-semver-release.sh            # bump patch from latest tag and push
#   ./create-semver-release.sh patch      # bump patch
#   ./create-semver-release.sh minor      # bump minor
#   ./create-semver-release.sh major      # bump major
#   ./create-semver-release.sh v1.2.3     # create explicit tag v1.2.3
#   ./create-semver-release.sh --dry-run  # show actions but don't push

DRY_RUN=0
BUMP="patch"
MSG="Automated release"

usage(){
  cat <<EOF
Usage: $0 [patch|minor|major|vX.Y.Z] [--dry-run] [--message "msg"]
Examples:
  $0            # bump patch from latest v* tag and push
  $0 minor      # bump minor
  $0 v1.2.3     # create tag v1.2.3
  $0 --dry-run  # don't push
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift;;
    --message) MSG="$2"; shift 2;;
    patch|minor|major) BUMP="$1"; shift;;
    -h|--help) usage; exit 0;;
    v[0-9]*.[0-9]*.[0-9]*) VERSION="$1"; shift;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo"; exit 1; }

if [[ -z "${VERSION:-}" ]]; then
  # find latest tag starting with v, sorted by version
  LATEST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -n1 || true)
  if [[ -z "$LATEST_TAG" ]]; then
    # no tags yet, start at v0.0.0
    MAJOR=0; MINOR=0; PATCH=0
  else
    if [[ ! "$LATEST_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      echo "Latest tag ($LATEST_TAG) is not semantic vMAJ.MIN.PAT"; exit 1
    fi
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    PATCH=${BASH_REMATCH[3]}
  fi

  case "$BUMP" in
    patch)
      PATCH=$((PATCH + 1))
      ;;
    minor)
      MINOR=$((MINOR + 1)); PATCH=0
      ;;
    major)
      MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
      ;;
    *) echo "Unknown bump: $BUMP"; exit 2;;
  esac

  VERSION="v${MAJOR}.${MINOR}.${PATCH}"
fi

if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be semver like v1.2.3"; exit 1
fi

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "Tag $VERSION already exists"; exit 1
fi

echo "Creating tag: $VERSION"
echo "Message: $MSG"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN: would run: git tag -a $VERSION -m \"$MSG\" && git push origin $VERSION"
  exit 0
fi

# create annotated tag and push
git tag -a "$VERSION" -m "$MSG"
git push origin "$VERSION"

echo "Pushed tag $VERSION to origin. The release workflow will run on GitHub." 

exit 0
