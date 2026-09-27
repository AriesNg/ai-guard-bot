# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

An **empty project scaffold**, not an application. `src/`, `tests/`, and `infrastructure/`
contain only `.gitkeep` files; `package.json` has an empty `dependencies` and every script
(`dev`, `build`, `start`, `lint`, `test`, `test:e2e`, `typecheck`) is an empty string. There
is no lockfile and no framework installed. It **is** a git repository, with `origin` at
`github.com:AriesNg/ai-guard-bot`.

The substance of the repo is the **process contract** in `.ai/` and the **phase-gated document
tree** in `docs/`. Read `.ai/instructions.md`, `.ai/workflow.md`, and `.ai/rules/*.md` before
doing anything — they define the operating mode that the rest of this file summarizes.

The product is defined in `.ai/context/project-brief.md` (filled in) and summarized in
`README.md`: a local, vendor-agnostic guardrail layer that intercepts an AI CLI agent's actions,
evaluates them against user-defined rules plus a small local model, and allows / masks / denies
them with a machine-readable error code. Six open questions at the end of the brief still block
Discovery — do not resolve them by assumption.

## Commands

There are none yet. The script names in `package.json` are placeholders reserved for the
eventual toolchain. Sprint 1 (`docs/07-implementation/sprint-001-plan.md`) is what populates
them: initialize Next.js + TypeScript + ESLint + Prettier, then wire `lint → test → build`.
Until that sprint runs, never claim a build/test command exists or invent one — fill in
`package.json` as part of the scaffold story, then document the real commands here.

## Work tracking — GitHub Issues

**User stories, tasks, and defects are GitHub issues, not markdown.** The contract is
`docs/07-implementation/issue-tracking.md`; read it before filing or picking up work.

- Split of responsibility: `docs/` holds requirements, designs, and decisions (approved,
  superseded, permanent). Issues hold *work* (state, assignee, PR). Never duplicate a requirement
  into an issue body — the story links to its `FR-nn` id and `requirements.md` links back to the
  issue.
- Three forms in `.github/ISSUE_TEMPLATE/`: `user-story.yml` (demoable to a person),
  `task.yml` (scaffolding, CI, refactor, spike), `defect.yml`. Blank issues are disabled.
- Labels: exactly one `type:*`, exactly one of `P0`/`P1`/`P2`, at least one `area:*`; `S1`–`S4` on
  defects; optional `status:*` and `phase:*`. `./.github/bootstrap-labels.sh` creates them all and
  is idempotent — it is the single source of the taxonomy, so change it rather than hand-editing
  labels in the web UI.
- Sprints are **milestones**; `docs/07-implementation/sprint-NNN-plan.md` is a snapshot listing
  issue numbers, not a parallel work queue.
- Branch `<type>/<issue-number>-<slug>`; one PR closes one issue via `Closes #N`; a story closes
  only when every acceptance criterion is ticked with verification recorded in the PR.
- Filing an issue is capture, not permission — the phase gate below still decides what may be
  worked on. An issue needing an architectural decision gets `status:needs-adr` and waits for a
  merged ADR.
- A security issue (sandbox escape, policy bypass, leaked data that should have been masked) goes
  to a private advisory, never a public issue.
- `gh` is installed and authenticated as `AriesNg`. Do not file, close, label, or comment on
  issues without being asked — propose the issue text instead.

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
- `.github/` — issue forms, PR template, and label script; edit freely, but keep
  `docs/07-implementation/issue-tracking.md` in step with any change to the taxonomy.

## Standing constraints on generated work

From `.ai/instructions.md` and `.ai/rules/general.md`, enforced across every phase:

- No `TODO`/`FIXME` comments in code — either implement it or file it as a GitHub issue.
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
