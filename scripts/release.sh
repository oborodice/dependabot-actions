#!/usr/bin/env bash
set -eo pipefail

# Usage: scripts/release.sh 1.2.3 (a leading v is also accepted)
# Tags the current main as v1.2.3, moves the major tag (v1) to it and creates a GitHub release.

version="v${1#v}"
if [[ ! "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Usage: $0 X.Y.Z" >&2
  exit 1
fi
major="v${BASH_REMATCH[1]}"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean." >&2
  exit 1
fi
if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Not on main." >&2
  exit 1
fi
# --force updates the major tag when it was moved from another clone
git fetch --quiet --tags --force origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "main is not in sync with origin/main." >&2
  exit 1
fi

if git rev-parse --quiet --verify "refs/tags/$version" > /dev/null; then
  echo "$version already exists." >&2
  exit 1
fi
# Moving the major tag back to an older commit would downgrade every user of it
latest=$(git tag --list "$major.*" | sort -V | tail -1)
if [[ -n "$latest" && "$(printf '%s\n' "$latest" "$version" | sort -V | tail -1)" != "$version" ]]; then
  echo "$version is older than the latest release $latest." >&2
  exit 1
fi

echo "Release $version at $(git log -1 --format='%h %s') and move $major to it."
read -r -p "Continue? [y/N] " answer || true
if [[ "$answer" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

git tag -a "$version" -m "$version"
git tag -f "$major" "$version^{commit}"
# Only the major tag is force-pushed, and both tags are pushed or neither is
git push --atomic origin "refs/tags/$version" "+refs/tags/$major"
gh release create "$version" --verify-tag --generate-notes
