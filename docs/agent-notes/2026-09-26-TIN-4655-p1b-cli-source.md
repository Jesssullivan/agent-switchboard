---
title: "P1b CLI source and session-binding boundary"
date: 2026-09-26
status: active
summary: >-
  swb gains bounded REST-backed hook, whoami and inbox commands; identity sources and live broker reach remain separate P1b gates.
refs:
  - TIN-4655
  - SWB-R10
  - SWB-R14
  - R-N11
  - R-N13
---

## Source receipt

R-N13, SWB-R10 and SWB-R14: swb whoami registers an explicitly supplied
harness/session identity; swb inbox reads its explicit SWB_AGENT_ID; the
Claude/Kimi hook reads bounded JSON input and registers on SessionStart,
UserPromptSubmit and Stop. UserPromptSubmit returns a body-free unread notice
as Claude hook additionalContext. SessionEnd calls /v1/end, which checks
the exact proc_start before setting ended. All hook errors remain silent
and exit zero. The lab wrapper applies the outer 1.8-second deadline; each
network call has its own 1.5-second bound. No process is signaled (R-N11).

This source requires explicit SWB_BROKER_URL (HTTP host and port),
SWB_HOST, SWB_SESSION_PID, and SWB_PROC_START. whoami also requires
SWB_HARNESS and SWB_SESSION_ID; inbox requires SWB_AGENT_ID. It does
not infer a parent PID. No live hostname is in source. The current lab hook
projection does not yet supply a proved PID/proc_start, so activation remains
gated. Native Pi/Junie session-file discovery and the Codex calling-session
binding in ADR-0001 are not claimed by this explicit-input source.

## Verification

On Honey, just lock regenerated Cargo, crate-universe and Bazel module
locks as one set. Its last git status command exited 128 because the remote
scratch copy intentionally omits .git; all lock generation commands had
completed, and the three files were copied back together. Honey
just remote-check then passed all eight Bazel targets, including loopback
HTTP registration, request-path rejection and ended transition tests.
Honey just build passed //:build and //deploy:swb_layer.
Neo performed no compile. No live broker, host delivery or process control
was attempted.
