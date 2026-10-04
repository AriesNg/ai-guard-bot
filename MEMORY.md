# MEMORY.md — Shared Project Memory

The **durable, checked-in context** for this repository: decisions already made, facts that are
easy to get wrong, and the current state of play. It is committed so that every contributor —
human or AI — starts from the same picture, instead of each one rebuilding it from a private
cache.

**Read this before starting work.** It is deliberately short; it is a state snapshot, not an
archive.

| File | Holds | Shape |
|------|-------|-------|
| `CLAUDE.md` | How the repo works — rules, phase gate, permissions, verification | Stable instructions |
| `MEMORY.md` (this file) | What is true *right now* — state, decisions, gotchas | Overwritten as it changes |
| `LEARN.md` | What we got wrong and what we do instead | Append-only, `L-NNN` entries |
| `docs/08-maintenance/defect-log.md` | Defects found, with severity and fix status | Append-only, `D-NNN` entries |
| `.ai/` | The process contract — **human-owned, never write here** | Human-authored |

Local agent caches (for example `.memsearch/`) are per-machine and gitignored. Anything worth
sharing is promoted into this file or `LEARN.md` by hand.

## Current state

_Last reviewed: 2026-10-02_

- **Phase**: design. There is no application code. `src/`, `tests/`, and `infrastructure/`
  contain no implementation — `tests/docs/verify-docs.sh` is the one real test and it checks the
  documents, which are the only shipped artefact so far.
- **Document status**: Phase 1 (Discovery) and Phase 3 (System Design) are **Draft**; Phase 4
  (Solution Design) is Draft and generated *ahead of* its Phase 3 prerequisite at the product
  owner's request. Phase 5 ADRs are **Proposed** (002 … 012). Phases 2, 6, 7 are **Not started**;
  Phase 7 is blocked on H-1 (Phase 3 approval). Phase 8 (Maintenance) is Draft and is process
  infrastructure, not a design phase.
- **Tooling**: none installed — no lockfile, no framework, no runtime chosen. `package.json`'s
  scripts are all empty strings (scaffold residue). The only command to run is
  `tests/docs/verify-docs.sh`.
- **Git**: default branch `master`, remote `origin` at `github.com:AriesNg/ai-guard-bot`. Work
  lands via a self-merged PR (see `CLAUDE.md`, "Landing work").
- **Blocked on**: Q-01 (which local model — gates ADR-005) and Q-09 (single-language Rust, an
  amendment to ADR-002). These two are the only questions still open; Discovery should not be
  marked approved until they are answered.

## What the product is

**AI Guard Bot** — a local, vendor-agnostic guardrail layer between an AI CLI agent and the
machine it runs on. It intercepts every action the agent attempts, evaluates it against
user-defined rules (deterministic checks first, a small local model for judgement calls), and
then allows it, rewrites it (PII/secret masking), or rejects it with a machine-readable error
code. Approved actions run inside a sandbox. No policy decision requires a network call.

Authoritative source: `.ai/context/project-brief.md`, then `README.md`. Do **not** infer the
product from the directory name (see `LEARN.md` L-001).

## Decisions in force

| id | Decision | Status | Source |
|----|----------|--------|--------|
| ADR-001 | Next.js 14+ App Router, TypeScript, RSC | **Superseded by ADR-010** — binds nothing | `docs/05-adr/010-...md` |
| ADR-002 | Rust enforcement core with TypeScript UI | **Proposed — amendment pending** (Q-09: single-language Rust) | `docs/05-adr/002-...md` |
| ADR-003 | Local daemon over a Unix socket, **no TCP listener in any configuration** | Proposed | `docs/05-adr/003-...md` |
| ADR-004 | Layered policy: deterministic rules before intent rules | Proposed | `docs/05-adr/004-...md` |
| ADR-005 | Pluggable local model runtime (gated on Q-01) | Proposed | `docs/05-adr/005-...md` |
| ADR-006 | Hash-chained single-writer audit log | Proposed | `docs/05-adr/006-...md` |
| ADR-007 | Per-CLI adapters behind a `CliAdapter` contract, coverage matrix | Proposed | `docs/05-adr/007-...md` |
| ADR-008 | OS-native spawn-time confinement, no absolute isolation claim | Proposed | `docs/05-adr/008-...md` |
| ADR-009 | Fail-closed as a default value, not a branch | Proposed | `docs/05-adr/009-...md` |
| ADR-010 | No web-server UI — read-only TUI audit viewer | Proposed (supersedes ADR-001) | `docs/05-adr/010-...md` |
| ADR-011 | v1 scope envelope — **confirmed with the product owner 2026-10-02** | Settled product decision | `docs/05-adr/011-...md` |
| ADR-012 | The decision trace: every decision carries its own reconstruction | Proposed | `docs/05-adr/012-...md` |

The v1 scope in ADR-011 is settled, not up for revisiting: macOS + Linux (Windows unsupported,
no boundary claim), threat model is an agent that **errs** (injection-driven escape is detected
and logged, never described as prevented), two shipped integrations (Claude Code hook adapter
and the MCP proxy, `CliAdapter` contract first), single-user local tool with no control plane,
CLI + config + read-only TUI, **enforcing from the first action** (so the accuracy gate and
shipped default policy are release blockers), and intermittent side-project timeline.

Decisions are superseded by a new ADR, never edited away.

## Gotchas

Facts that have already misled someone. The full reasoning lives in `LEARN.md`.

- The `package.json` scripts are **empty placeholders**. No build, test, or lint command exists
  yet — never run or document one as if it does. (L-005)
- The **one** command that exists is `tests/docs/verify-docs.sh`. Run it before committing; a
  failure is a defect to fix or raise in `docs/08-maintenance/defect-log.md`. (L-009)
- `.ai/` is **human-owned**. Propose changes in chat; do not write there. (L-002)
- `docs/` is phase-gated. Each phase `README.md` carries a `**Status**` line and a
  `Prerequisite` line — check both, and use the exact filenames that README lists.
- Never state an absolute safety guarantee for the sandbox. State a threat model with a named
  boundary. (L-003)
- Quantify every non-functional requirement. "P95 < 200 ms", never "fast". (L-004)
- Never force-push a shared branch — a history rewrite once dropped PR #1's files (`LEARN.md`,
  `MEMORY.md`) from `master`. (L-008)

## Keeping this file honest

Update **Current state** and **Decisions in force** in the same commit that makes them true:
when a phase is approved, a sprint lands, an ADR is accepted, or an open question is answered.
Bump _Last reviewed_ when you check the file and find nothing to change. A stale memory file is
worse than none — it is followed confidently.
