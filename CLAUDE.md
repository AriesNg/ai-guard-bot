# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

An **empty project scaffold**, not an application. `src/`, `tests/`, and `infrastructure/`
contain only `.gitkeep` files; `package.json` has an empty `dependencies` and every script
(`dev`, `build`, `start`, `lint`, `test`, `test:e2e`, `typecheck`) is an empty string. There
is no lockfile, no framework installed, and it is not yet a git repository.

The substance of the repo is the **process contract** in `.ai/` and the **phase-gated document
tree** in `docs/`. Read `.ai/instructions.md`, `.ai/workflow.md`, and `.ai/rules/*.md` before
doing anything — they define the operating mode that the rest of this file summarizes.

`.ai/context/project-brief.md` is **filled in** and is the authoritative description of the
product: a local, vendor-agnostic guardrail layer between an AI CLI agent and the machine, which
intercepts every action, evaluates it against high-level developer-authored rules using
deterministic matchers plus a locally-run small model, and allows / masks / denies it before
execution, logging every decision. Read the brief rather than inferring from the folder name.

Six open questions at the end of the brief are still unanswered, four of which block approval:
Q-02 (target platforms), Q-03 (threat model — an agent that errs vs one actively trying to
escape), Q-04 (first target CLI), Q-06 (is a UI in scope for v1). Do not invent answers to these;
where work depends on one, state the assumption explicitly.

## Commands

There are none yet. The script names in `package.json` are placeholders reserved for the
eventual toolchain. Sprint 1 (`docs/07-implementation/sprint-001-plan.md`) is what populates
them: initialize Next.js + TypeScript + ESLint + Prettier, then wire `lint → test → build`.
Until that sprint runs, never claim a build/test command exists or invent one — fill in
`package.json` as part of the scaffold story, then document the real commands here.

## The phase gate

Work proceeds through seven numbered phases, each owning a folder under `docs/`:

| # | Phase | Folder |
|---|-------|--------|
| 1 | Discovery | `docs/01-discovery/` |
| 2 | UX Design | `docs/02-ux-design/` |
| 3 | System Design | `docs/03-system-design/` |
| 4 | Solution Design | `docs/04-solution-design/` |
| 5 | ADRs | `docs/05-adr/` |
| 6 | Infrastructure | `docs/06-infrastructure/` |
| 7 | Implementation | `docs/07-implementation/` |

Rules that matter in practice:

- **Never skip ahead.** A phase's `README.md` carries a `**Status**` line and a `Prerequisite`
  line naming the phase that must be approved first. Check both before generating into a folder.
- Each phase README also lists the exact **filenames** it expects (e.g. `requirements.md`,
  `architecture.md`, `data-model.md`). Use those names rather than choosing your own.
- `.ai/templates/` holds the template for each phase's main document; ADRs must follow
  `.ai/templates/adr.md` and record **Rejected Alternatives**, not just the decision.
- `.ai/rules/review-criteria.md` is the per-phase exit checklist. Run it before proposing that
  a phase is complete.
- Every generated document opens with `**Status**: Draft | Review | Approved | Superseded`.
- The model is a spiral, not a waterfall: later learning may reopen an earlier phase. When it
  does, supersede the affected document rather than silently editing the decision away.

## Write permissions by directory

This is the repo's own rule (`.ai/workflow.md`) and it overrides the usual default of editing
freely:

- `.ai/` — **human-owned. Never write here.** Suggest changes in chat instead.
- `docs/` — generate drafts; the human approves them.
- `src/` — code, written by Claude.
- `infrastructure/` — generate; the human tests in non-prod first.
- `tests/` — written alongside the implementation, never deferred.

## Standing constraints on generated work

From `.ai/instructions.md` and `.ai/rules/general.md`, enforced across every phase:

- No `TODO`/`FIXME` comments in code — either implement it or add it to the sprint doc.
- Generate complete, runnable code, never skeletons or pseudo-code.
- Architecture, flows, and data models are expressed as **Mermaid** diagrams inside the docs.
- Non-functional requirements must be quantified ("P95 < 200ms", not "fast").
- Security, observability, and accessibility (WCAG 2.1 AA) are designed in from phase 1, not
  retrofitted.
- Propose before coding anything architectural; offer 2–3 options with a recommendation when
  uncertain rather than guessing.

## Existing decisions

`docs/05-adr/001-use-react-and-typescript.md` (Next.js 14+ App Router, RSC) was inherited from
the scaffold and is **superseded by ADR-010**. **It binds nothing** — do not treat Next.js, the
App Router, or RSC as decided for this project, and do not cite ADR-001 as a constraint.

`docs/05-adr/002` … `010` are **Proposed**, awaiting the human's review: Rust enforcement core
with a TypeScript UI (002), a local daemon over a Unix socket with **no TCP listener in any
configuration** (003), layered policy where deterministic rules decide before intent rules (004),
a pluggable local model runtime (005), a hash-chained single-writer audit log (006), per-CLI
adapters with a coverage matrix (007), OS-native confinement with no absolute isolation claim
(008), fail-closed as a default value rather than a branch (009), and no web-server UI (010).
Read `docs/05-adr/README.md` for the index and the open questions each one is blocked on.

Treat a Proposed ADR as the current design intent, not as settled: Phase 3 accepts or supersedes
them. Every document under `docs/01-discovery/` and `docs/04-solution-design/` is **Draft**, and
Phase 4 was drafted ahead of its Phase 3 prerequisite at the product owner's explicit request.
