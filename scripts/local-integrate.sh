#!/usr/bin/env bash
# TIN-4655: assemble pinned switchboard PRs in a signed local worktree.
# This is local source integration, not a GitHub main or deployment operation.
set -euo pipefail

# SWB-R49 / R-N13: fail before fetching refs or creating integration state.
# macOS ships Bash 3.2; this recipe needs Bash 4+ for associative arrays.
if (( BASH_VERSINFO[0] < 4 )); then
  echo 'error: local integration requires Bash 4 or newer; select a supported Bash on PATH before running just local-integrate' >&2
  exit 2
fi

usage() {
  cat <<'EOF'
Usage: local-integrate.sh [--dry-run] [--name NAME] 'PR@FULL_SHA [PR@FULL_SHA ...]'

Creates ../agent-switchboard-local-integration from fresh upstream/main, or
../agent-switchboard-local-integration-NAME when --name is supplied, and
merges the pinned upstream PR heads in the supplied order. Every created merge
commit is signed. The destination must not already exist; the script never
resets or removes a worktree. It never pushes, changes a PR, or updates main.
NAME is 1–48 lowercase ASCII letters, digits or hyphen-separated segments,
starting with a letter and ending with a letter or digit.
Run `just remote-check honey` from the printed destination after integration.
EOF
}

dry_run=0
name=
name_set=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      dry_run=1
      shift
      ;;
    --name)
      if [[ $name_set -eq 1 || $# -lt 2 ]]; then
        echo 'error: --name requires one name and may appear only once' >&2
        exit 2
      fi
      name=$2
      name_set=1
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
    *) break ;;
  esac
done
if [[ $name_set -eq 1 && ( ${#name} -gt 48 || $name == *[!abcdefghijklmnopqrstuvwxyz0123456789-]* || ! $name =~ ^[a-z]([a-z0-9]*(-[a-z0-9]+)*)$ ) ]]; then
  echo 'error: name must be 1–48 lowercase ASCII letters, digits or hyphen-separated segments, starting with a letter' >&2
  exit 2
fi
if [[ $# -ne 1 || -z $1 || $1 == *$'\n'* ]]; then
  usage >&2
  exit 2
fi

refs=$1
IFS=' ' read -r -a specs <<< "$refs"
if [[ ${#specs[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

declare -a numbers=() expected_shas=()
declare -A seen=()
for spec in "${specs[@]}"; do
  if [[ ! $spec =~ ^([1-9][0-9]*)@([0-9a-f]{40})$ ]]; then
    echo "error: use PR@FULL_SHA with a positive PR number and 40 lowercase hex characters: $spec" >&2
    exit 2
  fi
  number=${BASH_REMATCH[1]}
  expected=${BASH_REMATCH[2]}
  if [[ -n ${seen[$number]:-} ]]; then
    echo "error: duplicate PR #$number" >&2
    exit 2
  fi
  seen[$number]=1
  numbers+=("$number")
  expected_shas+=("$expected")
done

root=$(git rev-parse --show-toplevel)
upstream_url=$(git -C "$root" remote get-url upstream)
case "$upstream_url" in
  https://github.com/xoxd-ai/agent-switchboard.git|\
  git@github.com:xoxd-ai/agent-switchboard.git|\
  ssh://git@github.com/xoxd-ai/agent-switchboard.git) ;;
  *)
    echo "error: upstream is not canonical xoxd-ai/agent-switchboard: $upstream_url" >&2
    exit 2
    ;;
esac

destination="${root}-local-integration"
branch=local-integration/current
if [[ $name_set -eq 1 ]]; then
  destination="${destination}-${name}"
  branch="local-integration/${name}"
fi
if [[ -e $destination || -L $destination ]]; then
  echo "error: destination already exists; inspect it before another integration: $destination" >&2
  exit 1
fi
if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
  echo "error: branch $branch already exists; inspect it before another integration" >&2
  exit 1
fi

echo 'SWB-R49 / R-N13 / TIN-4655: fetching exact local-integration inputs'
git -C "$root" fetch --no-tags upstream refs/heads/main:refs/remotes/upstream/main
base_sha=$(git -C "$root" rev-parse --verify 'refs/remotes/upstream/main^{commit}')
for index in "${!numbers[@]}"; do
  number=${numbers[$index]}
  expected=${expected_shas[$index]}
  git -C "$root" fetch --no-tags upstream "refs/pull/$number/head"
  actual=$(git -C "$root" rev-parse --verify 'FETCH_HEAD^{commit}')
  if [[ $actual != "$expected" ]]; then
    echo "error: PR #$number changed: expected $expected, fetched $actual" >&2
    exit 1
  fi
  if ! git -C "$root" verify-commit "$expected" >/dev/null 2>&1; then
    echo "error: PR #$number head $expected did not pass local commit signature verification" >&2
    exit 1
  fi
  printf 'verified PR #%s %s\n' "$number" "$expected"
done

printf 'base %s\ndestination %s\n' "$base_sha" "$destination"
if [[ $dry_run -eq 1 ]]; then
  echo 'dry-run: no integration worktree or merge commits created'
  exit 0
fi

git -C "$root" worktree add -b "$branch" "$destination" "$base_sha"
message_file=$(mktemp "${TMPDIR:-/tmp}/swb-local-merge.XXXXXX")
trap 'rm -f "$message_file"' EXIT

for index in "${!numbers[@]}"; do
  number=${numbers[$index]}
  expected=${expected_shas[$index]}
  if git -C "$destination" merge-base --is-ancestor "$expected" HEAD; then
    printf 'PR #%s already included at %s\n' "$number" "$expected"
    continue
  fi
  printf 'Merge PR #%s locally (TIN-4655)\n\nSWB-R49, R-N13: local integration, 2026-09-27.\nPinned source: %s\nGitHub main and PR state are unchanged.\n' \
    "$number" "$expected" > "$message_file"
  if ! git -C "$destination" merge --no-ff --no-commit "$expected"; then
    echo "error: PR #$number merge stopped; inspect $destination and do not continue on an unresolved merge" >&2
    exit 1
  fi
  git -C "$destination" -c commit.gpgsign=true commit -S -F "$message_file"
  git -C "$destination" verify-commit HEAD >/dev/null
  printf 'merged PR #%s %s -> %s\n' "$number" "$expected" "$(git -C "$destination" rev-parse HEAD)"
done

git -C "$destination" diff --check "$base_sha" HEAD
if [[ -n $(git -C "$destination" status --porcelain) ]]; then
  echo "error: integration worktree is not clean: $destination" >&2
  exit 1
fi
printf 'local integration complete: %s\n' "$(git -C "$destination" rev-parse HEAD)"
printf 'worktree: %s\nnext: cd %s && just remote-check honey\n' "$destination" "$destination"
