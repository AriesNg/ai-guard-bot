# MEMORY.md — Shared Project Memory

The **durable, checked-in context** for this repository: decisions already made, facts that are
easy to get wrong, and the current state of play. It is committed so that every contributor —
human or AI — starts from the same picture, instead of each one rebuilding it from a private
cache.

**Read this before starting work.** It is deliberately short; it is a state snapshot, not an
archive.

| File | Holds | Shape |
|------|-------|-------|
| `CLAUDE.md` | How the repo works — rules, phase gate, permissions | Stable instructions |
| `MEMORY.md` (this file) | What is true *right now* — state, decisions, gotchas | Overwritten as it changes |
| `LEARN.md` | What we got wrong and what we do instead | Append-only, `L-NNN` entries |
| `.ai/` | The process contract — **human-owned, never write here** | Human-authored |

Local agent caches (for example `.memsearch/`) are per-machine and gitignored. Anything worth
sharing is promoted into this file or `LEARN.md` by hand.

## Current state

_Last reviewed: 2026-09-27_

- **Phase**: design. There is no application code. `src/`, `tests/`, and `infrastructure/`
  contain only `.gitkeep`. All seven documentation phases are ⬜ Not started.
- **Tooling**: none installed. No lockfile, no framework. Every script in `package.json` is an
  empty string. Sprint 1 (`docs/07-implementation/sprint-001-plan.md`) is what creates the
  toolchain — Next.js + TypeScript + ESLint + Prettier, then `lint → test → build`.
- **Git**: initialized, default branch `master`, remote `origin` at
  `github.com:AriesNg/ai-guard-bot`.
- **Blocked on**: the six open questions in `.ai/context/project-brief.md` — local model choice,
  target platforms, sandbox threat model, first target agent, distribution model, and whether a
  web UI is in v1 scope. Discovery should not be marked approved until these are answered.

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
| ADR-001 | Next.js 14+ App Router, TypeScript, React Server Components by default | **Accepted — binding** | `docs/05-adr/001-use-react-and-typescript.md` |
| — | ADR-001 governs the **web/UI surface only**. The enforcement core's language and runtime are an **open Phase 3 question**, to be settled by a new ADR — not assumed from ADR-001 | Open | `.ai/context/project-brief.md` |
| — | Local model runtime is pluggable (Ollama or equivalent); no hard dependency on one model | Open (direction agreed) | `.ai/context/project-brief.md` |
| — | No AI-vendor SDK in the enforcement path; no cloud service in the policy-decision path | Constraint | `.ai/context/project-brief.md` |

Decisions are superseded by a new ADR, never edited away.

## Gotchas

Facts that have already misled someone. The full reasoning lives in `LEARN.md`.

- The seven `package.json` scripts are **empty placeholders**. No build, test, or lint command
  exists yet — never run or document one as if it does. (L-005)
- `.ai/` is **human-owned**. Propose changes in chat; do not write there. (L-002)
- `docs/` is phase-gated. Each phase `README.md` carries a `**Status**` line and a
  `Prerequisite` line — check both, and use the exact filenames that README lists.
- Never state an absolute safety guarantee for the sandbox. State a threat model with a named
  boundary. (L-003)
- Quantify every non-functional requirement. "P95 < 200 ms", never "fast". (L-004)
- The ADR index table in `docs/05-adr/README.md` does not yet list ADR-001.

## Keeping this file honest

Update **Current state** and **Decisions in force** in the same commit that makes them true:
when a phase is approved, a sprint lands, an ADR is accepted, or an open question is answered.
Bump _Last reviewed_ when you check the file and find nothing to change. A stale memory file is
worse than none — it is followed confidently.
