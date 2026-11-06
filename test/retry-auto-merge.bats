setup() {
  load test_helper
  export REPO=o/r EVENT_NAME=workflow_run CONCLUSION=failure RUN_ID=42 RUN_ATTEMPT=1
  export HEAD_BRANCH=dependabot/npm_and_yarn/foo-1.2.3
  export MAX_RETRIES=3 MIN_DELAY=0 MAX_DELAY=0
}

retry() {
  run bash "$BATS_TEST_DIRNAME/../retry-auto-merge/retry.sh"
}

@test "re-runs a failed run while its PR is open" {
  retry
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$GH_LOG")" = "api -X GET repos/o/r/pulls -f head=o:$HEAD_BRANCH -f state=open --jq length" ]
  [ "$(sed -n 2p "$GH_LOG")" = "api -X POST repos/o/r/actions/runs/42/rerun --silent" ]
  [[ "$output" == *"Re-ran workflow run 42 after failed attempt 1."* ]]
}

@test "re-runs up to max-retries" {
  RUN_ATTEMPT=3 retry
  [ "$status" -eq 0 ]
  [[ "$(cat "$GH_LOG")" == *"/rerun"* ]]
}

@test "skips once max-retries is reached" {
  RUN_ATTEMPT=4 retry
  [ "$status" -eq 0 ]
  [ "$output" = "Skipping retry: attempt 4 has reached max-retries (3)." ]
  [ ! -e "$GH_LOG" ]
}

@test "never re-runs when max-retries is 0" {
  MAX_RETRIES=0 retry
  [ "$status" -eq 0 ]
  [ ! -e "$GH_LOG" ]
}

@test "skips runs that did not fail" {
  for conclusion in success cancelled; do
    echo "conclusion: $conclusion"
    CONCLUSION=$conclusion retry
    [ "$status" -eq 0 ]
    [ "$output" = "Skipping retry: workflow run concluded with '$conclusion'." ]
  done
  [ ! -e "$GH_LOG" ]
}

@test "skips when the PR is no longer open" {
  FAKE_OPEN_PULLS=0 retry
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping retry: no open PR for branch '$HEAD_BRANCH'."* ]]
  [[ "$(cat "$GH_LOG")" != *"/rerun"* ]]
}

@test "fails outside workflow_run events" {
  EVENT_NAME=push retry
  [ "$status" -eq 1 ]
  [ "$output" = "::error::This action must be triggered by workflow_run, got 'push'" ]
}

@test "fails when checking the PR fails" {
  FAKE_GH_FAIL="/pulls" retry
  [ "$status" -eq 1 ]
  [[ "$(cat "$GH_LOG")" != *"/rerun"* ]]
}

@test "fails when the re-run fails" {
  FAKE_GH_FAIL="/rerun" retry
  [ "$status" -eq 1 ]
}

@test "fails on non-integer inputs" {
  for value in abc -1 08 ""; do
    echo "max-retries: '$value'"
    MAX_RETRIES=$value retry
    [ "$status" -eq 1 ]
    [ "$output" = "::error::max-retries must be a non-negative integer: '$value'" ]
  done
  MIN_DELAY=abc retry
  [ "$status" -eq 1 ]
  [ "$output" = "::error::min-delay must be a non-negative integer: 'abc'" ]
  MAX_DELAY=abc retry
  [ "$status" -eq 1 ]
  [ "$output" = "::error::max-delay must be a non-negative integer: 'abc'" ]
}

@test "fails when min-delay is greater than max-delay" {
  MIN_DELAY=5 MAX_DELAY=1 retry
  [ "$status" -eq 1 ]
  [ "$output" = "::error::min-delay (5) must not be greater than max-delay (1)" ]
}
