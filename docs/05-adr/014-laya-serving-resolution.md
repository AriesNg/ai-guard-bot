# ADR-014: Laya served via its own `laya-serve` sidecar; reasons templated from per-rule checks

## Status
Proposed — records the product owner's resolution session of **2026-10-04**

## Context

[ADR-013](013-model-and-language-resolution.md) named the local model (**Laya**) and confirmed
single-language Rust (Q-09), but explicitly left one point open rather than resolving it by
inference: ADR-005 decision item 2 defaults to "an Ollama-class local server," and Laya is not
Ollama-servable. ADR-013's own research described Laya's *only* published runtime as an
MIT-licensed Node.js/TypeScript wrapper over ONNX Runtime
([github.com/receptron/laya](https://github.com/receptron/laya)) — which, with Q-09 now closing
out Node entirely, would force a from-scratch Rust reimplementation of Laya's pre/post-processing
(ADR-013's option (b)) or substituting an Ollama-servable model for the one the owner actually
named (option (a)). Neither was applied; both were left for this session.

Separately, two consequences of Laya's shape were still undecided wherever ADR-005 was drafted
against a generic chat-completion model rather than against Laya specifically:

- **Decision item 3** requires the model's output to include a free-text **reason string**,
  constrained-decoded alongside the `DecisionKind` enum and a confidence number. Laya is
  non-autoregressive: it answers typed `choice` / `score` / `noul` (yes/no) questions with
  calibrated probabilities and generates no text of any kind. There is no free-text channel to
  constrain — Laya is stricter than ADR-005's constrained-decoding requirement asked for, not
  looser — but item 3 as written describes a capability Laya does not have.
- Laya's own published latency figures split sharply by call shape and hardware: on CPU, a single
  question costs materially more per question than a batched call does (a batch amortises the
  encoder pass across questions); on GPU the gap narrows but does not close. ADR-005's P95 < 300 ms
  / P99 < 800 ms budget (item, unchanged, from the Context section) is comfortable against the
  batched figures and tight-to-risky against the single-question ones on a GPU-less laptop —
  exactly the hardware floor this product targets (`../01-discovery/requirements.md`, 16 GB RAM, no
  GPU assumed).

**A note on the research itself.** Two independent sessions researched Laya (ADR-013's and this
one's) and surfaced overlapping but not identical specifics — consistent parameter-count math
(≈421M params ≈ 1.7 GB at fp32, matching both passes) alongside differing repository names,
licensing details for the serving layer, and latency figures. Laya is a small, fast-moving
open-source project with thin documentation; treat every number in this ADR as the best available
secondary-source estimate, not a verified fact, and re-measure directly against the actual package
before S-6 (the sprint that integrates it) sizes anything against these figures.

## Decision

1. **Serve Laya through its own reference server, as a provisioned local sidecar process — not
   Ollama, not embedded in the Rust binary.** Laya's reference implementation ships a standalone
   HTTP server (started via its own CLI entry point) exposing a typed-decision endpoint and a
   batched variant. `guard install` provisions it (its own runtime plus the Laya weights) the same
   way it would have provisioned Ollama — a sidecar the daemon spawns, health-checks, and
   supervises over a loopback HTTP (or, where the reference server supports it, a Unix socket)
   connection — and `guardd` talks to it as one more concrete implementation behind the
   `LocalModelRuntime` port ADR-005 item 1 already defined. This **amends ADR-005 item 2**: the
   Ollama-class default is replaced by a Laya-specific sidecar for v1, not kept as written (option
   (a)) and not resolved by embedding `ort` plus a reimplementation (option (b)).
   - This is a **third option**, not either of ADR-013's two: it requires no Ollama tag for a model
     that has none, and no Rust reimplementation of Laya's pre/post-processing, because the
     reference server already is the correct implementation of that logic and runs as an
     independent OS process regardless of what language it happens to be written in. Single-language
     Rust (Q-09) governs what ships *inside* `guardd`'s binary; it was never a constraint on what
     external sidecar processes the product is allowed to provision and supervise — `guard install`
     already provisions and supervises OS-level services (launchd/systemd units, per
     `architecture.md` §5) that are not Rust either.
   - If direct verification against the actual package (see the research note above) finds the
     reference server is not self-contained the way described here, the fallback is ADR-013's
     option (a): select an Ollama-servable substitute model and treat "Laya" as the owner's stated
     intent (a small local System-1-style decision model) rather than a literal binary dependency.
     That fallback is **not applied by this ADR** and should only be taken if sidecar provisioning
     is verified impractical during S-6.
2. **Reason strings are templated by the engine from per-rule `noul` checks — Laya emits no reason
   text.** This **amends ADR-005 item 3**: rather than asking Laya one open-ended "should this be
   allowed" question and expecting a reason back, the evaluator asks one `noul` (yes/no, calibrated
   probability) question per candidate intent rule — "does this action violate rule `<rule-id>`:
   `<rule text>`?" — batched into a single call across every intent rule the deterministic layer
   judged applicable to this action. The engine then composes the reason deterministically from
   whichever rule(s) crossed the decision threshold: rule id, rule text, and Laya's calibrated
   probability for that rule, e.g. `"denied: rule R-04 matched (\"no writes outside the repo
   root\"), confidence 0.92"`. No model-generated text ever reaches the reason field, the audit
   log, or the user — only Laya's typed probability output and the rule text the developer
   themselves authored. This is strictly inside ADR-005's existing constrained-decoding intent
   (item 3's goal), just implemented against a model whose native output already has no free-text
   channel to secure.
3. **Always call the batched endpoint, even for a single decision.** This **amends ADR-005 item
   6**: because an action is typically judged against more than one candidate intent rule at a
   time (per decision 2 above), the per-rule `noul` questions for one decision are naturally a
   batch already; the bounded work queue (item 6, unchanged) queues *decisions*, and each decision
   is issued to Laya as one batched call over its candidate rules rather than one call per rule.
   This is what keeps the model-path P95 inside budget on CPU-only hardware: batched per-question
   cost is the figure the < 300 ms budget was checked against, not the single-question figure, and
   the engine must never fall back to issuing rule checks one at a time.

## Rationale

- **The sidecar option was missing from ADR-013's framing, not from the solution space.** ADR-013
  posed the choice as "Ollama-servable substitute" vs. "embed and reimplement," because its research
  characterised Laya's only runtime as Node. A model's *reference implementation* being provisioned
  and run as an independent local process — rather than linked into our binary or required to be a
  specific vendor's server — is exactly what ADR-005 item 1's port already anticipated; Ollama was
  always one example of "a local server," never the definition of the port.
- **Per-rule `noul` checks are a better fit for this product's policy model than a single
  open-ended judgement call would have been**, independent of the reason-string problem: ADR-004's
  layered policy already resolves which intent rules are candidates for an action before the model
  is consulted, so asking "does this violate rule X" once per candidate rule produces an answer that
  is directly attributable to a specific, developer-authored sentence — which is exactly what
  [H-3](../07-implementation/implementation-plan.md)'s denial-quality gate ("can you tell *which
  rule*, *why*") demands, and what a single undifferentiated judgement could not have produced
  without the free-text reason ADR-005 originally relied on the model to generate.
- **Batching was already the queueing unit ADR-005 item 6 assumed existed**; this decision only
  makes explicit that a decision's own candidate-rule checks batch together, closing the gap
  between "there is a bounded queue" and "the thing in each queue slot is cheap enough to meet the
  budget on a GPU-less laptop."
- **Honesty about the research itself is a trade-off worth taking explicitly.** Laya is obscure
  enough that two independent research passes produced different secondary details; recording that
  plainly, rather than presenting either pass's numbers as settled fact, is cheaper now than
  discovering the mismatch mid-S-6.

Trade-offs accepted:

- **A sidecar process is still an external dependency in the install path**, the same install-time
  risk ADR-005 already accepted for "Ollama as the default"; it is not a new category of risk, only
  a differently-named process to provision, health-check, and supervise.
- **Per-rule batched `noul` checks cost more calls-worth of "bandwidth" than one open-ended
  question would**, proportional to the number of candidate intent rules for an action. This is
  bounded by how many intent rules a developer writes for one action class, not by anything
  unbounded, and the batched-call figure this ADR relies on already assumes multiple questions per
  call.
- **If direct verification during S-6 contradicts this ADR's premise** (the research note above),
  the fallback is a second amendment, not a silent substitution — see decision item 1's fallback
  clause.

## Consequences

**Easier**

- ADR-013's open point is closed; Discovery and Phase 3 carry no open owner-decision against the
  model runtime.
- Denial messages are attributable to a specific rule by construction, directly serving H-3's gate
  rather than needing a model-generated sentence to be judged for quality separately.
- The constrained-decoding guarantee (ADR-005 item 3's real intent) is *strengthened*, not
  loosened: Laya cannot emit anything free-form because it was never built to.

**Harder**

- `guard install` must provision, health-check, and supervise one more concrete sidecar (Laya's
  reference server) in addition to the OS-level service units `architecture.md` §5 already names,
  inside the same 5-minute budget (S-09).
- The accuracy corpus (FR-11) must be structured as per-rule `noul` labels, not a single
  allow/deny/ask label per scenario — a corpus-format decision for whoever builds S-6, not a new
  open question, but real work this ADR did not exist before.

**The team must now**

1. Update [ADR-005](005-pluggable-local-model-runtime.md) items 2, 3, and 6, and its Rejected
   Alternatives #3 and #4, to read as amended here rather than as still-open.
2. Update [ADR-013](013-model-and-language-resolution.md)'s "one open point" section to point here
   as the resolution, without rewriting its own history.
3. Update `../03-system-design/architecture.md` assumption A-2 from "serving mechanism still open"
   to resolved, citing this ADR.
4. Carry the per-rule `noul` design into `../03-system-design/api-design.md` §7 (the
   constrained-decoding schema) and `../04-solution-design/testing-strategy.md` §2.2 (the
   evaluator's adversarial suite) when S-6 is planned in detail — not before, per
   `../07-implementation/README.md`'s own rule against sprints planned ahead of their start.
5. Re-measure Laya's actual latency, memory, and serving shape directly against the package at the
   start of S-6, before the performance gate's baseline (ADR-005 "team must now" #5) is recorded —
   this ADR's figures are secondary-source estimates, stated as such above.

## Rejected Alternatives

- **ADR-013 option (a): select an Ollama-servable substitute, treat "Laya" as intent.** Keeps
  ADR-005 completely unamended and the install path identical to the original design. Rejected as
  the primary resolution because it does not run the model the owner specifically named — but kept
  as the **named fallback** in decision item 1, rather than discarded, because it is the right
  answer if the sidecar approach turns out not to be viable.
- **ADR-013 option (b): embed `ort` plus a from-scratch Rust reimplementation of Laya's
  pre/post-processing.** Keeps every process Rust and avoids a sidecar dependency. Rejected: it
  turns "integrate a named model" into "re-derive and maintain, in a second language, logic that
  already exists and is maintained upstream" — the exact maintenance-surface argument ADR-005's
  Rejected Alternative #3 already made against embedding, now avoidable because Q-09's
  single-language constraint applies to `guardd`'s own binary, not to every process the product
  provisions.
- **Ask Laya one open-ended `choice`/`score` question covering the whole decision, and accept no
  reason text at all (drop ADR-005 item 3 outright).** Simpler than per-rule batching. Rejected:
  it satisfies the constrained-decoding guarantee but fails H-3's denial-quality gate, which
  requires naming *which rule* fired — information a single undifferentiated question cannot
  produce no matter how it is phrased.
- **Resolve this open point by inference, now, without the owner.** Rejected for the same reason
  ADR-013 gave for leaving it open: the Ollama-vs-embed-vs-sidecar choice and the reason-string
  design are both real engineering trade-offs with a cost (new sidecar dependency; corpus-format
  change) that `../01-discovery/requirements.md` and `CLAUDE.md` both say is the owner's call, not
  something to guess into existence.

---
**ADR Number**: 014
**Date**: 2026-10-04
**Author**: Claude (draft for review by Yu Fai (Aries) Ng)
**Related**: [ADR-013](013-model-and-language-resolution.md) (named Laya; raised this open point) ·
[ADR-005](005-pluggable-local-model-runtime.md) (items 2, 3, 6 amended here) ·
[ADR-004](004-layered-policy-model.md) (candidate-rule selection this ADR's per-rule checks depend
on) · [`../07-implementation/implementation-plan.md`](../07-implementation/implementation-plan.md)
H-1, H-3, H-9, H-10 (gates this ADR's figures and design feed)
