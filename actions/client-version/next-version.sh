#!/usr/bin/env bash
# The version a client of cjls releases next (cjls's D132): the major and minor of the cjls release
# it pins, and a patch of its own. A pin on a newer minor than the client's last release starts that
# minor at .0; on the last release's minor, the patch goes up by one, whether cjls's patch or the
# client's own change. Prints nothing when there is nothing to release: no commit since the last
# release that `cog bump --auto` would release.
#
# next-version.sh [<pin>]: the pin is a cjls tag, `.cjls-version`'s by default; run at the root of a
# clone with its tags, `cog` on PATH.

# next_version <pin vMAJOR.MINOR.PATCH> <the last release's tag, empty when none> <releasable: true|false>
# prints the version without its `v`, or nothing; fails naming why
next_version() {
  local pin=$1 last=$2 releasable=$3 pin_major pin_minor major minor patch
  if [[ ! $pin =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
    echo "::error::the pin '$pin' is no cjls release vMAJOR.MINOR.PATCH" >&2
    return 1
  fi
  pin_major=${BASH_REMATCH[1]} pin_minor=${BASH_REMATCH[2]}
  [ "$releasable" = true ] || return 0
  if [ -z "$last" ]; then
    echo "$pin_major.$pin_minor.0"
    return
  fi
  if [[ ! $last =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "::error::the last release '$last' is no vMAJOR.MINOR.PATCH" >&2
    return 1
  fi
  major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
  if [ "$pin_major" = "$major" ] && [ "$pin_minor" = "$minor" ]; then
    echo "$major.$minor.$((patch + 1))"
  elif [ "$pin_major" -gt "$major" ] || { [ "$pin_major" = "$major" ] && [ "$pin_minor" -gt "$minor" ]; }; then
    echo "$pin_major.$pin_minor.0"
  else
    echo "::error::the pin $pin is older than the last release $last" >&2
    return 1
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  pin=${1:-$(tr -d '[:space:]' <.cjls-version)}
  # the newest release tag on this branch; `nightly`, a client's rolling pre-release, is none
  last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
  releasable=false
  if [ -n "$(cog bump --auto --dry-run 2>/dev/null || true)" ]; then releasable=true; fi
  next_version "$pin" "$last" "$releasable"
fi
