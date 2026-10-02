# 03 — System Design

**Status**: 🟡 Draft — awaiting review
**Last updated**: 2026-10-02

> **Phase-gate note.** The prerequisite below is **UX Design approved**; Phase 2 is ⬜ Not started.
> Phase 1 is now **Approved** (Q-01 and Q-09 were answered 2026-10-02 — see
> [ADR-013](../05-adr/013-model-and-language-resolution.md)), but Phase 3's own prerequisite (UX
> Design) is still unmet. These documents were drafted ahead of that gate at the product owner's
> explicit request — the same precedent under which Phase 4 was drafted. Each document opens with
> the same note and the assumption table it carries.

## Purpose
Define the architecture, data model, APIs, and security strategy — and accept or supersede the
Proposed ADRs ([`../05-adr/`](../05-adr/README.md)). Disposition table:
[`architecture.md`](architecture.md) §7. **None is superseded**; several are ratified together with the
Phase-3-owned detail they delegated.

## Deliverables
- [x] Architecture diagram (C4 L1–L3) — [`architecture.md`](architecture.md) §2–§4
- [x] Tech stack decisions — [`architecture.md`](architecture.md) §5
- [x] Data model / ERD — [`data-model.md`](data-model.md) §1
- [x] API contracts — [`api-design.md`](api-design.md) §3, §4, §7, §8
- [x] Security architecture — [`security.md`](security.md)
- [x] Data flow diagrams — [`architecture.md`](architecture.md) §6.1–§6.5

## Files
- `architecture.md` — C4 L1–L3, tech stack with rationale, runtime and deployment views, ADR
  disposition, the NFR acceptance table, the review checklist
- `data-model.md` — ERD, the canonical `Action` and the closed eleven-value `ActionKind` enum, policy
  schema and validation, the audit record and its chain, storage design, 3NF statement
- `api-design.md` — the 19-method daemon RPC surface with budgets and read/write split, the CLI surface,
  the closed `GuardError` catalogue, the formal precedence relation, the model constrained-decoding
  schema, the `CliAdapter` contract
- `security.md` — adversary, per-platform `BoundaryDescription`, **what is not prevented**,
  authn/authz, R-07 invariants, input validation, saturation, secrets, CORS N/A, threat map

## Phase-3-owned work discharged here

| Delegated by | Obligation | Discharged in |
|---|---|---|
| ADR-004 | Formalise the specificity relation so the precedence order is total in fact | [`api-design.md`](api-design.md) §6 |
| ADR-004 | Make the resolver report the key that eliminated each loser, not just the winner | [`api-design.md`](api-design.md) §6.4 |
| ADR-005 | Define the constrained-decoding schema; reject an unconstrainable runtime at startup | [`api-design.md`](api-design.md) §7 |
| ADR-006 | Choose the embedded audit store against a measured durable-append benchmark | [`data-model.md`](data-model.md) §6.1 |
| ADR-007 | Fix the coverage matrix's `ActionKind` list, including the five `mcp.*` cells (FR-28) | [`data-model.md`](data-model.md) §2.1 |
| ADR-008 | Write the per-platform `BoundaryDescription` and publish the threat model | [`security.md`](security.md) §2, §3 |
| ADR-003 | Treat the socket path as part of the threat model | [`security.md`](security.md) §4.3 |

**Raised by this phase, not delegated to it:** the design above records *what* each decision was and
discarded *how* it was reached, which makes a recorded verdict unverifiable by the person holding the
log. [ADR-012](../05-adr/012-decision-trace.md) closes that gap — every decision carries a trace inside
the audit hash (FR-30 – FR-32), with `decision.explain` and `decision.replay` as first-class surfaces
([`data-model.md`](data-model.md) §5.5, [`api-design.md`](api-design.md) §4, §6.4). It is blocked on
neither Q-01 nor Q-09.

## Assumptions carried

| # | Assumption | Status |
|---|---|---|
| A-1 | Single-language Rust; one binary for engine, CLI and TUI | **Confirmed 2026-10-02** — Q-09 / [ADR-013](../05-adr/013-model-and-language-resolution.md) |
| A-2 | The local model is **Laya**; no accuracy, memory or context figure in this document has been re-derived from its own published numbers yet, and its serving mechanism (ADR-005 item 2) is still open | **Named 2026-10-02** — Q-01 / [ADR-013](../05-adr/013-model-and-language-resolution.md); **partially resolved** |
| A-3 | TypeScript interface syntax is schema notation only | — |

The architectural delta for each resolution is stated in [`architecture.md`](architecture.md) §8, so
answering either question is an edit rather than a redesign.

## Exit criteria for this phase

1. The review checklist in [`architecture.md`](architecture.md) §11 passes, with every N/A carrying its
   reason.
2. The ADR disposition table ([`architecture.md`](architecture.md) §7) is accepted, which moves ADRs
   002–011 from Proposed to Accepted, **and ADR-012, raised by this phase, with them**.
3. The product owner accepts, or corrects, assumptions A-1 and A-2.
4. The human review gates **H-1** and **H-2** in
   [`../07-implementation/implementation-plan.md`](../07-implementation/implementation-plan.md) §4 are
   signed off — H-1 is approval of this phase, and it is the gate Phase 7 is blocked on.

---
**Prerequisite**: UX Design approved — **not met; proceeding at the product owner's explicit request
(see the phase-gate note above)**
**Next**: [`../07-implementation/implementation-plan.md`](../07-implementation/implementation-plan.md)
— the work breakdown and the human quality-check schedule, gated on this phase's approval
