# Formal spec (R-C229)

Ruling R-C229 sets the formal stack: Dhall for typed records, and Haskell
QuickCheck over a pure model of the broker. Ruling R-C261 adds LiquidHaskell
refinement types on the model's core invariants. The operator's guidance, verbatim:
"we already use dhall with flake extensively in our lab; we also like
quickcheck, which allows for simple, parsimonious properties instead of
extensive architecture boundary checks."

Nothing here is a Bazel input or a release-protected input
(`scripts/release-check.py` `SOURCE_INPUTS_V1`), so this tree can change
without touching the SWB-R53 release lock.

## Layout

| Path | What it is |
|---|---|
| `dhall/ApprovedRelease.dhall` | Type of `docs/releases/approved-broker.json` (`swb.approved-release.v1`). |
| `dhall/approved-broker.dhall` | The record itself. Its rendering must equal the committed JSON. |
| `dhall/RustfsBucketIam.dhall` | Type of blahaj `config/rustfs-iam/owners.json` (`tinyland.blahaj.rustfs-bucket-iam.v1`), which carries the TIN-5105 `agent-switchboard-tofu-state` owner row. |
| `dhall/Broker.dhall` | Ruled broker constants (SWB-R09, R14, R16) and the `Unruled` SWB-R16 cases. |
| `dhall/generated/broker-constants.json` | Rendering of `Broker.dhall`, committed. The Haskell model reads only this file. |
| `fixtures/blahaj-rustfs-iam-owners.json` | Snapshot of blahaj `owners.json` at commit `a54ff72480657fbecae8960946714081df2adb0e`. Check the live file with `just spec-owners <path>`. |
| `check-dhall.sh` | The Dhall check. `just spec-dhall` and the flake check `spec-dhall` both run it. |
| `haskell/` | Cabal package `swb-spec`: the model, the properties and the live adapter. |
| `haskell/src/Swb/Invariants.hs` | The model's core definitions with LiquidHaskell refinement types (R-C261). Imports only base. |

## Dhall check

`just spec-dhall` runs on any seat, neo included. It uses `nix shell` to
substitute dhall, dhall-json and jq from the locked nixpkgs and compiles
nothing. It does four things:

1. It type-checks every file under `dhall/`.
2. It renders `approved-broker.dhall` and requires the output to equal
   `docs/releases/approved-broker.json` after `jq -S`. Edit the two together.
   `release-check.py` still reads the JSON and still decides what the values
   mean.
3. It renders `Broker.dhall` and requires the output to equal
   `generated/broker-constants.json`.
4. It reads the owners snapshot into `RustfsBucketIam.dhall` with strict
   records, so an unknown or mistyped field fails. It then renders the result
   back and requires it to equal the input.

## QuickCheck properties

The model (`haskell/src/Swb/Model.hs`) follows `crates/swb-store` for
sessions, threads and messages. It follows the SWB-R16 text in ADR-0001 for
claims, which Rust does not implement yet. Time is an abstract clock in
seconds.

Each property replays a trace of (operation, result) pairs and judges only the
results. So the same five checks judge the model and, through the live
adapter, the real broker.

| Property | Ruling | Claim |
|---|---|---|
| `leaseLifecycle` | SWB-R09, `peers()` | Each observed state is the band implied by the agent's own last refresh or end. Between observations with no own activity, a state only decays: live, then idle, then gone. Ended stays ended. |
| `threadSeqDense` | SWB-R14 | Within each thread, seq runs 1, 2, 3, and so on, and keeps doing so after a prune. |
| `atLeastOnceUntilAck` | SWB-R09 | Inbox returns only pending messages, and `delivery_count` goes up by one each time. A short page holds every pending message, so a message that is never acked keeps coming back. Ack succeeds exactly for my own messages that are unexpired or already acked. |
| `exclusiveRefusal` | SWB-R16 | A non-exclusive claim is always recorded. A second exclusive claim returns `held_by` while another holder's unexpired exclusive claim exists. Otherwise the claim is recorded. |
| `noOrphanAfterExpiry` | SWB-R16 | The claim list shows exactly the unexpired recorded claims. A claim is orphaned while its holder is gone, and not while the holder is live or idle. |

**Unruled cases are never asserted.** The model answers each of these with
`Unruled` and every property skips it:

- SWB-R16 "Not yet ruled": an exclusive request while non-exclusive claims
  exist.
- SWB-R16 "Not yet ruled": whether a non-exclusive claim lists an exclusive
  holder in `overlaps[]`. The model has no overlaps.
