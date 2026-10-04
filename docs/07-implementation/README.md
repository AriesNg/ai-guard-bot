# 07 — Implementation

**Status**: ⬜ Not started — **blocked on H-1 (Phase 3 approval)**

## Purpose
Build the product iteratively, sprint by sprint. Each sprint produces working, tested code that is
**independently useful** — this is a side project with intermittent time ([ADR-011](../05-adr/011-v1-scope-envelope.md)),
so a sprint that only makes sense once the next three are done is a sprint that may never finish.

## How This Works

1. [`implementation-plan.md`](implementation-plan.md) holds the whole work breakdown (S-0 … S-7 plus
   pre-release) and the fourteen human quality gates H-1 … H-14.
2. For each sprint:
   - Write `sprint-NNN-plan.md` from the sprint's row in that plan, expanding each task to the four
     required fields below
   - Build features + tests, together, never deferred
   - Run the plan's **demo script** with the human; clear the sprint's **human gate**
   - Write `sprint-NNN-review.md`
   - Update the backlog and this file's sprint log

## Testability contract

**Every task in every sprint must be testable at the end of the sprint it is in.** A task may not
enter a sprint unless it carries all four of:

| Field | Requirement |
|---|---|
| **Deliverable** | The artefact that exists afterwards — a module, a command, a CI stage |
| **Acceptance** | An observable, **falsifiable** condition. "Implemented" is not one; a statement that can come out false is |
| **Verified by** | The exact command a reviewer runs, plus the test file that asserts it in CI |
| **Traces to** | The design section it implements |

And one hard rule on top of them:

> **No task's verification may depend on an artefact from a later sprint.**

When a task cannot meet that, it **moves** to the sprint where its verification becomes possible.
Weakening the acceptance condition to fit the sprint is never the correct response. A condition that
genuinely cannot be automated becomes a named human gate in
[`implementation-plan.md`](implementation-plan.md) §4, with a stated reason CI cannot answer it — not
a looser test.

A sprint is complete when every task's acceptance condition passes **on both macOS and Linux** and
the sprint's human gate is signed. See [`sprint-001-plan.md`](sprint-001-plan.md) §3 for the worked
application of this contract, and §6 there for what a demo script looks like.

## Current Sprint

**Sprint**: 1 — S-0 Foundations ([`sprint-001-plan.md`](sprint-001-plan.md))
**Status**: ⬜ Planned — **not started; blocked on H-1**
**Goal**: The decision substrate — canonical action model, normalisation, policy schema and total
validation, precedence resolver, closed error catalogue — shipped behind one runnable command,
`guard policy validate`, with a blocking two-OS CI pipeline around it.
**Exit gate**: **H-2** — a human writes five real rules without reading the schema.
**Blockers**:
- **H-1** — Phase 3 approval. Nothing starts before it.
- **§7 of the sprint plan** — `validate --explain` is a proposed CLI-surface addition awaiting a
  decision at H-1.

~~**Q-09** (single-language Rust?) — carried as assumption **A-4**~~ **Resolved 2026-10-02** —
single-language Rust, confirmed ([ADR-013](../05-adr/013-model-and-language-resolution.md)). This
line was written before that ADR merged; left struck through rather than deleted so the sprint log
shows what changed underneath it.

*Not blocking*: **Q-01** (which local model). Nothing in Sprint 1 touches the model runtime.

## Sprint Log

| Sprint | Goal | Status | Gate | Dates |
|--------|------|--------|------|-------|
| 1 | S-0 Foundations — decision substrate + `guard policy validate` | ⬜ Planned | H-2 | — |
| 2 | S-1 Decide, locally — pipeline, daemon, `policy simulate` | ⬜ Not planned | H-3 | — |
| 3 | S-2 Evidence — audit chain, query, `guard log` | ⬜ Not planned | H-4 | — |
| 4 | S-3 First interception — `CliAdapter`, Claude Code adapter, install/uninstall | ⬜ Not planned | H-5, H-6 | — |
| 5 | S-4 Confinement — Seatbelt + Landlock, boundary honesty | ⬜ Not planned | H-7 | — |
| 6 | S-5 Second integration — MCP proxy, content screening | ⬜ Not planned | H-8 | — |
| 7 | S-6 Intent rules — model runtime port, accuracy gate | ⬜ Not planned | H-9, H-10 | — |
| 8 | S-7 Surfaces — TUI, a11y gate, metrics | ⬜ Not planned | H-11 | — |
| — | Pre-release — shipped default policy, clean-machine install | ⬜ Not planned | H-12, H-13, H-14 | — |

Sprint 2 onward are **not planned in detail yet, deliberately**: each is planned at its own start,
when the preceding sprint's findings are known. The scope of each is fixed in
[`implementation-plan.md`](implementation-plan.md) §2; only the task-level acceptance criteria wait.

## Backlog

Carried out of Sprint 1, per [`sprint-001-plan.md`](sprint-001-plan.md) §9 — nothing here is a `TODO`
in code:

| # | Item | Sprint |
|---|---|---|
| B-1 | Audit-store benchmark spike | S-1 |
| B-2 | The remaining fifteen `GuardError` codes becoming constructible | each owning sprint |
| B-3 | Policy fixtures for `mcp.*` server-identity matching | S-5 |
| B-4 | Performance gate as a CI stage | S-1 |
| B-5 | The default policy `guard policy init` writes | pre-release |
| B-6 | `TraceBuilder`, `ProvenanceStamp`, the trace inside the audit record | S-1, S-2 |
| B-7 | `guard explain` / `guard replay` and the determinism gate | S-2 |

---
**Prerequisite**: Phases 1–6 approved, at least for the scope of the sprint being started. For Sprint 1
that is **H-1 — Phase 3 approval** ([`implementation-plan.md`](implementation-plan.md) §4).
