---
title: "Switchboard local source integration while GF is in development"
date: 2026-09-27
status: active
summary: >-
  SWB-R49 local recipe, pinned-source dry run, and the separate main and live-acceptance gates.
refs:
  - TIN-4655
---

# Local integration carrier

SWB-R49 records the operator's direction to use local merge recipes while GF
is in development. The new `just local-integrate` recipe assembles pinned
switchboard PR heads from fresh upstream main in a separate worktree. Each
created merge commit is signed. The recipe does not push, change GitHub PRs,
or alter upstream main. Its result is a source-validation tree, not the
original P1a merge-queue exit or production acceptance.

The first dry run resolved and locally verified the signed heads of #2, #3,
#4 and #5 at `12dd8637`, `db3d966c`, `5211eacd` and `6575d45d` against
upstream main `2a11acb2`. It created no integration worktree. An initial
fetch refspec removed the local `upstream/main` tracking ref without touching
the checked-out branch; the script was corrected to fetch explicit
`refs/heads/main`, the tracking ref was restored, and the complete dry run
passed. An independent review identified a permissive upstream-URL suffix
match; an exact canonical GitHub URL allowlist replaced it before actual
integration. This note is the R-N13 receipt for those local source mutations.

Next: run the exact pinned local integration recipe, verify its signed merge
commits and clean worktree, then run `just remote-check honey` from that tree.
Record the Honey result and source marker. GitHub main landing, blahaj image
publication/deployment, L0 and cross-host functional exits remain distinct.

## 20:26 UTC result

SWB-R49 / R-N13: `just local-integrate` created
`/Users/jess/git/agent-switchboard-local-integration` from upstream main
`2a11acb2`, then merged pinned PRs #2, #3, #4 and #5 in that order. All four
local merge commits have verified `G` signatures; the clean result is
`6330f2e3`. PR #5 had one additive README conflict. The signed merge retained
both the fork-contribution paragraph and the immutable OCI publication/PVC
guidance. The staged safety audit and diff check passed. No hook refused,
no source PR or upstream main changed, and no broker was deployed.

Honey ran `just remote-check honey` from that exact local tree, using a
dedicated `~/scratch/agent-switchboard-local-6330f2e` source directory. Bazel
`//:check` passed all eight targets, including format, Clippy, unit and
broker integration tests: 725 actions, 8/8 tests, 288.9 seconds. A checksum
dry-run rsync with directory times omitted emitted no differences between the
clean local worktree and Honey's tested source. The local merge is source
integration evidence only; the image from this exact tree is not published,
and the four live P1b exits remain unproved.