- Not addressed by the SWB-R16 text: a second exclusive claim from the current
  exclusive holder.

The properties also make no assertion about a claim whose holder has ended.
These cases are the questions for the P2 claims ruling packet.

**Modeling assumptions to confirm in P2.** These are not rulings:

- A claim lease ends at its expiry.
- A claim refreshes the claimant's session lease, as every other broker
  operation does.

## LiquidHaskell refinement types

R-C261 keeps the QuickCheck properties and adds refinement types on three
core invariants. The definitions live in `haskell/src/Swb/Invariants.hs`, and
`Swb.Model` runs them, so the checked code is the code the properties
exercise.

| Invariant | Proved by | Claim |
|---|---|---|
| Per-thread seq | `appendSeq`, type `SeqLog` | A thread's seq log is strictly decreasing newest first, and its newest seq equals its length. Appending always adds a seq above every earlier one on that thread, so seqs run 1, 2, 3, and so on. The log survives prune, like `thread_counters`. |
| Lease transitions | `decayLemma`, `endedLemma`, `reviveLemma` over `classifyAge` | With no activity of its own, a lease only decays: live, then idle, then gone. Ended stays ended. End always gives ended, and a refresh always gives live. Those are the only edges. |
| Claim holders | `activeClaims`, `viewClaim` | A listed claim is unexpired, and it is marked orphaned exactly when its holder is gone. So a listed claim's holder is not gone, or the claim is marked for release. A claim refreshes its holder, so the holder is live when the claim is recorded. The model has no explicit release, so this is as far as the model goes. |

Not proved: that `Swb.Model` threads its state through these functions
correctly. The model module is not LiquidHaskell-checked, because it reads
the constants through aeson. The QuickCheck trace properties cover it.

### Running it

Run these on build hosts only (sting or honey), never on neo. From neo, use
`just remote-spec-check`.

- `just spec-quickcheck` builds the package. The build runs the model
  properties, 1000 cases each.
- `just spec-liquid` checks `Swb.Invariants` with the LiquidHaskell GHC
  plugin and z3 from the locked nixpkgs. Any unproved refinement fails the
  compile.
- `just spec-check` runs the Dhall check, the properties and LiquidHaskell.
- The flake checks are `spec-dhall`, `spec-quickcheck` and `spec-liquid`.
- In CI, `spec-dhall`, `spec-quickcheck` and `spec-liquid` are jobs that
  `ci-ok` requires (R-C255, R-C261).
- In `nix develop .#spec`, run `liquid-ghc -fplugin=LiquidHaskell -isrc
  src/Swb/Invariants.hs` from `haskell/` to iterate.

### Live adapter

`haskell/src/Swb/Live.hs` sends the same operations to a running broker's
REST API. It never starts, stops or signals a process (R-N11), and it refuses
any URL that is not loopback. Each case uses a fresh random host tag in its
agent ids, so cases cannot see each other.

On a build host, start a disposable broker that bounds itself with `timeout`,
then point the suite at it:

```sh
d="$(mktemp -d "$HOME/scratch/swb-spec.XXXXXX")"
timeout 600 env SWB_DB_PATH="$d/swb.sqlite3" SWB_LISTEN=127.0.0.1:18080 \
  SWB_METRICS_LISTEN=127.0.0.1:19090 bazel-bin/crates/swb/swb serve &
just spec-live http://127.0.0.1:18080
```

**Live coverage today.** The broker has no clock seam and no claims, so the
live mode generates no `Tick` and no claim operations. The live run fully
checks `threadSeqDense` and `atLeastOnceUntilAck`, minus expiry. It checks
`leaseLifecycle` only for the live, ended and revive transitions. The claim
properties are vacuous there.

**TODO.** Close the gap. This is proposed ticket text under TIN-4655 and is
not filed:

> Give `swb-store` a clock seam: a `Clock` trait, with SQLite `unixepoch()`
> as the default and a test clock behind a feature or test-only constructor.
> Then add a `spec/driver` harness that reads JSON operations on stdin and
> writes results on stdout, exiting at EOF so it needs no signal.
> `Swb.Live` can then drive `Tick` and the expiry and idle/gone paths with
> the same five properties.
>
> Both changes edit `crates/`, which are release-protected inputs (SWB-R53).
> So they need a new approved release, or a ruling that a test-only crate is
> outside `SOURCE_INPUTS_V1`. Claims (SWB-R16) join the live run when P2
> implements them.
