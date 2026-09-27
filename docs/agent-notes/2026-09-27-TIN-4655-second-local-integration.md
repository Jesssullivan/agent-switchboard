---
title: "Second signed switchboard local integration candidate"
date: 2026-09-27
status: active
summary: >-
  SWB-R49 second named #2–#5 candidate is signed and Honey-validated; OCI image built and locally smoked without publication.
refs:
  - TIN-4655
---

# Second local candidate receipt

SWB-R49 / R-N13: The reviewed signed PR #6 recipe head `ff3f6f0` was run
with name `second-20260927` and exact reviewed PR heads #2 `12dd8637`,
#3 `db3d966c`, #4 `5211eacd`, and fork PR #5 `330d949b`. The dry run
verified signatures and selected fresh upstream main `2a11acb` as base.
The named worktree is
`/Users/jess/git/agent-switchboard-named-recipe-20260927-local-integration-second-20260927`,
branch `local-integration/second-20260927`. Signed merge commits are
`e959948` (#2), `e4907c8` (#3), `52be7c0` (#4), and **`b515872` (#5)**.
All four pinned heads are ancestors of the clean candidate. The original
`local-integration/current` worktree remains clean at `6330f2e`; the PR #6
recipe branch remains at `ff3f6f0`.

SWB-R49 / R-N13: The #5 merge had one README content conflict. Its resolution
matches the first candidate's README, retaining both the fork contribution
text and the OCI publication instructions. `git diff --check` passed. No
guard-hook refusal occurred. No process was signaled.

SWB-R49 / R-N13: The exact candidate source was copied to a dedicated Honey
scratch directory with the repo's `remote-check` recipe. Honey's
`just check` passed format, Clippy, and all 8 Bazel test targets (729 actions,
286.7 seconds). `just build` and `just image` passed on Honey and produced
OCI digest `sha256:b0633ecb…c6309`. The local OCI layout loaded into
Podman. A foreground, self-terminating `swb version` container exited zero
and printed `swb 0.1.0 envelope v3`; the image config reports UID 65532,
entrypoint `/usr/local/bin/swb`, and default command `serve`.

An independent Astra source review found no P0–P2 issue. It confirmed the
new retention startup/hourly paths and bounded listener drain. Its scope
limit remains: a 30-second drain plus 5-second grace does not guarantee
exit if SQLite blocks. The smoke proves packaging and executable startup,
not live broker readiness or rollout acceptance.

SWB-R49 / R-N13: This receipt is committed on a separate local docs branch.
The candidate, original candidate, GitHub main and PR merge state remain
unchanged. No image was published and no GF runner was used. Full immutable
source and image identifiers are in the TIN-4655 handoff receipt.
