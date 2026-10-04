---
title: "PR #7 landing hardening: secrets scan, CODEOWNERS, tag release"
date: 2026-10-04
status: active
summary: >-
  Adds the required secrets-scan job, CODEOWNERS and a signed-tag release
  workflow that can push only the SWB-R53 approved digest, plus release-check
  --tag/--main-ref/--built-digest. No protected input changed.
refs:
  - TIN-4655
  - SWB-R53
  - R-C227
  - R-C228
  - R-N13
---

R-C227 / R-C228 / SWB-R53 / R-N13. Source work only, authored on neo; nothing
was built, pushed to a registry, queued or merged.

## What changed

- `ci.yml`: new `secrets-scan` job (pinned `xoxd-ai/ci-templates`
  secrets-scan action at `ae836d84`, v5.1.1: TruffleHog 3.95.3
  `--only-verified`, gitleaks 8.30.1, both checksum-pinned), full-history
  checkout, gated like the Rust lane on fork PRs; `ci-ok` now needs it.
- `.gitleaks.toml` (default rules), `.github/CODEOWNERS` (`@Jesssullivan`).
- `release.yml`: signed annotated `v*` tag only; imports
  `docs/releases/release-signers.asc` (public key, primary
  `161895136D2E5C292D2A663D0B01977B8DD5DA60`) into an empty key ring and
  requires exactly that primary; `release-check --tag --main-ref origin/main`;
  Bazel builds `//deploy:image.digest`; `--built-digest` refuses any digest
  other than the approved one before push; `bazelisk run //deploy:push`;
  ghcr.io readback by digest verified with `--registry-manifest`; evidence
  uploaded as a workflow artifact. Never on pull_request or merge_group.
- `release-check.py`: `--tag`, `--main-ref`, `--built-digest`; 8 new
  owned-fixture tests (17 total, pass on neo in 0.03 s, no build).
- `flake.nix`: `gitleaks` and `trufflehog` in the default devShell; a
  minimal `release` devShell (git, gnupg, curl, jq, python3, coreutils).
- `just secrets-scan`, `just release-check-tag`; docs: ADR CI bullet,
  PRODUCTIONIZATION, AGENTS, `tinyland.repo.json` (schema-validated).

## Evidence on neo

- `just release-check`: passed, 27 inputs, HEAD unchanged protected roots.
- `gitleaks git --config .gitleaks.toml`: 55 commits, no leaks.
- A throwaway clone with a signed annotated tag passed `--tag --main-ref`;
  an unsigned annotated tag failed on the signature check.
- Ephemeral key ring from `release-signers.asc` verified b515 (exit 0).
- `nix flake check --no-build` and `actionlint` (only unknown self-hosted
  label notices) clean.

## Open

- The `main-merge-queue` ruleset has no bypass actors, so the R-C228 admin
  merge is refused until a ruling changes the ruleset (and ADR-0001's
  "It has no bypass actors").
- Sting receipts bound to the new head are still owed: `just check`,
  `just release-check`, `just release-check-test`, `just secrets-scan`.
- Before the first tag: the ghcr package must grant this repository's Actions
  write access; the release workflow has never run on a GF runner. Whether a
  rebuilt tree reproduces `sha256:b0633ecb…` is unproven; if not, the
  workflow refuses to push, by design.
- A guard-hook refusal (R-N12) stopped a diff self-scan whose grep pattern
  spelled process-control words; that scan was dropped, not rephrased.
