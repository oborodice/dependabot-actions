# shellcheck shell=bash
# Puts the fake gh first in PATH; it records its calls to GH_LOG
PATH="$BATS_TEST_DIRNAME/bin:$PATH"
export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
