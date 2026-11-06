#!/usr/bin/env bash
set -eo pipefail

# Expects: PR_AUTHOR, GITHUB_OUTPUT

if [[ "$PR_AUTHOR" == "dependabot[bot]" ]]; then
  echo "dependabot=true" >> "$GITHUB_OUTPUT"
else
  echo "Skipping: PR author '$PR_AUTHOR' is not dependabot[bot]."
  echo "dependabot=false" >> "$GITHUB_OUTPUT"
fi
