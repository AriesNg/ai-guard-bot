# AI Guard Bot

A local, vendor-agnostic guardrail layer that sits between an AI CLI agent and the machine it
runs on. Every action the agent attempts — tool call, function call, MCP request, or shell
command — is intercepted, evaluated against user-defined rules by deterministic policy checks
plus a small locally-run model, and then allowed, rewritten (PII/secret masking), or rejected
with a machine-readable error code naming the violated rule. Allowed actions execute inside a
sandbox that confines filesystem, network, and process access. No policy decision requires a
network call, so no prompt or file content leaves the machine to be judged.

It targets AI **CLIs** first (Claude Code, Codex CLI, Gemini CLI, and others), with a path to
extending the same policy engine to AI **desktop** applications.

> **Project status: design phase.** There is no application code yet. `src/`, `tests/`, and
> `infrastructure/` are empty, and `package.json` has no dependencies and no real scripts.
> Phase 1 (Discovery) and Phase 4 (Solution Design) are drafted and awaiting review; Phases 2, 3,
> 6 and 7 are not started. The substance of this repo today is the process contract in `.ai/`, the
> phase-gated document tree in `docs/`, and those two draft phases.

## Core Capabilities

| # | Capability |
|---|-----------|
| 1 | **Agent-agnostic interception** — via each tool's hook/permission interface, or an MCP proxy / process-level interception where none exists. No forks of the host agent. |
| 2 | **Local small-model policy evaluation** — intent classification, prompt-injection detection, semantic PII detection, served by a pluggable local runtime. |
| 3 | **Configurable rules and hooks** — declarative `allow`/`deny`/`ask`/`mask` rules matching tool name, command, path, network destination, and content; versionable and shareable. |
| 4 | **Structured violation responses** — a stable error code plus the violated rules, parseable by the calling agent rather than a free-text refusal. |
| 5 | **Sandboxed execution** — approved actions run with an explicit filesystem, network, and process allowlist. |
| 6 | **PII and secret handling** — detect and mask or strip credentials, PII, and user-defined keywords, both outbound and inbound. |
| 7 | **Audit log** — append-only record of every intercepted action and the decision taken. |

## Stack

| Layer | Technology | Basis |
|-------|-----------|-------|
| Web/UI surface (policy editor, audit log viewer) | Next.js 14+ App Router, TypeScript, React Server Components by default | [ADR-001](docs/05-adr/001-use-react-and-typescript.md) — **Accepted**, binding |
| Enforcement core (interceptor, policy engine, sandbox) | **Open question** — different constraints (startup time, latency, OS-level sandboxing); to be settled by a new ADR in Phase 3, not assumed from ADR-001 | `.ai/context/project-brief.md` |
| Local model runtime | Pluggable local inference layer (Ollama or equivalent), not a hard dependency on one model | `.ai/context/project-brief.md` |
| Infrastructure | Not yet decided (Phase 6) | — |

Explicitly avoided: any hard dependency on a specific AI vendor's SDK in the enforcement path,
and any cloud service in the policy-decision path.

## Starting Non-Functional Targets

To be quantified in Phase 1 and fixed in Phase 3. Current targets for discussion:

- **Latency** — P95 added latency per intercepted action under 50 ms for deterministic rule
  evaluation, under 300 ms when local model evaluation is required. Deterministic rules run
  first, keeping the model off the hot path for most actions.
- **Throughput** — sustain at least 4 concurrent agent sessions on a developer laptop within a
  defined CPU/RAM budget.
- **Fail mode** — fail-closed by default: an action that cannot be evaluated is denied.
  Configurable per rule.
- **Privacy** — no action content, file content, or prompt leaves the local machine as part of a
  policy decision.
- **Observability** — every decision emits a structured event with rule id, decision, and latency.
- **Accessibility** — any UI surface meets WCAG 2.1 AA.
- **Sandbox isolation** — stated as a concrete threat model, never as an absolute claim.

## Getting Started

Nothing to run yet. The script names in `package.json` (`dev`, `build`, `start`, `lint`, `test`,
`test:e2e`, `typecheck`) are empty placeholders reserved for the eventual toolchain.
[Sprint 1](docs/07-implementation/sprint-001-plan.md) is what populates them — initialize
Next.js + TypeScript + ESLint + Prettier, then wire `lint → test → build`. This section gets
real commands as part of that scaffold story.

## Project Structure

```
.ai/              # AI instructions, templates, rules — human-owned, do not write here
docs/             # Phase-by-phase documentation
src/              # Application source code (empty)
tests/            # Test suites (empty)
infrastructure/   # Deployment, Docker, K8s, Terraform (empty)
```

## How Work Proceeds

Seven numbered phases, each owning a folder under `docs/`. A phase README carries a `**Status**`
line and a `Prerequisite` line naming the phase that must be approved first — **never skip
ahead**, and use the exact filenames each README lists. `.ai/rules/review-criteria.md` is the
per-phase exit checklist; `.ai/templates/` holds the template for each phase's main document.
The model is a spiral, not a waterfall: later learning may reopen an earlier phase, in which
case the affected document is **superseded** rather than silently edited.

Read `.ai/instructions.md`, `.ai/workflow.md`, and `.ai/rules/*.md` before contributing.

## Phase Status

| # | Phase | Folder | Prerequisite | Status |
|---|-------|--------|--------------|--------|
| 1 | Discovery — requirements, personas, user stories | [`docs/01-discovery/`](docs/01-discovery/) | — | 🟡 Draft — awaiting review |
| 2 | UX Design — flows, wireframes, design system | [`docs/02-ux-design/`](docs/02-ux-design/) | Discovery approved | ⬜ Not started |
| 3 | System Design — architecture, data model, APIs | [`docs/03-system-design/`](docs/03-system-design/) | UX Design approved | ⬜ Not started |
| 4 | Solution Design — components, state, testing strategy | [`docs/04-solution-design/`](docs/04-solution-design/) | System Design approved | 🟡 Draft — written ahead of its prerequisite on request; the assumed architecture in `component-design.md` §0 awaits Phase 3 |
| 5 | ADRs — architecture decisions with rationale | [`docs/05-adr/`](docs/05-adr/) | — | ⬜ Not started (ADR-001 Accepted) |
| 6 | Infrastructure — deployment, CI/CD, monitoring | [`docs/06-infrastructure/`](docs/06-infrastructure/) | System Design approved (may overlap with Solution Design) | ⬜ Not started |
| 7 | Implementation — sprint plans and progress | [`docs/07-implementation/`](docs/07-implementation/) | Phases 1–6 approved, at least for Sprint 1's scope | ⬜ Not started |

## Open Questions

These block or materially shape Phase 1 and should be answered before Discovery is approved
(full text in `.ai/context/project-brief.md`):

1. **Local model choice** — the request named "jev / laya"; read as small local models in the
   Llama/Gemma/Qwen class. Confirm the intended models or runtimes.
2. **Target platforms** — macOS only to start, or macOS + Linux + Windows? Drives the sandbox
   technology choice heavily.
3. **Threat model** — an agent that errs, or an agent actively trying to escape (e.g. driven by
   prompt injection)? The answer changes the design substantially.
4. **First target agent** — which AI CLI should be supported end-to-end first?
5. **Distribution** — single-user local tool, or team deployment with centrally-managed policy?
6. **Scope of the UI** — is a web UI in scope for v1, or is v1 CLI-and-config-file only?

Timeline: not yet set.
