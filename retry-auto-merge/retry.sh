#!/usr/bin/env bash
set -eo pipefail

# Expects: GH_TOKEN, REPO, EVENT_NAME, CONCLUSION, RUN_ID, RUN_ATTEMPT, HEAD_BRANCH,
#          RETRY_STEPS, MAX_RETRIES, MIN_DELAY, MAX_DELAY

require_integer() {
  if [[ ! "$2" =~ ^(0|[1-9][0-9]*)$ ]]; then
    echo "::error::$1 must be a non-negative integer: '$2'"
    exit 1
  fi
}
require_integer max-retries "$MAX_RETRIES"
require_integer min-delay "$MIN_DELAY"
require_integer max-delay "$MAX_DELAY"
if ((MIN_DELAY > MAX_DELAY)); then
  echo "::error::min-delay ($MIN_DELAY) must not be greater than max-delay ($MAX_DELAY)"
  exit 1
fi

trim() {
  local s="${1#"${1%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}
allowed_steps=()
IFS=',' read -ra items <<< "$RETRY_STEPS"
for item in "${items[@]}"; do
  item=$(trim "$item")
  if [[ -n "$item" ]]; then
    allowed_steps+=("$item")
  fi
done
if [[ ${#allowed_steps[@]} -eq 0 ]]; then
  echo "::error::retry-steps must not be empty"
  exit 1
fi

if [[ "$EVENT_NAME" != "workflow_run" ]]; then
  echo "::error::This action must be triggered by workflow_run, got '$EVENT_NAME'"
  exit 1
fi
if [[ "$CONCLUSION" != "failure" ]]; then
  echo "Skipping retry: workflow run concluded with '$CONCLUSION'."
  exit 0
fi
if ((RUN_ATTEMPT > MAX_RETRIES)); then
  echo "Skipping retry: attempt $RUN_ATTEMPT has reached max-retries ($MAX_RETRIES)."
  exit 0
fi

# Failures of other steps, such as a broken build, fail the same way on every attempt
failed_steps=$(gh api "repos/$REPO/actions/runs/$RUN_ID/attempts/$RUN_ATTEMPT/jobs" \
  --jq '.jobs[].steps[]? | select(.conclusion == "failure") | .name')
retryable=false
while IFS= read -r step; do
  for allowed_step in "${allowed_steps[@]}"; do
    if [[ "$step" == "$allowed_step" ]]; then
      retryable=true
    fi
  done
done <<< "$failed_steps"
if [[ "$retryable" != true ]]; then
  echo "Skipping retry: failed steps '${failed_steps//$'\n'/, }' are not in retry-steps '$RETRY_STEPS'."
  exit 0
fi

delay=$((RANDOM % (MAX_DELAY - MIN_DELAY + 1) + MIN_DELAY))
echo "Waiting ${delay} seconds before retry..."
sleep "$delay"

# The branch is deleted once the PR is merged or closed during the wait, and a re-run would fail at checkout
open_pulls=$(gh api -X GET "repos/$REPO/pulls" -f head="${REPO%%/*}:$HEAD_BRANCH" -f state=open --jq length)
if ((open_pulls == 0)); then
  echo "Skipping retry: no open PR for branch '$HEAD_BRANCH'."
  exit 0
fi

gh api -X POST "repos/$REPO/actions/runs/$RUN_ID/rerun" --silent
echo "Re-ran workflow run $RUN_ID after failed attempt $RUN_ATTEMPT."
