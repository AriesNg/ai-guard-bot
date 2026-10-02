# ADR-002: Rust for the enforcement core, TypeScript for the UI

## Status
Proposed — **amended 2026-10-02: single-language Rust, confirmed**

Q-06 answered with a **TUI**, not a web UI ([ADR-011](011-v1-scope-envelope.md)), which removed the
only consumer of the TypeScript half of this split. **Q-09 is now answered** — the product owner
confirmed single-language Rust on 2026-10-02 ([ADR-013](013-model-and-language-resolution.md)).
The title is now a misnomer kept for history: there is no TypeScript layer. The TUI is built
in-process in Rust (`ratatui`-class) and shipped in the same static binary; the schema-codegen
build step this ADR introduced is deleted from scope, not conditionally retained.

## Context

ADR-001 fixed Next.js + TypeScript + React Server Components for this project. It was written for
a web application's UI, and is now superseded by
[ADR-010](010-supersede-adr-001-no-web-server-ui.md) — but either way it never addressed the layer
this ADR is about. This product's centre of gravity is not a UI: it is a
long-lived local process that must decide, before every action an AI CLI takes, whether that
action may proceed.

The forces on that process are different in kind from the forces on a web UI:

- **Per-action overhead budget.** `../01-discovery/requirements.md` sets P95 < 10 ms of added
  overhead on an allowed, unmodified action, and P95 < 20 ms for a deterministic decision. The
  adapter is invoked by the host CLI per action, so its *process start* is inside that budget.
- **Cold start** < 2 s excluding model warm-up.
- **OS-level confinement.** FR-17 requires filesystem, network, and process allowlists. On every
  target platform this means calling an OS primitive directly (Seatbelt on macOS, Landlock and
  seccomp on Linux) — see ADR-008.
- **Memory floor.** The engine must fit in < 250 MB while leaving the local model room under a
  < 5 GB total budget on a 16 GB laptop.
- **One-command install** (S-09, < 5 minutes on a clean machine).
- `.ai/context/project-brief.md` explicitly records this as an open question rather than
  something to inherit from the scaffold's UI ADR.

## Decision

Split the stack at the wire contract:

- **Enforcement core, the per-CLI adapters, the CLI, and the TUI: Rust.** Distributed as a single
  static binary per platform. One workspace, one type set.
- ~~**UI surface (audit viewer), if Q-06 puts one in v1: TypeScript.**~~ **Superseded:** Q-06
  answered with a TUI and Q-09 confirmed single-language Rust
  ([ADR-013](013-model-and-language-resolution.md)). The audit viewer is in-process, in the core's
  language. No separate UI language, no second runtime, no generated client types.
- **The boundary is JSON-RPC over a Unix domain socket** (ADR-003), with the JSON schemas in
  Phase 3's `api-design.md` as the single source of truth. With no second language, these schemas
  are documentation and wire validation, not a codegen source — the Rust `struct`/`enum` types on
  both sides of the socket are hand-written against them, once, not generated.

This ADR decides only the enforcement layer, which no earlier ADR addressed. The UI half of the
split is now governed by [ADR-010](010-supersede-adr-001-no-web-server-ui.md).

## Rationale

- **Process start is the deciding constraint.** A Node process costs roughly 40–80 ms to start
  before executing a line of our code. The adapter budget is 10 ms. No amount of optimisation
  inside a Node adapter recovers that, so a native adapter is required regardless of what the
  daemon is written in — and once the adapter is native, writing the daemon in a second language
  buys a language boundary and no benefit.
- **Confinement wants direct syscall access.** ADR-008's candidate primitives are C APIs. Rust
  calls them without a native-module build step; Node would need one, which reintroduces the
  toolchain complexity that Rust supplies outright.
- **A single static binary is the cheapest possible install** (S-09). No runtime to provision, no
  version skew with a system interpreter.
- **No GC pause risk against a P99.** The deterministic P99 < 50 ms budget is tight enough that a
  collector pause is a real failure mode, not a theoretical one.
- **Memory headroom.** Every MB the engine does not use is a MB available to the model, which is
  the component actually constrained on a 16 GB machine.
