# ADR-005: Pluggable local model runtime with constrained decoding

## Status
Proposed

## Context

The intent layer (ADR-004) needs a small model running locally. The brief names "laya"/"jev" and
records the exact choice as an open question (Q-01). **Q-01 is now answered**
([ADR-013](013-model-and-language-resolution.md), 2026-10-02): the model is **Laya**, Convai
Innovations' open-source "System 1 decision model"
([github.com/receptron/laya](https://github.com/receptron/laya)) — not a chat/completion LLM in
the Llama/Gemma/Qwen class this ADR originally assumed. It takes a state and returns calibrated
probabilities over `choice`, `score`, and `noul` (yes/no) questions; ONNX weights, ≈ 1.7 GB fp32,
Apache-2.0; the only published runtime is an MIT-licensed Node.js/TypeScript wrapper
(`onnxruntime-node`, Node 20+), budgeting ≈ 2 GB resident RAM and reporting ≈ 140 ms for a
3-question call on warm Apple-silicon CPU. That naming raised a serving-mechanism question this
ADR had not anticipated, and a reason-string mismatch (Laya generates no free text at all) —
both **resolved 2026-10-04** by [ADR-014](014-laya-serving-resolution.md); see the amended
decision items 2, 3, and 6 below. What was never open, regardless of how those resolved:

- **No network in the decision path** (FR-12, Privacy NFR). The model runs on the machine.
- **P95 < 300 ms, P99 < 800 ms** for a model-path decision, on a laptop also running an IDE and the
  agent itself.
- **< 5 GB resident** including the model, on a 16 GB floor.
- **4 concurrent sessions** sharing one runtime.
- **One-command install** must provision the runtime (S-09, FR-24), in under 5 minutes on a clean
  machine.
- The model reads **untrusted content** — command output, file contents, fetched pages — and that
  content will sometimes be an attempt to manipulate it (R-02, S-16).
- Local model tooling is moving fast; anything chosen today will be second-best within a year.

## Decision

1. **Abstract the runtime behind a `LocalModelRuntime` port.** The evaluator depends on the port,
   never on a specific server, API shape, or model.
2. **Serve Laya through its own reference server, provisioned and supervised as a local sidecar
   process — not Ollama, not embedded in the Rust binary.** *(Amended by
   [ADR-014](014-laya-serving-resolution.md), 2026-10-04 — superseding the Ollama-class default
   below, which was written before the model was named.)* `guard install` provisions Laya's
   reference server the way it would have provisioned Ollama; `guardd` talks to it as a concrete
   implementation of the `LocalModelRuntime` port over loopback HTTP. ~~Default to an Ollama-class
   local server for v1, selected because it is the lowest-friction thing to provision in `guard
   install`.~~
3. **Constrained decoding, always — and for Laya specifically, no free-text channel exists to
   constrain.** *(Amended by [ADR-014](014-laya-serving-resolution.md): Laya is non-autoregressive
   and emits only typed, calibrated probabilities, never generated text. The evaluator asks one
   `noul` yes/no question per candidate intent rule and templates the reason string itself from
   whichever rule(s) crossed threshold — the model never produces the reason.)* The model's output
   is confined to a small schema — a `DecisionKind` enum, a confidence number, and (engine-composed,
   not model-generated) a reason string. The model cannot emit a command, a path, a tool name, or
   anything the engine would act upon.
4. **Model input is framed as untrusted data.** The action and the intent rules are passed in
   clearly delimited, explicitly-untrusted regions; the model is never given instructions sourced
   from the content it is judging.
5. **Malformed, out-of-schema, or timed-out output yields `deny`**, recorded with reason
   `EVALUATOR_UNAVAILABLE` or `EVALUATOR_SATURATED`. There is no retry-until-parseable loop and no
   free-text fallback path.
6. **Bounded work queue with a fixed worker count** sized to the runtime, round-robin across
   sessions. Queue wait and inference time are recorded separately so a latency regression is
   attributable. *(Amended by [ADR-014](014-laya-serving-resolution.md): each decision's per-rule
   `noul` checks are issued to Laya as one batched call, never one call per rule — batched
   per-question cost, not single-question cost, is what the P95 budget below was checked against.)*
7. **A recorded-response stub** implements the same port for integration tests; the real runtime is
   exercised only in the accuracy and performance gates.
8. **The model is never the sole gate on a catastrophic action** — guaranteed by ADR-004, restated
   here because it is the reason this ADR can accept a small model at all.
9. **The port declares what provisioning wrote to disk**, so removal can undo it: `guard install`
   provisions the runtime and weights, and `guard uninstall --purge` deletes them (FR-27). Weights
   are multi-gigabyte, so leaving them behind silently is a real cost — but deleting them on a plain
   `uninstall` is also wrong, because a reinstall would re-download them and `install`'s 5-minute
   budget (S-09) assumes it may not have to. Plain removal therefore **retains** the weights and
   prints their path and size; `--purge` removes them. A runtime the product did not install (an
   Ollama the developer already ran) is never removed, only de-referenced — which the port must be
   able to distinguish, so provisioning records whether it installed the runtime or adopted one.

## Rationale

- **The port is the whole point.** Every specific choice here has a short shelf life; the boundary
  does not. Swapping runtime or model must be a configuration change plus a corpus re-run, not a
  refactor.
- **Constrained decoding converts prompt injection from a code-execution risk into a wrong-answer
  risk.** If the model can only say `allow|deny|ask|mask` plus a number and a string, the worst a
  successful manipulation achieves is one incorrect decision — which the deterministic layer already
  backstops for every catastrophic class. This is the single highest-value property in this ADR.
- **Deny on malformed output** keeps the fail-closed posture (ADR-009) intact at the one place an
  engineer is most tempted to add a lenient fallback.
- **A bounded queue is required by the numbers.** Four sessions against one runtime cannot each get
  native latency; the choice is between bounded queueing with honest denial under saturation and
  unbounded latency growth. The latter is R-03.
- **Separating queue wait from inference time** is what makes the P95 budget debuggable rather than
  a single number nobody can act on.
- **A recorded-response stub** keeps integration tests deterministic and fast, and lets the CI
  stages that must prove FR-12 run with networking disabled entirely.

Trade-offs accepted:

- **A port is an abstraction over things that differ meaningfully** — tokenisation, context
  windows, constrained-decoding support. The port will leak, and capability probing at startup is
  required rather than optional.
- **A sidecar server as the default adds an external dependency to the install path** (Laya's
  reference server in place of Ollama, per [ADR-014](014-laya-serving-resolution.md)), which is a
  real failure surface for S-09's 5-minute budget.
- **Accuracy is model-specific.** The FR-11 numbers are a property of the pairing, so the corpus
  must be re-run on any model change; swapping models is not a free configuration change.

## Consequences

**Easier**

- Changing model or runtime later without touching the evaluator.
- Deterministic, offline, fast integration tests.
- Bounding the blast radius of a successful prompt injection against the evaluator.
- Reporting model availability honestly in the health check (FR-23).

**Harder**

- Install robustness: provisioning a runtime and pulling a model inside 5 minutes, with a clear
  failure path when it cannot.
- Capability detection: a runtime without constrained-decoding support must be rejected at startup
  rather than silently degraded to free-text parsing.
- Accuracy bookkeeping: corpus results become per-(model, runtime, prompt) and need versioning.

**The team must now**

1. ~~Answer Q-01~~ **Done** — the model is Laya ([ADR-013](013-model-and-language-resolution.md)).
   ~~The accuracy and memory numbers are still not verifiable until the serving-mechanism open
   point in decision item 2 is settled~~ **Done** — served via its own sidecar
   ([ADR-014](014-laya-serving-resolution.md)). Laya's published figures are still only
   secondary-source estimates; ADR-014 requires re-measuring them directly against the package at
   the start of S-6, before the performance-gate baseline (#5 below) is recorded.
2. Define the constrained-decoding schema in Phase 3's `api-design.md` and make rejection of a
   runtime that cannot honour it a startup check.
3. Build the recorded-response stub alongside the first real integration (not after).
4. Add the model-manipulation cases from `../04-solution-design/testing-strategy.md` §2.2 as the
   evaluator's own adversarial suite.
5. Record the chosen pairing's measured P95, RSS, and corpus scores as the baseline the performance
   gate enforces.

## Rejected Alternatives

- **A remote/hosted model API** (any provider). Best accuracy per millisecond of engineering, no
  local resource cost. Rejected on a hard requirement: FR-12 and the Privacy NFR forbid a network
  call in the decision path, and sending the action being judged — commands, paths, file content —
  to a third party is precisely the leak the product exists to prevent. Not a trade-off; a
  contradiction of the premise.
- **Hard dependency on one specific runtime and model, no abstraction.** Simpler, faster to build,
  and the accuracy numbers would be exactly measurable. Rejected: `.ai/context/project-brief.md`
  explicitly forbids a hard dependency on one model, and the field moves fast enough that this
  choice would be wrong within a release or two.
- **Embedding an inference library directly in the daemon** (llama.cpp-class, linked in). Removes
  the external process and the install dependency, and would lower latency. Rejected for v1
  *as a general policy*: it puts model-format compatibility, GPU/accelerator handling, and update
  cadence inside our binary, which is a large maintenance surface for a latency gain that the
  ≥ 80 % no-model share already makes uncritical. **Reopened as option (b) for Laya specifically**
  by [ADR-013](013-model-and-language-resolution.md) (embed `ort` plus a from-scratch Rust
  reimplementation of Laya's pre/post-processing), and **rejected again, finally, by
  [ADR-014](014-laya-serving-resolution.md)** in favour of running Laya's own reference server as
  a sidecar — the maintenance-surface argument against embedding applies just as much to
  reimplementing Laya's pre/post-processing from scratch as it did to the original llama.cpp case.
- **Free-text model output parsed with a regex or a JSON-repair pass.** More flexible, gives richer
  reasons. Rejected outright: it reopens the possibility of the model emitting something the engine
  acts on, and a repair pass on adversarially-shaped output is a vulnerability, not a convenience.
  Laya's actual output has no free-text channel at all to parse — [ADR-014](014-laya-serving-resolution.md)
  templates the reason from the engine's own rule text instead, which is this rejection's logic
  taken to its conclusion rather than an exception to it.
- **Retrying on malformed output until it parses.** Rejected: it converts a deny into an eventual
  allow given enough attempts, silently inverting the fail-closed posture, and it blows the latency
  budget while doing so.
- **Fine-tuning or shipping our own model.** Rejected — explicitly out of scope in
  `../01-discovery/requirements.md`, and it would make the product responsible for model quality
  rather than for enforcement.
- **Unbounded concurrency to the runtime.** Rejected: four sessions would degrade every session's
  latency together rather than degrading one predictably, and latency is the uninstall trigger.

---
**ADR Number**: 005
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-013](013-model-and-language-resolution.md) (Q-01 answered: the model is Laya) ·
[ADR-014](014-laya-serving-resolution.md) (decision item 2's serving mechanism resolved) ·
[ADR-004](004-layered-policy-model.md) ·
[ADR-009](009-fail-closed-default.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) FR-11–FR-14, Q-01 ·
[`../04-solution-design/state-management.md`](../04-solution-design/state-management.md) §A.5
