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

**Do not infer the product from the folder name.** Take the product definition from
`.ai/context/project-brief.md` (now filled in) and `README.md`. If a task requires knowing
something neither states, ask the human rather than guessing.

## Read these first

- **`MEMORY.md`** — shared project memory: current state, decisions in force, and known
  gotchas. Read it before making non-trivial changes, and update it in the same commit that
  makes one of its facts untrue.
- **`LEARN.md`** — append-only record of corrections from user feedback and PR comments. Add an
  `L-NNN` entry whenever feedback is general enough to matter again; never rewrite or delete
  past entries, supersede them.

Both are committed so every contributor, human or AI, starts from the same picture. Local agent
caches such as `.memsearch/` are per-machine, gitignored, and are not a substitute for either.

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

`docs/05-adr/001-use-react-and-typescript.md` is **Accepted**: Next.js 14+ App Router,
TypeScript, React Server Components by default. Treat this as binding unless a new ADR
supersedes it — note that the ADR index table in `docs/05-adr/README.md` has not yet been
updated to list it.
