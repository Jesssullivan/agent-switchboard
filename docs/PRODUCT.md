# agent-switchboard product brief

Authority: R-C265 (TIN-4655, operator direction 2026-10-04). Measured against
`main` `08de158`. This is the one page that says who `swb` serves, what works
today, what blocks production, and which docs survive. Decisions and rulings
stay in the ADRs; rollout gates stay in
[operations/PRODUCTIONIZATION.md](operations/PRODUCTIONIZATION.md).

## Users

| User | Wants |
| --- | --- |
| Operator (seat on neo) | See which agents are live where; route work between them without tmux injection |
| Agent seat (Claude, Kimi, Codex, Pi, Junie, OpenCode) | Find peers, message them in a thread, be told about unread mail, reply |
| New contributor (human or agent) | Build, run and change `swb` from the README alone |
| blahaj owner seat | Deploy one digest-pinned image with known settings and health signals |

## User stories and acceptance

Status: **holds** = verified today; **gap** = not true on `main`.

1. **Run locally.** A contributor runs a loopback broker from the README.
   *Accept:* README quickstart reaches a threaded send/inbox/ack between two
   ids in under 5 minutes on a warm host. **Gap:** works (measured below) but
   only by reading `spec/README.md` and `crates/swb/src/main.rs`.
2. **Register.** A harness session registers on SessionStart without agent
   action. *Accept:* `swb hook <harness> SessionStart` registers and the
   session appears in `peers`. **Holds** for the binary; **gap** in delivery:
   nothing in lab sets `SWB_HOST`, `SWB_SESSION_PID`, `SWB_PROC_START` or
   `SWB_BROKER_URL` for Claude, so the hook exits 0 silently.
3. **Discover.** An agent lists live peers. *Accept:* `peers` returns live and
   idle sessions only, bounded, without credentials. **Gap:** sessions are
   never pruned and `proc_start` (the `/v1/end` check) is returned to everyone.
4. **Message.** An agent sends a ticketed message and gets a threaded reply.
   *Accept:* broker stamps `authority: peer`; reply shares `thread_id`.
   **Holds** over MCP and REST.
5. **Notice.** An agent with unread mail is told on its next prompt, and can
   act on the notice. *Accept:* the notice names the agent's own id and one
   real command. **Gap:** notice says `agents inbox`; ADR and agentd say
   `ag inbox`; neither exists, and the agent is never told its id.
6. **Bash-only seat.** A seat with only a shell can read, reply and ack.
   *Accept:* `swb inbox`, `swb send`, `swb ack`, `swb peers`. **Gap:** only
   `whoami` and `inbox` exist.
7. **Coordinate.** Agents claim, release and hand off work. *Accept:* the
   ADR-0001 claim/handoff tools exist and the QuickCheck claim properties
   test Rust, not only the Haskell model. **Gap:** 5 of 11 tools ship
   (register, peers, send, inbox, ack).
8. **Diagnose.** The operator learns why a host is not enrolled. *Accept:*
   `swb doctor` prints resolved settings and broker reachability and exits
   nonzero on failure; hooks stay exit-0 (SWB-R10). **Gap:** no doctor, no
   debug log; "not wired" is indistinguishable from "no mail".
9. **Deploy.** The blahaj owner runs the approved image. *Accept:* one
   documented settings table, `/healthz`, P1b exits met. **Gap:** 0 of 7 P1b
   exits met; no broker deployed; v0.1.0 blocked on two things: the GHCR
   package grants this repo no Actions write access (UI-only operator act),
   and a rebuild of `main` gives `b7e8788e`, not the SWB-R53 digest
   `b0633ecb`.

## Install story (measured on sting, 2026-10-04)

| Step | Time |
| --- | --- |
| `git clone` | 1.1 s |
| `nix develop` (warm store) | 7 s |
| `just build` (364 cached Bazel actions; not a cold number) | 20 s |
| `swb serve` ready on `/metrics` | 145 ms |
| `swb hook claude SessionStart` (register) | 14 ms |
| send, inbox, reply, ack, notice | < 1 s total |

The working recipe, until it moves into the README:

```sh
just build                                   # on sting or honey, never neo
swb=$PWD/bazel-bin/crates/swb/swb
d="$(mktemp -d "$HOME/scratch-swb.XXXXXX")"
timeout 600 env SWB_DB_PATH="$d/swb.sqlite3" \
  SWB_LISTEN=127.0.0.1:18080 SWB_METRICS_LISTEN=127.0.0.1:19090 \
  "$swb" serve &
# Wait for the listener: a hook that fires first fails silently (SWB-R10).
until curl -sf http://127.0.0.1:19090/metrics >/dev/null; do sleep 0.1; done
export SWB_BROKER_URL=http://127.0.0.1:18080 SWB_HOST="$(hostname -s)" \
  SWB_SESSION_PID=40001 SWB_PROC_START=2026-10-04T00:00:00Z
echo '{"session_id":"sess-a"}' | "$swb" hook claude SessionStart
SWB_AGENT_ID="claude:$SWB_HOST:40001:sess-a" "$swb" inbox
```

The broker exits on its own `timeout`; nothing needs to be signalled. It
prints one JSON audit line per register, send and ack to the same terminal.
Without the readiness wait, the pasted script registers nothing (re-run on
sting 2026-10-04: `/v1/peers` got curl exit 7, both hooks exited 0).

