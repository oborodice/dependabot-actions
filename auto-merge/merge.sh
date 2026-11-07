#!/usr/bin/env bash
set -eo pipefail

# Expects: GH_TOKEN, PR_URL, UPDATE_TYPE, UPDATE_TYPES, MERGE_METHOD

case "$MERGE_METHOD" in
  merge | squash | rebase) ;;
  *)
    echo "::error::Invalid merge-method: $MERGE_METHOD"
    exit 1
    ;;
esac

IFS=',' read -ra allowed <<< "${UPDATE_TYPES// /}"
if [[ ${#allowed[@]} -eq 0 ]]; then
  echo "::error::update-types must not be empty"
  exit 1
fi
for t in "${allowed[@]}"; do
  case "$t" in
    patch | minor | major) ;;
    *)
      echo "::error::Invalid update-types value: '$t'"
      exit 1
      ;;
  esac
done

# update-type looks like version-update:semver-patch
type="${UPDATE_TYPE#version-update:semver-}"
allowed_type=false
for t in "${allowed[@]}"; do
  if [[ "$t" == "$type" ]]; then
    allowed_type=true
    break
  fi
done
if [[ "$allowed_type" != true ]]; then
  echo "Skipping merge: update type '${type:-unknown}' is not in '$UPDATE_TYPES'."
  exit 0
fi

# Merging fails with "Base branch was modified" when another Dependabot PR is
# merged at the same time, so retry after a random delay to spread the runs out
max_attempts=5
for ((attempt = 1; ; attempt++)); do
  gh pr merge "--$MERGE_METHOD" "$PR_URL" && exit 0
  if ((attempt >= max_attempts)); then
    echo "::error::Failed to merge after $max_attempts attempts"
    exit 1
  fi
  delay=$((RANDOM % 21 + 10))
  echo "Merge attempt $attempt failed. Retrying in ${delay}s."
  sleep "$delay"
done
