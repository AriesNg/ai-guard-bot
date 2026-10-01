# 05 — Architecture Decision Records

**Status**: 🟡 Draft — ADR-001 **Superseded** by ADR-010; ADR-002 … ADR-012 Proposed, awaiting human review
**Last updated**: 2026-10-02, after the product owner's requirements-confirmation session (recorded
in [ADR-011](011-v1-scope-envelope.md))

## Purpose
Record every significant architectural decision with context, rationale, and rejected alternatives.

## ADR Index

| # | Title | Status | Date |
|---|-------|--------|------|
| [001](001-use-react-and-typescript.md) | Use React + TypeScript with Next.js App Router | ~~Accepted~~ **Superseded by 010** | 2026-05-10 |
| [002](002-enforcement-core-language.md) | Rust for the enforcement core, TypeScript for the UI | Proposed — **amendment pending** (TUI makes it single-language) | 2026-09-28 |
| [003](003-local-daemon-over-unix-socket.md) | A long-lived local daemon addressed over a Unix domain socket | Proposed | 2026-09-28 |
| [004](004-layered-policy-model.md) | Layered policy — deterministic rules decide first, intent rules fill the gap | Proposed | 2026-09-28 |
| [005](005-pluggable-local-model-runtime.md) | Pluggable local model runtime with constrained decoding | Proposed | 2026-09-28 |
| [006](006-audit-log-integrity.md) | Hash-chained, single-writer audit log, durable before the decision returns | Proposed | 2026-09-28 |
| [007](007-cli-integration-strategy.md) | Per-CLI adapters over documented hook interfaces, with a coverage matrix | Proposed | 2026-09-28 |
| [008](008-sandbox-confinement-primitive.md) | Sandbox confinement — OS-native primitives, and no absolute isolation claim | Proposed — **unblocked**; Seatbelt + Landlock/seccomp | 2026-09-28 |
| [009](009-fail-closed-default.md) | Fail-closed by default, implemented as a default value rather than a branch | Proposed | 2026-09-28 |
| [010](010-supersede-adr-001-no-web-server-ui.md) | Supersede ADR-001 — no web-server UI; the CLI is v1's interface | Proposed — amended, Q-06 closed with a TUI | 2026-10-02 |
| [011](011-v1-scope-envelope.md) | v1 scope envelope — platforms, adapters, interface, posture | Proposed | 2026-10-02 |
| [012](012-decision-trace.md) | Every decision carries its own trace, inside the audit hash | Proposed — raised by Phase 3; blocked on neither Q-01 nor Q-09 | 2026-10-02 |

## Scope note on ADR-001 — superseded

ADR-001 was inherited from the project scaffold and predates the project brief. It **binds
nothing**: its stated forces (SSR, static generation, SEO, Vercel deployment, a BFF) do not
describe a local guardrail daemon, and as written it conflicts with ADR-003's rule that no TCP
listener exists in the product in any configuration.
[ADR-010](010-supersede-adr-001-no-web-server-ui.md) supersedes it — deciding the constraints any
UI must satisfy (static assets, no server runtime, no listener, read-only) while deferring the
stack choice to Q-06. TypeScript for UI client code survives, as a preference.

ADR-002's "TypeScript for the UI" half therefore no longer rests on ADR-001; it rests on ADR-010
item 4. ADR-002's enforcement-core decision is unaffected — ADR-001 never governed that layer.

## Decision dependency graph

```mermaid
flowchart TD
    A001["ADR-001: Next.js + TS for UI<br/>(superseded)"] -.->|superseded by| A010["ADR-010: No web-server UI;<br/>CLI is v1's interface"]
    A002[ADR-002: Rust core, TS UI]
    A010 --> A002
    A003 --> A010
    A002 --> A003[ADR-003: Daemon over Unix socket]
    A003 --> A006[ADR-006: Hash-chained audit log]
    A003 --> A007[ADR-007: Per-CLI adapters]
    A004[ADR-004: Layered policy model] --> A005[ADR-005: Pluggable model runtime]
    A004 --> A009[ADR-009: Fail-closed default]
    A005 --> A009
    A006 --> A009
    A007 --> A009
    A002 --> A008[ADR-008: Sandbox primitive]
    A007 --> A008
    A008 --> A009
    A011["ADR-011: v1 scope envelope<br/>(Q-02…Q-08 answered)"] --> A008
    A011 --> A007
    A011 --> A010
    A011 -.->|amendment pending| A002
    A004 --> A012["ADR-012: Decision trace<br/>inside the audit hash"]
    A006 --> A012
    A009 --> A012
    A012 --> A006
```

