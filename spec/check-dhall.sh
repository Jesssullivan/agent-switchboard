#!/usr/bin/env bash
# Dhall spec check (R-C229). Needs dhall, dhall-json and jq on PATH; the
# devShell and the flake check spec-dhall provide them.
#
#   check-dhall.sh [REPO_ROOT] [OWNERS_JSON]
#
# 1. Type-checks every spec/dhall/*.dhall file.
# 2. Renders spec/dhall/approved-broker.dhall and requires it to equal
#    docs/releases/approved-broker.json (after jq -S).
# 3. Renders spec/dhall/Broker.dhall and requires it to equal the committed
#    spec/dhall/generated/broker-constants.json (after jq -S).
# 4. Reads OWNERS_JSON (default: the pinned snapshot in spec/fixtures) into
#    RustfsBucketIam.dhall with strict records and requires the round trip to
#    equal the input (after jq -S).
# It reads files and writes only under a private temporary directory.
set -euo pipefail

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
owners="${2:-$root/spec/fixtures/blahaj-rustfs-iam-owners.json}"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export XDG_CACHE_HOME="$work/dhall-cache"
mkdir -p "$XDG_CACHE_HOME"
dhall_dir="$root/spec/dhall"
fail=0

for f in "$dhall_dir"/*.dhall; do
  if ! dhall type --file "$f" >/dev/null; then
    echo "spec-dhall: type error in ${f#"$root"/}" >&2
    fail=1
  fi
done

same() { # same LABEL RENDERED COMMITTED
  if ! cmp -s <(jq -S . "$2") <(jq -S . "$3"); then
    echo "spec-dhall: $1 differs from its Dhall source" >&2
    diff -u <(jq -S . "$3") <(jq -S . "$2") >&2 || true
    fail=1
  fi
}

dhall-to-json --file "$dhall_dir/approved-broker.dhall" >"$work/approved-broker.json"
same docs/releases/approved-broker.json "$work/approved-broker.json" "$root/docs/releases/approved-broker.json"

dhall-to-json --file "$dhall_dir/Broker.dhall" >"$work/broker-constants.json"
same spec/dhall/generated/broker-constants.json "$work/broker-constants.json" "$dhall_dir/generated/broker-constants.json"

(cd "$dhall_dir" && json-to-dhall ./RustfsBucketIam.dhall --file "$owners") >"$work/owners.dhall"
dhall-to-json --file "$work/owners.dhall" >"$work/owners.json"
same "$owners" "$work/owners.json" "$owners"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "spec-dhall: ok"
