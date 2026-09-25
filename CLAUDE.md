@AGENTS.md

# Claude Code overlay

`AGENTS.md` is the primary contract for this repo. This file is a thin overlay
and never outranks it.

- Prefer `just` recipes over ad hoc commands.
- From neo, never run `just check`, `just build` or any `bazel`/`cargo` build
  locally. Use `just remote-check`, or rely on the merge queue.
- Push only to `origin` (your fork). `upstream` has push disabled on purpose;
  never re-enable it to land a change.
- Working notes go to `docs/agent-notes/`, never to a scratchpad or `/tmp`.