Fixes, in order: README quickstart (above); a settings table; `just
dev-serve` (loopback, scratch DB, self-bounded); `swb --help` on stdout with
exit 0 (today it exits 2); state where the binary lands
(`bazel-bin/crates/swb/swb`).

### Settings

| Variable | Read by | Default | Required |
| --- | --- | --- | --- |
| `SWB_DB_PATH` | serve | `/var/lib/swb/swb.sqlite3` | for non-root |
| `SWB_LISTEN` | serve | `0.0.0.0:8080` | no |
| `SWB_METRICS_LISTEN` | serve | `0.0.0.0:9090` | no |
| `SWB_MCP_ALLOWED_HOSTS` | serve | loopback only | in deployment |
| `SWB_BROKER_URL` | hook, CLI | none; `http://host:port`, no trailing `/` | yes |
| `SWB_HOST` | hook, CLI | none | yes |
| `SWB_SESSION_PID` | hook, CLI | none | yes |
| `SWB_PROC_START` | hook, CLI | none | yes |
| `SWB_HARNESS` | hook, `whoami` | hook: its argv harness, which this overrides; `whoami`: none | for `whoami` |
| `SWB_SESSION_ID` | `whoami` | none (hooks read `session_id` from stdin) | for `whoami` |
| `SWB_AGENT_ID` | `inbox` | none; `harness:host:pid:session_id` | for `inbox` |

## AX/UX friction, ranked

1. **Hooks are inert and silent.** No lab producer for the identity
   variables; lab's wrapper also discards errors. Claude does not pass its
   pid; a hook's `$PPID` is not guaranteed to be the Claude process, and
   walking the process tree to find it is the ancestry pattern the R-N11
   incident record warns against.
2. **Notice is not actionable.** Wrong command name, no agent id.
3. **`peers` is unbounded and leaks `proc_start`,** which lets any reader end
   any session through `/v1/end`.
4. **Docs promise what is not built:** 11 tools, `agentd` push, stub status.
5. **MCP schemas carry no field descriptions or patterns;** rules (ticket
   `TIN-<n>|none`, ULIDs, id shape `harness:host:pid:session`, 16 KiB body,
   inbox limits) surface only as errors.
6. **Errors are not actionable:** `invalid agent id`, `unknown envelope
   field` without the field, CLI drops the JSON error body, every error but
   a `msg_id` conflict (409) is HTTP 400.
7. **CLI conventions:** no `--version`, help exits 2, `agentd` advertised
   but exits 3, `whoami` registers, one missing variable reported per run.
8. **Client disagreement:** `swb` rejects a trailing `/` and `https`; lab's Pi
   client accepts both.
9. **No `/healthz`;** `/v1/notify` not implemented; `/v1/end` has no MCP twin.
10. **Inbox long-poll prunes the store every 250 ms.**

## Target doc set

| Doc | Holds | Action |
| --- | --- | --- |
| `README.md` | What, 3-line status, quickstart, settings link | Rewrite Status and tool count (this PR); add quickstart next |
| `docs/PRODUCT.md` | Users, stories, install, friction | New (this PR) |
| `CONTRIBUTING.md` | Fork convention, signed commits, landing, lock rule | New; absorbs the convention now repeated in AGENTS.md, ADR-0001, README |
| `AGENTS.md` | Read order, source of truth, build placement, current R-N11 | Slim; point invariants at ADR Rulings |
| ADR-0001, ADR-0002 | Decision and Rulings tables | Cut snapshots, Deltas and inline supersessions (needs decision 1) |
| `docs/operations/PRODUCTIONIZATION.md` | Release lock, rollout gates | Drop stale step 4 |
| `spec/README.md` | Formal spec | Keep; move its TODO block to Linear |
| `docs/agent-notes/` | Live-gate notes only | Retire superseded notes under R35 |

Projected prose: about 275 KB to about 145 KB with decision 1, about 215 KB
without it.

## Open decisions

Recommended default first.

1. **ADR supersession text.** *Default: delete* superseded wording and Deltas
   tables in signed commits naming the replacement (R35); the Rulings table
   stays normative. Alternative: keep inline notes, cap reduction at ~60 KB.
2. **Identity producer for Claude/Codex hooks.** *Default: a wrapper
   launcher* that exports `SWB_HOST`, `SWB_SESSION_PID`, `SWB_PROC_START` and
   `SWB_BROKER_URL` from its own pid. Alternatives: a broker lease keyed on
   hook-stdin `session_id` alone; wait for a harness-provided variable.
3. **One enrollment switch.** *Default: yes,* one lab
   `tinyland.switchboard.enable` option plus `swb doctor`, gated on
   decision 2; never enable `switchboardHooks` before it.
4. **CLI verbs `send`, `ack`, `peers`, `doctor`.** *Default: ship* in the next
   approved release alongside the R-C262 clock seam (protected inputs).
5. **Notice command name.** *Default:* the MCP tool `mcp__agents__inbox` with
   `me=<agent_id>`, and `swb inbox` for bash seats; retire `ag`.
6. **`peers` exposure.** *Default:* live/idle only, `limit`, no
   `proc_start`; `/v1/end` checks a credential never returned to others.
7. **R-C262 release ID.** *Default:* a dated TIN-4655 comment assigns a new
   SWB-R number; SWB-R54 stays state custody.
