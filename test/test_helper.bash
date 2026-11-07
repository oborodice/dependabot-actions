# shellcheck shell=bash
# Puts the fake gh and sleep first in PATH; they record their calls to GH_LOG and SLEEP_LOG
PATH="$BATS_TEST_DIRNAME/bin:$PATH"
export GH_LOG="$BATS_TEST_TMPDIR/gh.log" SLEEP_LOG="$BATS_TEST_TMPDIR/sleep.log"
