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

There are none yet, and the toolchain is **not** the one `package.json` implies. The enforcement
core is proposed as Rust (ADR-002), the UI is a terminal UI, and Q-09 asks whether a Node runtime
ships at all — so `package.json`'s empty npm scripts are scaffold residue, not a reserved plan.

`docs/07-implementation/sprint-001-plan.md` is also scaffold boilerplate: it describes auth, a
landing page, and a dashboard shell, which belong to no part of this product. **It binds nothing.**
Phase 7's real Sprint 1 is written after Phase 3 is approved, and ADR-011 names what it must contain
(the `CliAdapter` contract, both adapters, the two-OS CI matrix, the accuracy gate, and the shipped
default policy).

Until that sprint is written and run, never claim a build/test command exists or invent one.

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

## Worktrees carry an id

Every worktree exists to land one identified work item, so that a branch, its commits and its PR
are all traceable back to the document, decision or task that justified them. Name it
`.claude/worktrees/<id>-<slug>` — git then creates the branch `worktree-<id>-<slug>`.

The id is lowercase and comes from a vocabulary that already exists in the repo:

| Id form | What it names | Where it is defined |
|---|---|---|
| `adr-0NN` | an ADR | `docs/05-adr/0NN-*.md`, indexed in `docs/05-adr/README.md` |
| `q-NN` | an open question | `.ai/context/project-brief.md`, tracked per ADR in `docs/05-adr/README.md` |
| `fr-NN`, `nfr-NN`, `r-NN`, `s-NN` | a requirement, non-functional requirement, risk or story | `docs/01-discovery/requirements.md` |
| `sprint-N` | a sprint (S-0 … S-7, or `pre-release`) | `docs/07-implementation/implementation-plan.md` |
| `phase-N` | a whole phase's document set | `docs/0N-*/README.md` |
| `meta` | the process itself — `CLAUDE.md`, `.claude/`, tooling; no numbered id exists for these | this file |

Rules:

- **One worktree, one id.** If the work turns out to span a second id, open a second worktree
  rather than widening the first.
- The worktree's **first commit body names the id and the file(s) it maps to**, and the PR
  description opens with the same id. A reader must never have to guess which decision a branch
  belongs to.
- If no id exists yet, **create the record first** — the ADR, the requirement, the sprint entry —
  then name the worktree after it. `meta` is the only exemption, and only for process/tooling
  files that live outside `docs/`.
- Do not rename or reuse a worktree for unrelated work; `.claude/worktrees/` is a record of what
  was attempted, not scratch space.

## Landing work

The default branch is `master` (this repo has no separate `main`). The flow is:

1. Commit in the worktree.
2. Push the branch to `origin`.
3. Open a PR with `gh pr create` — title and body opening with the worktree's id.
4. **Merge it into `master` directly**, without waiting, once the PR is green.

Do not leave a PR open hoping for review: the normal end state is *merged*. Report the PR and the
merge together.

**Stop before step 4 and ask for the human's approval** when the change is one the process reserves
to them. That is the case when it:

- changes a `**Status**` line — anything moving a document to **Approved**, or marking one
  **Superseded**;
- answers an open question (Q-01, Q-09, Q-02 … Q-06) or amends a decision recorded in an ADR,
  including ADR-011's v1 scope envelope;
- touches `.ai/` (which should not happen — propose in chat instead);
- lands something behind a human quality gate in `docs/07-implementation/implementation-plan.md`
  §4, or a release blocker (the accuracy gate, the shipped default policy);
- publishes a boundary or platform claim — e.g. anything that would imply Windows support, or
  describe injection-driven escape as prevented.

In those cases push the branch and open the PR anyway, say plainly which clause triggered the hold,
and leave the merge to the human. Never force-push, never merge `master` into a worktree branch to
"fix" it, and never delete a branch that was not merged.

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

`docs/05-adr/002` … `011` are **Proposed**, awaiting the human's review: Rust enforcement core
with a TypeScript UI (002 — **amendment pending**, see below), a local daemon over a Unix socket
with **no TCP listener in any configuration** (003), layered policy where deterministic rules decide
before intent rules (004), a pluggable local model runtime (005), a hash-chained single-writer audit
log (006), per-CLI adapters with a coverage matrix (007), OS-native confinement with no absolute
isolation claim (008), fail-closed as a default value rather than a branch (009), no web-server UI
(010), and the v1 scope envelope (011).
Read `docs/05-adr/README.md` for the index and the open questions each one is blocked on.

**v1 scope was confirmed with the product owner on 2026-10-02** (ADR-011). Treat these as settled
product decisions, not as options to revisit:

| Dimension | v1 |
|---|---|
| Platforms | macOS + Linux, both adversarially tested on real kernels. **Windows unsupported**, and no Windows boundary claim may be published |
| Threat model | An agent that **errs**, not one actively escaping. Injection-driven escape is detected and logged — never described as prevented |
| Integrations at ship | **Two**: Claude Code hook adapter **and** the MCP proxy. Build the `CliAdapter` contract before either |
| Distribution | Single-user local tool. No control plane, no shared baseline. S-11/S-12/S-23 are post-v1 and persona P2 is not a v1 persona |
| Interface | CLI + config file + a **read-only TUI** audit viewer. No web UI. Nothing binds a TCP port |
| Posture | **Enforcing from the first action.** Dry-run is opt-in, so the accuracy gate and the shipped default policy are release blockers |
| Timeline | Side project, intermittent — each sprint must land something independently useful |

**Two questions are still open and still block Discovery approval:** Q-01 (which local model —
"laya" is a specific model, not a placeholder; gates ADR-005) and Q-09 (make the product
single-language Rust, now that a TUI leaves TypeScript with no consumer; an amendment to ADR-002).
Do not resolve either by inference.

Treat a Proposed ADR as the current design intent, not as settled: Phase 3 accepts or supersedes
them. Every document under `docs/01-discovery/` and `docs/04-solution-design/` is **Draft**, and
Phase 4 was drafted ahead of its Phase 3 prerequisite at the product owner's explicit request.
