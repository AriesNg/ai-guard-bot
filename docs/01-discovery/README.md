# 01 — Discovery

**Status**: 🟢 Approved — v1, 2026-10-02
**Documents**: `requirements.md`, `user-personas.md` (re-scoped 2026-10-02; Q-01/Q-09 resolved the
same day)
**Approved 2026-10-02**: all eight Open Questions are answered. Q-02 … Q-08 were answered by the
product owner on 2026-10-02 and are recorded in
[`../05-adr/011-v1-scope-envelope.md`](../05-adr/011-v1-scope-envelope.md); the two that session
left open — **Q-01** (which local model) and **Q-09** (single-language Rust) — were answered later
the same day and are recorded in
[`../05-adr/013-model-and-language-resolution.md`](../05-adr/013-model-and-language-resolution.md).
That ADR raised one narrower open point of its own (how Laya is served), resolved 2026-10-04 in
[`../05-adr/014-laya-serving-resolution.md`](../05-adr/014-laya-serving-resolution.md) — it never
reopened Discovery, which only required the model to be *named*.

## Purpose
Understand the problem, users, market, and constraints before designing anything.

## Deliverables
- [x] Problem statement
- [x] User personas (4)
- [x] User stories (P0/P1/P2) — S-01 … S-26, with S-11/S-12/S-23 deferred post-v1 and S-19 withdrawn
- [x] Functional requirements — FR-01 … FR-32, including FR-30 – FR-32 (decision trace, explain, replay)
- [x] Non-functional requirements — quantified
- [x] Constraints & risks — R-01 … R-07 with mitigations
- [x] Scope boundaries — in-scope and 15 explicit out-of-scope items
- [x] v1 scope envelope confirmed with the product owner (platforms, threat model, adapters,
      distribution, interface, timeline, posture)
- [x] Local model named (Laya) and implementation language confirmed (single-language Rust) —
      [ADR-013](../05-adr/013-model-and-language-resolution.md)

## How to use this phase
1. AI reads `.ai/templates/discovery.md`
2. AI generates draft into this folder `requirements.md`
3. Human reviews and requests changes
4. ~~Once approved, move to Phase 2~~ **Done 2026-10-02.** Phase 2 (UX Design) is next in sequence,
   though Phase 3 (System Design) and Phase 4 were already drafted ahead of it at the product
   owner's explicit request — see each phase's README for that note.

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
| Traceability | Every decision carries its own trace inside the audit hash, with `guard explain` and `guard replay` ([ADR-012](../05-adr/012-decision-trace.md)) |
| Local model | **Laya** (Convai Innovations, ONNX, ≈ 1.7 GB fp32 weights) — a "System 1 decision model" over `choice`/`score`/`noul` questions, not a chat LLM. Served via its own `laya-serve` reference server as a local sidecar — [ADR-005](../05-adr/005-pluggable-local-model-runtime.md) item 2, [ADR-014](../05-adr/014-laya-serving-resolution.md) |
| Implementation language | Single-language Rust — enforcement core, CLI, and TUI in one static binary. No Node runtime ships |

Full reasoning and the consequences of each answer:
[`../05-adr/011-v1-scope-envelope.md`](../05-adr/011-v1-scope-envelope.md) (Q-02 … Q-08) and
[`../05-adr/013-model-and-language-resolution.md`](../05-adr/013-model-and-language-resolution.md)
(Q-01, Q-09).

## Files
- `requirements.md` — consolidated discovery document
- `user-personas.md` — persona details (can be inline in requirements)
- `market-analysis.md` — optional, only if relevant
