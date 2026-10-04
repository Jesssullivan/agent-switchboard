---
title: "Named switchboard local integration candidate"
date: 2026-09-27
status: active
summary: >-
  SWB-R49 named recipe change prepared on signed PR #6 head for a second immutable candidate; integration remains unrun.
refs:
  - TIN-4655
---

# Named candidate preparation

SWB-R49 / R-N13: This change starts from signed PR #6 head
`93e055157af0` in the isolated
`agent-switchboard-named-recipe-20260927` worktree. The existing
`local-integration/current` worktree is clean at signed candidate
`6330f2e3dfdb` and has not been removed or modified. The new PR #5 head is
`330d949beb16`.

The `--name` option and matching `just local-integrate-named` recipes select a
new destination and branch, while the default recipe retains its original
names. Both paths keep the exact full-SHA, source-signature, canonical-upstream,
and existing-candidate checks. The script still makes no push or main/PR
mutation. Validation accepted a dry run of the new #5 head, showing its new
destination without creating it. The default and `--name current` routes
refused the existing branch. Invalid and empty names failed before fetch.
`bash -n` and `just --list` passed. No actual integration, build, publication,
deployment or process signaling occurred.

## Independent review and dry-run scope

SWB-R49 / R-N13: An independent Astra review found no P0–P2 issue. It checked
the signed base and preserved current candidate, 13 invalid-name cases,
duplicate/missing/unknown options, and the default/current collisions. The
named dry run fetches the pinned Git objects and updates `FETCH_HEAD` and the
local `upstream/main` tracking ref; it creates no worktree or merge commit.
The review cleared this narrow change for staged checks and a signed commit.
