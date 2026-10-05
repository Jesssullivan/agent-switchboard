# agent-switchboard product brief

Authority: R-C265 (TIN-4655, operator direction 2026-10-04); refreshed
against v0.1.0 (SWB-R55) under R-C318. This is the one page that says who
`swb` serves, what works today, what blocks production, and which docs
survive. Decisions and rulings stay in the ADRs; rollout gates stay in
[operations/PRODUCTIONIZATION.md](operations/PRODUCTIONIZATION.md); how to
build, run and configure `swb` is the [README](../README.md).

## Users

| User | Wants |
| --- | --- |
| Operator (seat on neo) | See which agents are live where; route work between them without tmux injection |
| Agent seat (Claude, Kimi, Codex, Pi, Junie, OpenCode) | Find peers, message them in a thread, be told about unread mail, reply |
| New contributor (human or agent) | Build, run and change `swb` from the README alone |
| blahaj owner seat | Deploy one digest-pinned image with known settings and health signals |

## User stories and acceptance

Status: **holds** = true in v0.1.0; **gap** = not true yet.

1. **Run locally.** A contributor runs a loopback broker from the README.
   *Accept:* the README quickstart reaches send/inbox/ack between two ids in
   under 5 minutes on a warm host. **Holds:** README → "Run locally" uses
   only `swb` verbs.
2. **Register.** A harness session registers on SessionStart without agent
   action. *Accept:* `swb hook <harness> SessionStart` registers and the
   session appears in `peers`. **Holds** for the binary. Lab's launchers
   export `SWB_HOST`, `SWB_SESSION_PID`, `SWB_PROC_START` and
   `SWB_BROKER_URL` from their own pid when `tinyland.switchboard.enable` is
   set (R-C273). **Gap** in delivery: that switch is false on every host, and
   there is no live broker for it to point at.
3. **Discover.** An agent lists live peers. *Accept:* `peers` returns live and
   idle sessions only, bounded, without credentials. **Gap:** `peers` returns
   every session row, including `ended` and `gone`, with no limit; session
   rows are never pruned; and `proc_start` (the `/v1/end` check) is returned
   to every caller.
4. **Message.** An agent sends a ticketed message and gets a threaded reply.
   *Accept:* the broker stamps `authority: peer`; the reply shares
   `thread_id`. **Holds** over MCP, REST and `swb send --in-reply-to`.
5. **Notice.** An agent with unread mail is told on its next prompt, and can
   act on the notice. *Accept:* the notice names the agent's own id and one
   real command. **Gap:** the notice says "use agents inbox", which is not a
   command, and never tells the agent its id.
6. **Bash-only seat.** A seat with only a shell can read, reply and ack.
   *Accept:* `swb inbox`, `swb send`, `swb ack`, `swb peers`. **Holds**
   (R-C275). `swb inbox` returns one message per call.
7. **Coordinate.** Agents claim, release and hand off work. *Accept:* the
   ADR-0001 claim/handoff tools exist and the QuickCheck claim properties
   test Rust, not only the Haskell model. **Gap:** 5 of 11 tools ship
   (register, peers, send, inbox, ack).
8. **Diagnose.** The operator learns why a host is not enrolled. *Accept:*
   `swb doctor` prints resolved settings and broker reachability and exits
   nonzero on failure; hooks stay exit-0 (SWB-R10). **Holds:** `swb doctor
   [--register]` prints one `ok`/`skip`/`FAIL` line per check with a fix,
   and exits 3 on any failure. A hook itself still logs nothing.
