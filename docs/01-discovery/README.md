# 01 — Discovery

**Status**: 🟡 Draft — awaiting human review
**Documents**: `requirements.md`, `user-personas.md` (both Draft; re-scoped 2026-10-02)
**Blocking approval**: Open Questions **Q-01** (which local model) and **Q-09** (single-language
Rust) in `requirements.md`. Q-02 … Q-08 were answered by the product owner on 2026-10-02 and are
recorded in [`../05-adr/011-v1-scope-envelope.md`](../05-adr/011-v1-scope-envelope.md).

## Purpose
Understand the problem, users, market, and constraints before designing anything.

## Deliverables
- [x] Problem statement
- [x] User personas (4)
- [x] User stories (P0/P1/P2) — S-01 … S-24, with S-11/S-12/S-23 deferred post-v1 and S-19 withdrawn
- [x] Functional requirements — FR-01 … FR-26
- [x] Non-functional requirements — quantified
- [x] Constraints & risks — R-01 … R-07 with mitigations
- [x] Scope boundaries — in-scope and 15 explicit out-of-scope items
- [x] v1 scope envelope confirmed with the product owner (platforms, threat model, adapters,
      distribution, interface, timeline, posture)

## How to use this phase
1. AI reads `.ai/templates/discovery.md`
2. AI generates draft into this folder `requirements.md`
3. Human reviews and requests changes
4. Once approved, move to Phase 2

## Confirmed v1 envelope (2026-10-02)

| Dimension | v1 |
|---|---|
| Platforms | macOS + Linux, both adversarially tested. Windows unsupported, no boundary claim |
| Threat model | An agent that errs; injection-driven escape detected and logged, not prevented |
| Adapters at ship | Claude Code (hook-based) **and** the vendor-neutral MCP proxy |
| Distribution | Single-user local tool — no control plane, no shared baseline |
| Interface | CLI + config file + read-only TUI audit viewer. No web UI, no TCP port |
| Posture | Enforcing from the first action; dry-run is opt-in |
| Timeline | Side project, intermittent — each sprint independently useful |

Full reasoning and the consequences of each answer:
[`../05-adr/011-v1-scope-envelope.md`](../05-adr/011-v1-scope-envelope.md).

## Files
- `requirements.md` — consolidated discovery document
- `user-personas.md` — persona details (can be inline in requirements)
- `market-analysis.md` — optional, only if relevant
