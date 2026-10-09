#!/usr/bin/env bash
# The ci.yml run of ide4cj/cjls whose build a client tests against the paired branch $1 (cjls's D32):
# the run of the branch's head commit, waited for while it is queued or running. When GitHub has
# already deleted the branch (its PR merged), the branch's newest run. Prints the run's id, or
# nothing when cjls has no such branch. Fails, naming the run, when that run did not succeed or the
# head has none: a pair is never tested against a release or an older build of the branch.

REPO=${CJLS_REPO:-ide4cj/cjls}

run_url() { echo "https://github.com/$REPO/actions/runs/$1"; }

# decide <branch> <head sha, empty when the branch is gone> <run: "id status conclusion", empty when none>
# prints "use <id>", "watch <id>", "none" (no pair) or "fail <why>"
decide() {
  local branch=$1 sha=$2 run=$3 id status conclusion
  if [ -z "$run" ]; then
    if [ -n "$sha" ]; then
      echo "fail $REPO@$branch has no ci.yml run of its head $sha (a branch runs CI once its PR is open): re-run this job once it has one"
    else
      echo none
    fi
    return
  fi
  read -r id status conclusion <<<"$run"
  if [ "$status" != completed ]; then
    echo "watch $id"
  elif [ "$conclusion" = success ]; then
    echo "use $id"
  else
    echo "fail $REPO@$branch's ci.yml run of ${sha:-its newest commit} is $conclusion: $(run_url "$id")"
  fi
}

# head_sha <branch>: the branch's head sha; empty when the branch does not exist; fails on any other error
head_sha() {
  local out
  if out=$(gh api "repos/$REPO/branches/$1" --jq .commit.sha 2>&1); then
    echo "$out"
  elif [[ $out == *"HTTP 404"* ]]; then
    :
  else
    echo "$out" >&2
    return 1
  fi
}

# runs <branch> [<sha>]: the newest ci.yml run of the branch (of that commit), "id status conclusion"
runs() {
  local args=(run list --repo "$REPO" --workflow ci.yml --branch "$1" --limit 1
    --json "databaseId,status,conclusion" --jq '.[] | "\(.databaseId) \(.status) \(.conclusion)"')
  if [ -n "${2:-}" ]; then args+=(--commit "$2"); fi
  gh "${args[@]}"
}

paired_run() {
  local branch=$1 sha run verdict id
  if ! sha=$(head_sha "$branch"); then
    echo "::error::cannot read $REPO's branch $branch" >&2
    return 1
  fi
  run=$(runs "$branch" "$sha") || return 1
  while :; do
    verdict=$(decide "$branch" "$sha" "$run")
    case $verdict in
      none) return 0 ;;
      use\ *) echo "${verdict#use }"; return 0 ;;
      fail\ *) echo "::error::${verdict#fail }" >&2; return 1 ;;
      watch\ *)
        id=${verdict#watch }
        echo "::notice::waiting for $REPO@$branch's CI: $(run_url "$id")" >&2
        # its own exit status is the run's, read again below
        gh run watch "$id" --repo "$REPO" --compact --interval 30 >&2 || true
        run=$(gh run view "$id" --repo "$REPO" --json databaseId,status,conclusion \
          --jq '"\(.databaseId) \(.status) \(.conclusion)"') || return 1
        ;;
    esac
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  paired_run "$1"
fi
