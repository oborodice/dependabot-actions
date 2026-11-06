setup() {
  load test_helper
  export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output"
  export PR_NUMBER=1 PR_AUTHOR="dependabot[bot]" PR_URL=https://github.com/o/r/pull/1
  export UPDATE_TYPE=version-update:semver-patch UPDATE_TYPES=patch MERGE_METHOD=merge
}

check_author() {
  run bash "$BATS_TEST_DIRNAME/../auto-merge/check-author.sh"
}

merge() {
  run bash "$BATS_TEST_DIRNAME/../auto-merge/merge.sh"
}

@test "check-author: continues for Dependabot PRs" {
  check_author
  [ "$status" -eq 0 ]
  [ "$(cat "$GITHUB_OUTPUT")" = "dependabot=true" ]
}

@test "check-author: skips PRs from other authors" {
  PR_AUTHOR=octocat check_author
  [ "$status" -eq 0 ]
  [ "$(cat "$GITHUB_OUTPUT")" = "dependabot=false" ]
}

@test "check-author: fails outside pull request events" {
  PR_NUMBER="" PR_AUTHOR="" check_author
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be triggered by a pull request event"* ]]
}

@test "merge: merges an allowed update type" {
  merge
  [ "$status" -eq 0 ]
  [ "$(cat "$GH_LOG")" = "pr merge --merge $PR_URL" ]
}

@test "merge: uses the given merge method" {
  for method in merge squash rebase; do
    echo "merge-method: $method"
    rm -f "$GH_LOG"
    MERGE_METHOD=$method merge
    [ "$status" -eq 0 ]
    [ "$(cat "$GH_LOG")" = "pr merge --$method $PR_URL" ]
  done
}

@test "merge: fails when gh fails" {
  FAKE_GH_FAIL="pr merge" merge
  [ "$status" -eq 1 ]
}

@test "merge: accepts spaces and a trailing comma in update-types" {
  UPDATE_TYPE=version-update:semver-minor UPDATE_TYPES="patch, minor," merge
  [ "$status" -eq 0 ]
  [ -s "$GH_LOG" ]
}

@test "merge: skips a disallowed update type" {
  UPDATE_TYPE=version-update:semver-major UPDATE_TYPES=patch,minor merge
  [ "$status" -eq 0 ]
  [ "$output" = "Skipping merge: update type 'major' is not in 'patch,minor'." ]
  [ ! -e "$GH_LOG" ]
}

@test "merge: skips when the update type is unknown" {
  UPDATE_TYPE="" merge
  [ "$status" -eq 0 ]
  [ "$output" = "Skipping merge: update type 'unknown' is not in 'patch'." ]
  [ ! -e "$GH_LOG" ]
}

@test "merge: fails on an invalid merge-method" {
  MERGE_METHOD=fast-forward merge
  [ "$status" -eq 1 ]
  [ "$output" = "::error::Invalid merge-method: fast-forward" ]
}

@test "merge: fails on an invalid update-types value" {
  UPDATE_TYPES=patch,minr merge
  [ "$status" -eq 1 ]
  [ "$output" = "::error::Invalid update-types value: 'minr'" ]
}

@test "merge: fails on empty update-types" {
  UPDATE_TYPES="" merge
  [ "$status" -eq 1 ]
  [ "$output" = "::error::update-types must not be empty" ]
}

@test "merge: fails on update-types with only separators" {
  UPDATE_TYPES=" , " merge
  [ "$status" -eq 1 ]
  [ "$output" = "::error::Invalid update-types value: ''" ]
}