9. **Deploy.** The blahaj owner runs the approved image. *Accept:* one
   documented settings table, `/healthz`, P1b exits met. **Gap:** v0.1.0 is
   published by digest (`sha256:c9170c71…`, SWB-R55, pushed by hand under
   R-C312) and the README carries the settings table, but there is no
   `/healthz`, no broker is deployed and 0 of the P1b exits are met. The
   staged blahaj source (#1793) still pins the never-published SWB-R53
   digest.

## Install story (measured on sting, 2026-10-04, main `08de158`)

| Step | Time |
| --- | --- |
| `git clone` | 1.1 s |
| `nix develop` (warm store) | 7 s |
| `just build` (364 cached Bazel actions; not a cold number) | 20 s |
| `swb serve` ready on `/metrics` | 145 ms |
| `swb hook claude SessionStart` (register) | 14 ms |
| send, inbox, reply, ack, notice | < 1 s total |

The recipe and the settings table are in the README. Without its readiness
wait the script registers nothing: a hook that fires before the listener is
up exits 0 silently (re-run on sting 2026-10-04: `/v1/peers` got curl exit
7, both hooks exited 0).

Still open from the install review: `just dev-serve` (loopback, scratch DB,
self-bounded), and `swb --help` on stdout with exit 0 (today any unknown
verb, `--help` included, prints usage on stderr and exits 2).

## AX/UX friction, ranked

1. **Hooks are inert by default.** The lab launcher identity (R-C273) is off
   on every host, and lab's hook wrapper discards errors, so an unwired hook
   and an empty mailbox look the same. Run `swb doctor` to tell them apart.
2. **Notice is not actionable.** Wrong command name, no agent id.
3. **`peers` is unbounded and leaks `proc_start`,** which lets any reader end
   any session through `/v1/end`.
4. **MCP schemas carry no field descriptions or patterns;** rules (ticket
   `TIN-<n>|none`, ULIDs, id shape `harness:host:pid:session`, 16 KiB body,
   inbox limits) surface only as errors. The CLI checks them locally first.
5. **Broker errors are terse:** `invalid agent id`, `unknown envelope field`
   without the field; every error but a `msg_id` conflict (409) is HTTP 400.
   The CLI prints the broker's error string, capped at 200 characters.
6. **CLI conventions:** `version` is a verb with no `--version` flag; help
   exits 2; `agentd` is listed in usage but exits 3; `whoami` registers;
   `whoami` and `inbox` report one missing variable per run (`doctor`
   reports them all).
7. **Client disagreement:** `swb` rejects a trailing `/` and `https`; lab's Pi
   client accepts both.
8. **No `/healthz`;** `/v1/notify` is not implemented; `/v1/end` has no MCP
   twin.
9. **Inbox long-poll prunes the store every 250 ms.**

## Doc set

| Doc | Holds |
| --- | --- |
| `README.md` | What, status, develop, run locally, settings, CLI and routes |
| `docs/PRODUCT.md` | Users, stories, install timings, friction, open decisions |
| `AGENTS.md` | Read order, source of truth, build placement, fork convention, invariant summary |
| ADR-0001, ADR-0002 | Decisions and Rulings tables; superseded wording lives in signed history (R-C275) |
| `docs/operations/PRODUCTIONIZATION.md` | Release lock, release workflow, rollout gates |
| `docs/operations/SLO.md` | SLIs, no targets (R-C263) |
| `spec/README.md` | Formal spec |
| `docs/agent-notes/` | Live-gate notes only; superseded notes retire under R35 |

A separate `CONTRIBUTING.md` was proposed to absorb the fork convention now
in AGENTS.md and ADR-0001; it does not exist yet.

## Decided since the first brief

- ADR supersession text: delete superseded wording and Deltas tables in
  signed commits; the Rulings tables stay normative (R-C275).
- Identity producer: the lab launchers export the identity from their own
  pid, behind the single `tinyland.switchboard.enable` switch (R-C273).
- CLI verbs `send`, `ack`, `peers`, `doctor`: shipped in v0.1.0 (R-C275).
- Release ID for the clock seam: SWB-R55; SWB-R54 stays state custody
  (R-C274, R-C304).

## Open decisions

Recommended default first.

1. **Notice command name.** *Default:* the MCP tool `mcp__agents__inbox` with
   `me=<agent_id>`, and `swb inbox` for bash seats; retire `ag` in the
   notice text.
2. **`peers` exposure.** *Default:* live/idle only, `limit`, no
   `proc_start`; `/v1/end` checks a credential never returned to others.
