---
title: "Local integration Bash admission"
date: 2026-10-02
status: active
summary: >-
  Refuse unsupported Bash before local integration state changes.
refs:
  - TIN-4655
  - SWB-R49
  - R-N13
---

SWB-R49 / R-N13: added a Bash 4-or-newer admission check to the local
integration script before argument parsing, associative declarations, Git
fetches or worktree creation. Native macOS Bash 3.2 now receives an actionable
error directing the operator to select a supported Bash on PATH. The recipe
still uses the existing interpreter selection; no package or global shell
change is introduced.

The isolated source successor preserves signed candidate b515 and tooling
d215. Runtime/build inputs, remote-check and upstream landing contracts are
unchanged. Syntax and native Bash 3.2 refusal were checked without network,
Git mutation, integration execution or compilation. Independent claude_source_coordination review returned SOURCE GO for the
exact guard and note before normal signing. No live broker or custody proof follows.
