# ADR-002: Rust for the enforcement core, TypeScript for the UI

## Status
Proposed

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

- **Enforcement core and the per-CLI adapters: Rust.** Distributed as a single static binary per
  platform.
- **UI surface (audit viewer), if Q-06 puts one in v1: TypeScript.** The framework is deliberately
  not decided here — see [ADR-010](010-supersede-adr-001-no-web-server-ui.md), which forbids a
  server runtime or listener and defers the stack choice. What this ADR fixes is only that the UI
  layer is **not** Rust.
- **The boundary is JSON-RPC over a Unix domain socket** (ADR-003), with the JSON schemas in
  Phase 3's `api-design.md` as the single source of truth. TypeScript types for the UI are
  **generated** from those schemas, not hand-maintained in parallel.

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

1. Add a Rust workspace (`core/`, `adapters/`) alongside the Next.js app, with `cargo` wired into
   the `lint → test → build` pipeline that Sprint 1 creates.
2. Make schema-driven codegen a build step with a CI check that regeneration is a no-op.
3. Set up cross-compilation for the platforms Q-02 selects.
4. Revisit this ADR if Q-06 answers "no UI in v1" — the product is then single-language (Rust) and
   the TypeScript half of this decision is dormant until a UI exists.

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
- **Rust everywhere, including the UI (WASM or a native GUI).** Rejected: the UI has no latency
  budget and is out of the enforcement path, so it buys nothing, and it would narrow the hiring and
  contribution pool for the layer where that matters least.
- **A thin native adapter shelling into a Node daemon.** Considered as the compromise that keeps
  most logic in TypeScript. Rejected: it keeps the language boundary *and* the Node memory and
  start-up costs, adds a hop, and puts the policy engine — the part most needing to be fast and
  memory-frugal — on the wrong side.

---
**ADR Number**: 002
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-010](010-supersede-adr-001-no-web-server-ui.md) (governs the UI half; supersedes
ADR-001) ·
[ADR-003](003-local-daemon-over-unix-socket.md) ·
[ADR-008](008-sandbox-confinement-primitive.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) §0