ADR-012 is the one two-way edge in the graph, and deliberately so: it *depends* on ADR-006's record
and chain, and it also *changes* what ADR-006's record contains. The alternative — a separate
side-car log — was rejected in ADR-012 precisely because it would have made the dependency one-way
at the cost of leaving the explanation outside the chain.

## What each ADR answers

| ADR | The question it settles | Primary driver |
|---|---|---|
| 002 | What language is the enforcement core, which no earlier ADR addressed? | P95 < 10 ms adapter overhead; OS confinement APIs |
| 003 | What holds the policy, model, and audit chain between actions, and how is it reached? | Model load cost; single audit writer; R-07 |
| 004 | How can plain-language rules be the authoring surface without a small model being the sole gate on irreversible actions? | **R-01**, FR-11 |
| 005 | Which local model, and how is its output prevented from becoming an instruction? | Q-01, FR-12, R-02 |
| 006 | What makes the audit log evidence rather than a debug file? | FR-19–FR-22, persona P3 |
| 007 | How are CLIs we do not control intercepted, and what happens where coverage is incomplete? | R-04, R-05, FR-08 |
| 008 | What is the confinement boundary, and what will the product claim about it? | FR-17, FR-18, R-02 |
| 009 | What happens to an action when the engine cannot evaluate it? | S-08, FR-10, Availability NFR |
| 010 | Does the product ship a UI, and may it ship a web server to do it? | ADR-003's no-listener invariant; R-07; persona P3; Q-06 |
| 011 | What is actually in v1 — which platforms, which adapters, which interface, enforcing from when? | The product owner's answers of 2026-10-02 |
| 012 | The log says *what* was decided — what makes it say *how*, and how is yesterday's decision reproduced? | FR-30–FR-32, S-26; ADR-006's chain; ADR-004's precedence order |

## Blocked on human input

As of 2026-10-02, **two questions remain open** — Q-01, carried from the brief, and **Q-09**, raised
*by* the answers. See [ADR-011](011-v1-scope-envelope.md) for the seven that were answered.

| ADR | Blocked on | Effect |
|---|---|---|
| 005 | **Q-01** — which model is "laya"? The owner confirms it is a specific model, not a Llama-class placeholder | The runtime port and the `LocalModelRuntime` contract stand; the accuracy gate thresholds and the < 5 GB memory budget cannot be validated until the model is named |
| 002 | **Q-09** — owner's confirmation of [ADR-011](011-v1-scope-envelope.md)'s open point: make the product single-language Rust, now that the UI is a TUI | Decides whether TypeScript, a Node runtime, and the schema-codegen build step exist at all |

**ADR-012 is blocked on neither.** It treats the model's identity as a recorded *field*
(`runtimeId`, `modelId`, `weightsDigest`) rather than a known value, so Q-01 changes what a
provenance stamp contains but not whether one exists; and it specifies a schema and a set of
properties, not a language, so Q-09 changes the implementation and not the decision. It can therefore
be reviewed and accepted now, which matters because a decision record written without a trace can
never acquire one later.

Resolved: Q-02 and Q-03 (ADR-008, unblocked — Seatbelt on macOS, Landlock + seccomp + netns on
Linux, Windows unsupported), Q-04 (ADR-007 — Claude Code adapter plus the MCP proxy), Q-05, Q-06
(ADR-010 — TUI), Q-07, Q-08.

## Template
See `.ai/templates/adr.md`. Every ADR records **Rejected Alternatives**, not just the decision.

---
**Note**: ADRs are created throughout the lifecycle, not just in this phase. Add them whenever a
meaningful decision is made. A decision that changes later is **superseded** by a new ADR rather
than edited in place.
