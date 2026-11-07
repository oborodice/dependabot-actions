#!/usr/bin/env bash
set -eo pipefail

# Expects: PR_NUMBER, PR_AUTHOR, GITHUB_OUTPUT

if [[ -z "$PR_NUMBER" ]]; then
  echo "::error::This action must be triggered by a pull request event"
  exit 1
fi

if [[ "$PR_AUTHOR" == "dependabot[bot]" ]]; then
  echo "dependabot=true" >> "$GITHUB_OUTPUT"
else
  echo "Skipping: PR author '$PR_AUTHOR' is not dependabot[bot]."
  echo "dependabot=false" >> "$GITHUB_OUTPUT"
fi
