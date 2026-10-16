#!/usr/bin/env bash
# next-version.sh's next_version: bash actions/client-version/next-version.test.sh
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=next-version.sh
source "$(dirname "$0")/next-version.sh"

failures=0
fail() { echo "FAIL $case: $*"; failures=$((failures + 1)); }

# check <case> <pin> <last> <releasable> <exit status> <stdout> <stderr pattern>
check() {
  case=$1
  local want_status=$5 want_out=$6 want_err=$7 out err status before=$failures
  err=$(mktemp)
  out=$(next_version "$2" "$3" "$4" 2>"$err")
  status=$?
  [ "$status" = "$want_status" ] || fail "exit $status, want $want_status"
  [ "$out" = "$want_out" ] || fail "printed '$out', want '$want_out'"
  [ -z "$want_err" ] || grep -q -- "$want_err" "$err" || fail "stderr '$(cat "$err")' lacks '$want_err'"
  rm -f "$err"
  [ "$failures" -gt "$before" ] || echo "ok   $case"
}

check "a client's first release starts the pin's minor" v0.5.0 "" true 0 0.5.0 ""
check "a first release takes the pin's minor whatever its patch" v0.5.3 "" true 0 0.5.0 ""
check "a pin on a newer minor starts it at .0" v0.6.0 v0.5.2 true 0 0.6.0 ""
check "a client behind by several minors catches up with the pin" v0.5.0 v0.2.0 true 0 0.5.0 ""
check "a pin on a newer major starts it at .0" v1.0.0 v0.9.4 true 0 1.0.0 ""
check "a cjls patch on the same minor is the client's next patch" v0.5.1 v0.5.0 true 0 0.5.1 ""
check "the client's own change on the same pin is its next patch" v0.5.0 v0.5.0 true 0 0.5.1 ""
check "the client's patch is its own, not cjls's" v0.5.1 v0.5.4 true 0 0.5.5 ""
check "nothing to release prints nothing" v0.6.0 v0.5.0 false 0 "" ""
check "a pin older than the last release fails" v0.4.0 v0.5.0 true 1 "" "older than the last release v0.5.0"
check "a pin on an older major fails" v0.9.0 v1.0.0 true 1 "" "older than the last release"
check "a pin that is no release fails" nightly-build v0.5.0 true 1 "" "is no cjls release"
check "an empty pin fails" "" v0.5.0 true 1 "" "is no cjls release"
check "a last release that is no version fails" v0.5.0 v0.5 true 1 "" "is no vMAJOR.MINOR.PATCH"

[ "$failures" = 0 ] || { echo "$failures failed"; exit 1; }
