---
title: "Switchboard upstream source consolidation and release provenance"
date: 2026-10-01
status: active
summary: >-
  Dedicated source successor preserves the published broker and carries reviewed local integration tooling and explicit release provenance checks.
refs:
  - TIN-4655
  - TIN-5105
  - SWB-R49
  - SWB-R53
  - SWB-R54
  - R-N13
---

Authority: LAB-TAKEOVER-20260930, SWB-R49, SWB-R53 and R-N13.

Created an isolated successor from signed candidate
`b5158729355e836a3a98ade90d7649690e7a6900`, at
`/Users/jess/git/agent-switchboard-upstream-productionization-20260930`.
The primary tree and six existing worker/candidate trees remain preserved.
SWB-R49/R-N13: merged reviewed recipe PR #6 exact
`ff3f6f0c85344ef6ff6529200239cceaf140aa18` without committing yet.
Two ADR conflicts were resolved by retaining the R0/P1a text and adding
R49/R50 together; no runtime path changed. Independent source review and root
signer coordination remain pending.

SWB-R53/R-N13: the approved-release ledger names the exact published source,
pinned PR heads, immutable registry reference and publication receipt. Its file
map is SHA-256 of every selected build/runtime input at the approved commit.
The source checker compares that signed source and the current files, and
optionally verifies a supplied OCI layout and raw registry manifest. A source
successor is not a newly approved image. Supplied local evidence does not prove
a current authenticated cluster pull or a live deployment.

Fresh GitHub read: main remains `2a11acb2988a88ff0c5a6b6a7040487c6d55df0b`;
PRs #2–#6 remain open at the recorded exact heads. GitHub main landing remains
a separate merge-queue/ci-ok contract; SWB-R49 is a local integration lane,
not main bypass authority. No queue dispatch or GF execution was requested.


SWB-R49/SWB-R53/R-N13 validation receipt: Honey ran eleven finite tooling
integrity fixtures in `/home/jess/scratch/swb-release-check-20260930` and
passed all eleven in 0.020 seconds. Remote SHA-256 readbacks match local:
`release-check.py` = `0858c6fcc67315c46df858a315ed57e559df5f9dd25590256fef8a77ea8089ed`;
`test_release_check.py` = `b14c8baa561dd1b5301c759a7e1f933f420cc9c554772e0f34772f06d255f58f`.
No compilation, credentials, live broker, or provider calls were involved.

`just release-check` passed the signed b515 source/PR ancestry check and
27 protected input hashes. With preserved 2026-09-27 evidence supplied, it
also checked all 24 OCI blobs, Linux/amd64, UID 65532, entrypoint/command and
the raw 4,579-byte registry manifest. The report explicitly leaves
`fresh_registry_pull`, `live_acceptance`, and `publication_authorized` false.
The supplied historical manifest is not a current registry or node-pull test.

SWB-R49/R-N13 recipe receipt: the isolated successor's
`local-integrate-named-dry-run source-lane-probe-20260930` fetched exact
reviewed #2–#6 heads and verified all five commit signatures; canonical main
remains the recorded `2a11acb2`. No additional candidate tree was created.
The script and `just` recipes parse, diff whitespace is clean, and the 27
protected runtime/build inputs have an empty diff from b515.

Independent reviewer `upstream_release_review` identified and checked fixes
for three P2 source-tooling issues: path argument preservation, refusal of
empty/weakened protected-root configuration, and ignored untracked runtime
input enumeration. The checker now requires the v1 schema/exact required
roots and a nonempty source map. Final reviewer readback remains pending;
the reviewer made no edits, process signals or heavy local builds.

SWB-R51–SWB-R54/R-N13 source receipt: ADR-0001 now carries the established
shared-platform, Bumble/actual-MagicDNS, exact-image and state-custody rulings
from dated TIN-4655 comments. The productionization runbook identifies the
reviewed blahaj #1731 source, existing CREATEONLY owner gate, actual
backup/lock/restore and node-pull requirements, and four live P1b exits. It
retains Pi and combined Junie/Pi/LGTM acceptance, the fleet order and PZM hold.
Telemetry source proof and scrub qualification remain post-v1 as ruled.

Existing Sting source `24c03ab9` and its 24 owned broker/store/CLI plus 18
managed-hook cases are documented as prior evidence. They were not imported
or substituted for the R53 runtime. The prior service-roundtrip worker tree
remains unchanged. No backend apply, owner credential/Job issuance, namespace,
restart, down-fault test, new image publication, GF run, or upstream merge ran.


Independent final review receipt (SWB-R53/R-N13): SOURCE GO, no remaining
P0–P2. Reviewer reran all eleven fixtures and real signed-source validation;
protected source diff and whitespace remained clear. Exact reviewed hashes
are the two scripts above, ledger
`154cd863e03c1a0df0b8f2ebfbd81276b63004a17f5be9cd4524e0432f4d35c2`,
runbook `bc01a63d133a496b726d37c98cfad701fbdc707df195b71f2db0a8bb8c462909`,
ADR `aaa746a5d6caba5a7d99a8cc22a52f746f683845eac43263cced760a3d6dc7bb`,
and justfile `944c715df1908c307bd760afffa32c999118ea2be1e0eedc08b3318c030f5910`.
The merge index is resolved and staged. Root signer slot is requested before
signing; GitHub publication of this source branch remains separate.
