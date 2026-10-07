---
title: "R-C389: swb channel, the Claude Code channel emitter (SWB-R56)"
date: 2026-10-07
status: active
summary: >-
  Adds `swb channel`, a stdio MCP server that pushes broker inbox messages
  into a running Claude Code session as channel events, fixes the
  UserPromptSubmit notice text, and bumps the workspace to 0.2.0.
refs:
  - TIN-4655
  - TIN-5770
  - R-C389
  - SWB-R56
  - SWB-R03
  - SWB-R17
  - SWB-R10
  - SWB-R14
  - SWB-R20
---

R-C389 (Linear TIN-5770 comment `d00ba5ef`, operator interview
2026-10-07): "Adopt channels now". Authored from neo; built and tested on
sting only.

## Contract, from primary sources

Read on 2026-10-07 from `code.claude.com/docs/en/channels-reference`,
`/channels` and `/mcp`. The census before this lane had inferred the flags
from strings in the 2.1.290 executable only.

- Capability: `capabilities.experimental["claude/channel"] = {}`. The
  optional `claude/channel/permission` capability relays tool approvals;
  `swb channel` never declares it.
- Event: `notifications/claude/channel` with `content` (string) and `meta`
  (string values; non-identifier keys are dropped). The model sees
  `<channel source="<server name>" …>content</channel>`. There is no
  acknowledgement, and events are dropped silently when the server is not
  loaded as a channel.
- Transport: stdio, spawned by Claude Code. Stdio MCP servers inherit the
  parent environment unless `CLAUDE_CODE_MCP_ALLOWLIST_ENV=1`. No session
  id is exported to an MCP server.
- On the v2 MCP runtime a channel server that negotiates revision
  2026-07-28 is not registered as a channel. `swb channel` answers
  `initialize` with 2025-11-25 or older.
- Loading: `--channels` accepts only allowlisted plugins. A plain MCP
  server loads only with `--dangerously-load-development-channels
  server:<name>`. That flag shows a startup confirmation, is ignored with
  `-p`, and still obeys `channelsEnabled`. Channels require Anthropic
  authentication (claude.ai or a Console key), not a third-party provider.

## Prior attempt

An earlier run of this lane left an untracked 970-line
`crates/swb/src/channel.rs` in `sting:/srv/scratch/jess/swb-channels`, with
no main.rs wiring, no BUILD change and a reference to a missing `VERSION`.
It had not compiled. This lane reviewed it, kept its design and fixed:

- the module wiring, `VERSION`, the BUILD `srcs` and test-helper visibility;
- the identity lookup, which required `proc_start` in `peers`. PRODUCT.md
  open decision 2 proposes removing that field, so the lookup now matches
  host and pid when the field is absent;
- the protocol list, which now includes 2025-11-25;
- rustfmt in three test hunks.

## Validation on sting

- `just lock` (tinyland-heavy): Cargo.lock and cargo-bazel-lock.json change
  only by the five crate versions; MODULE.bazel.lock is unchanged.
- `just check` (tinyland-heavy): 9 of 9 targets pass, including clippy and
  rustfmt. `swb_test` runs 40 tests, 17 of them channel tests.
- An end-to-end driver ran the built binary against a loopback
  `swb serve` (self-bounded by `timeout 180`, scratch DB under
  `/srv/data/jess/scratch/swb-rc389/e2e`). 24 of 24 checks passed:
  - the handshake declined 2026-07-28 and answered 2025-11-25;
  - the event arrived 0.2 s after a peer send, with sender, ticket and body;
  - a forged `</channel>` in the body was neutralised;
  - `reply` sent a threaded answer and acked the original, and the notice
    then disappeared;
  - with the broker down, `initialize` and a tool error each answered
    within 2 ms, the process stayed up, and stderr had one line.
- Not validated: a live Claude Code session loading the channel. That
  needs an interactive session with the development flag and its
  confirmation, which this lane did not start.

## Release

The workspace version is 0.2.0. `just release-check` fails on this head by
design: it hashes the protected inputs against the SWB-R55 source
`d8ebfdbf`, and this change edits them. A v0.2.0 image needs a new
approved-release record and an operator ruling for its digest (the SWB-R55
pattern), built from the merge commit after this lands.
