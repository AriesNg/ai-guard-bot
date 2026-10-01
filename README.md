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
| UI surface (audit log viewer) | **A read-only TUI**, in-process, inside the same binary (Q-06, 2026-10-02). No web UI, no server runtime, no listener; policy writes go through the CLI. | [ADR-010](docs/05-adr/010-supersede-adr-001-no-web-server-ui.md) — **Proposed**, supersedes ADR-001 · [ADR-011](docs/05-adr/011-v1-scope-envelope.md) |
| Enforcement core (interceptor, policy engine, sandbox) | **Rust proposed** — process-start cost against a P95 < 10 ms budget, and first-class bindings to OS confinement primitives. **Amendment pending**: with a TUI rather than a web UI, the recommendation is single-language Rust — one binary, no Node runtime (Q-09) | [ADR-002](docs/05-adr/002-enforcement-core-language.md) — **Proposed, amendment pending** |
| Platforms | **macOS and Linux** — Seatbelt, and Landlock + seccomp + network namespaces. **Windows unsupported in v1**, no boundary claim published | [ADR-008](docs/05-adr/008-sandbox-confinement-primitive.md) · [ADR-011](docs/05-adr/011-v1-scope-envelope.md) |
| Host integrations at ship | **Two**: Claude Code hook adapter and the vendor-neutral MCP proxy | [ADR-007](docs/05-adr/007-cli-integration-strategy.md) |
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
- **Accessibility** — WCAG 2.1 AA on v1's real surfaces, the terminal and the TUI: no colour-only
  meaning, keyboard-operable throughout, and every TUI query answerable as linear text.
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
| 1 | Discovery — requirements, personas, user stories | [`docs/01-discovery/`](docs/01-discovery/) | — | 🟡 Draft — v1 scope confirmed 2026-10-02; blocked only on Q-01 and Q-09 |
| 2 | UX Design — flows, wireframes, design system | [`docs/02-ux-design/`](docs/02-ux-design/) | Discovery approved | ⬜ Not started |
| 3 | System Design — architecture, data model, APIs | [`docs/03-system-design/`](docs/03-system-design/) | UX Design approved | ⬜ Not started |
| 4 | Solution Design — components, state, testing strategy | [`docs/04-solution-design/`](docs/04-solution-design/) | System Design approved | 🟡 Draft — written ahead of its prerequisite on request; the assumed architecture in `component-design.md` §0 awaits Phase 3 |
| 5 | ADRs — architecture decisions with rationale | [`docs/05-adr/`](docs/05-adr/) | — | 🟡 Draft (002–011 Proposed; ADR-001 superseded by 010; ADR-002 amendment pending) |
| 6 | Infrastructure — deployment, CI/CD, monitoring | [`docs/06-infrastructure/`](docs/06-infrastructure/) | System Design approved (may overlap with Solution Design) | ⬜ Not started |
| 7 | Implementation — sprint plans and progress | [`docs/07-implementation/`](docs/07-implementation/) | Phases 1–6 approved, at least for Sprint 1's scope | ⬜ Not started |

## Open Questions

**Six of the original questions were answered by the product owner on 2026-10-02** and are recorded
in [ADR-011](docs/05-adr/011-v1-scope-envelope.md) — see the v1 scope table in
`.ai/context/project-brief.md`. Two remain, and they are what still blocks Discovery approval:

1. **Local model choice (Q-01)** — "laya" is a specific model, not a Llama-class placeholder. Which
   model, and which runtime serves it? The accuracy thresholds, the memory budget against the 16 GB
   laptop floor, and whether constrained decoding is available are all properties of a named model.
   Gates [ADR-005](docs/05-adr/005-pluggable-local-model-runtime.md).
2. **Single-language Rust (Q-09)** — the TUI answer removed the only consumer of TypeScript.
   Recommendation: build the TUI in-process in Rust, ship one binary, delete the schema-codegen step.
   An amendment to [ADR-002](docs/05-adr/002-enforcement-core-language.md), not applied unilaterally.

Timeline: **side project, intermittent.** Each sprint must land something independently useful.