- **The split is where the risk is lowest.** The UI is not in the enforcement path
  (`../04-solution-design/component-design.md` §3), so the two languages never share a hot path,
  and the contract between them is a schema that is already needed for the CLI and adapters.

Trade-offs accepted, stated plainly:

- **Slower to build.** Rust will cost more to write than TypeScript, particularly early.
- **Two languages, two toolchains** in CI, and a schema-generation step that must not rot.
- **Smaller overlap with the ADR-001 skill set.** This is the real cost of this decision and the
  main argument against it.

## Consequences

**Easier**

- Meeting the per-action and cold-start budgets at all.
- Shipping one artefact per platform; `guard install` has nothing to provision but the model.
- Calling OS confinement APIs, and therefore making honest boundary claims (FR-18).

**Harder**

- Initial velocity. Sprint 1's scaffold story becomes two scaffolds.
- Keeping the wire contract honest: a schema change must regenerate both sides or CI fails.
- Hiring and review, if the team is TypeScript-first.

**The team must now**

1. Add a Rust workspace (`core/`, `adapters/`, `cli/`, `tui/`), with `cargo` wired into the
   `lint → test → build` pipeline that Sprint 1 creates. There is no Next.js app to sit alongside:
   ADR-001 is superseded ([ADR-010](010-supersede-adr-001-no-web-server-ui.md)).
2. ~~Make schema-driven codegen a build step~~ **Deleted from scope.** Single-language Rust means
   there is no second side to keep in sync.
3. Set up cross-compilation for **macOS and Linux** (Q-02, answered 2026-10-02). No Windows target.
4. ~~Resolve Q-09~~ **Done.** The product owner confirmed single-language Rust on 2026-10-02 — see
   [ADR-013](013-model-and-language-resolution.md).

## Rejected Alternatives

- **Node + TypeScript for everything.** One language, shared types with the UI, fastest to build,
  best fit for the existing skill set. Rejected on measurement, not taste: ~40–80 ms of process
  start against a 10 ms adapter budget is a 4–8× overrun before our code runs, and a per-action
  overhead the user can feel is precisely the failure mode (R-03) that makes developers disable
  guardrails — the problem this product exists to solve. Native modules for confinement would also
  erase the "simpler toolchain" advantage that is the main reason to choose it.
- **Go.** Fast start, trivial static binaries, materially easier than Rust, and a genuine
  contender. Rejected on two counts: GC pauses are an unnecessary risk against a P99 < 50 ms
  budget on a machine also running an IDE and a local model; and access to Landlock/seccomp/Seatbelt
  goes through cgo, which costs most of Go's simplicity advantage exactly where the hardest code
  lives.
- **C or C++.** Maximum control, direct syscall access. Rejected: a security product whose entire
  job is parsing untrusted input (commands, paths, file content, model output) should not be
  written in a language without memory safety. The decision is not close.
- **Python.** Rejected outright: start-up cost, packaging, and the GIL against a concurrency
  requirement of 4 sessions.
- **Rust everywhere, including the UI (WASM or a native GUI), at the time this ADR was first
  written.** Rejected then because a *web* UI's latency budget didn't need it and it would have
  narrowed the hiring pool. Overtaken by events: Q-06 answered with a TUI rather than a web UI, so
  the GUI framing no longer applies, and Q-09 confirmed single-language Rust
  ([ADR-013](013-model-and-language-resolution.md)) — this alternative is what the decision became,
  not what was rejected.
- **A thin native adapter shelling into a Node daemon.** Considered as the compromise that keeps
  most logic in TypeScript. Rejected: it keeps the language boundary *and* the Node memory and
  start-up costs, adds a hop, and puts the policy engine — the part most needing to be fast and
  memory-frugal — on the wrong side.

---
**ADR Number**: 002
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-013](013-model-and-language-resolution.md) (Q-09 confirmed: single-language
Rust) · [ADR-011](011-v1-scope-envelope.md) (Q-06's TUI answer raised Q-09) ·
[ADR-010](010-supersede-adr-001-no-web-server-ui.md) (governs the UI half; supersedes ADR-001) ·
[ADR-003](003-local-daemon-over-unix-socket.md) ·
[ADR-008](008-sandbox-confinement-primitive.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) §0
