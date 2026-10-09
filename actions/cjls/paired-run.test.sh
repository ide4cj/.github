#!/usr/bin/env bash
# paired-run.sh against a fake gh: bash actions/cjls/paired-run.test.sh
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=paired-run.sh
source "$(dirname "$0")/paired-run.sh"

failures=0
fail() { echo "FAIL $case: $*"; failures=$((failures + 1)); }

# the fake: HEAD (a sha, or "404", or "500"), RUNS ("<branch>@<sha or *>=<id status conclusion>" lines),
# VIEWS ("<id status conclusion>" lines, one per `gh run view`, the run after each watch); CALLS logs
gh() {
  echo "$*" >>"$CALLS"
  case "$1 $2" in
    "api repos/$REPO/branches/"*)
      case $HEAD in
        404) echo '{"message":"Branch not found"}gh: Branch not found (HTTP 404)' >&2; return 1 ;;
        500) echo 'gh: Server Error (HTTP 500)' >&2; return 1 ;;
        *) echo "$HEAD" ;;
      esac ;;
    "run list")
      local branch="" sha="*" line
      while [ $# -gt 0 ]; do
        case $1 in --branch) branch=$2 ;; --commit) sha=$2 ;; esac
        shift
      done
      while read -r line; do
        if [ "${line%%=*}" = "$branch@$sha" ]; then echo "${line#*=}"; return 0; fi
      done <<<"$RUNS" ;;
    "run watch") ;;
    "run view")
      local n
      n=$(grep -c '^run view' "$CALLS")
      sed -n "${n}p" <<<"$VIEWS" ;;
    *) echo "unexpected gh $*" >&2; return 1 ;;
  esac
}

# check <case> <exit status> <stdout> <stderr pattern> [<call pattern that must (not, with !) be made>...]
check() {
  case=$1
  local want_status=$2 want_out=$3 want_err=$4 out err status pattern before=$failures
  CALLS=$(mktemp)
  err=$(mktemp)
  out=$(paired_run feat/x 2>"$err")
  status=$?
  [ "$status" = "$want_status" ] || fail "exit $status, want $want_status"
  [ "$out" = "$want_out" ] || fail "printed '$out', want '$want_out'"
  [ -z "$want_err" ] || grep -q -- "$want_err" "$err" || fail "stderr '$(cat "$err")' lacks '$want_err'"
  shift 4
  for pattern in "$@"; do
    if [ "${pattern#!}" != "$pattern" ]; then
      ! grep -q -- "${pattern#!}" "$CALLS" || fail "called gh ${pattern#!}"
    else
      grep -q -- "$pattern" "$CALLS" || fail "never called gh $pattern"
    fi
  done
  rm -f "$CALLS" "$err"
  [ "$failures" -gt "$before" ] || echo "ok   $case"
}

HEAD=new VIEWS=""
RUNS="feat/x@new=2 completed success
feat/x@*=2 completed success"
check "the head's green run is taken" 0 2 "" "--commit new" "!run watch"

RUNS="feat/x@*=1 completed success"
check "an older green run of the branch is not taken when the head has none" 1 "" "no ci.yml run of its head new" "!run watch"

RUNS="feat/x@new=2 in_progress
feat/x@*=2 in_progress
feat/x@old=1 completed success"
VIEWS="2 completed success"
check "the head's running run is waited for, then taken" 0 2 "waiting for" "run watch 2"

RUNS="feat/x@new=2 queued"
VIEWS="2 completed failure"
check "the head's run that fails once watched fails the step" 1 "" "is failure: https://github.com/ide4cj/cjls/actions/runs/2" "run watch 2"

RUNS="feat/x@new=2 completed cancelled"
VIEWS=""
check "the head's cancelled run fails the step" 1 "" "is cancelled: .*/runs/2" "!run watch"

HEAD=404
RUNS="feat/x@*=3 completed success"
check "a branch deleted after its merge takes its newest run" 0 3 "" "!--commit"

RUNS="feat/x@*=3 completed failure"
check "a deleted branch's failed newest run fails the step" 1 "" "newest commit is failure"

RUNS=""
check "no branch and no run is no pair" 0 "" "" "!run watch"

HEAD=500
check "an unreadable branch fails the step, it is not taken for none" 1 "" "cannot read" "!run list"

HEAD=new RUNS="feat/x@new=2 waiting"
VIEWS="2 in_progress
2 completed success"
check "a run still unfinished after a watch is watched again" 0 2 "" "run watch 2"

for verdict in "use 7:7 completed success" "watch 7:7 requested" "none:"; do
  case="decide: ${verdict#*:} -> ${verdict%%:*}"
  got=$(decide b "" "${verdict#*:}")
  if [ "$got" = "${verdict%%:*}" ]; then echo "ok   $case"; else fail "$got"; fi
done

[ "$failures" = 0 ] || { echo "$failures failed"; exit 1; }
