# ADR-013: Laya named as the local model; single-language Rust confirmed

## Status
Proposed — records the product owner's resolution session of **2026-10-02**

## Context

Discovery (`../01-discovery/requirements.md`) carried two open questions after
[ADR-011](011-v1-scope-envelope.md) closed the other seven: **Q-01**, carried from the brief
itself, and **Q-09**, raised *by* ADR-011's Q-06 answer (a TUI leaves ADR-002's TypeScript half
with no consumer). Both were explicitly named as the sole remaining blockers on Discovery
approval (`../01-discovery/README.md`).

On 2026-10-02 the product owner answered both. This ADR records those answers, as ADR-011
recorded the prior seven — and, in the same spirit as ADR-011's "one open point ... for the owner
to confirm," surfaces a consequence of the Q-01 answer that neither ADR-005 nor the brief
anticipated, rather than resolving it unilaterally.

## Decision

| # | Question | Answer | What it closes |
|---|---|---|---|
| **Q-01** | Local model | **Laya** — Convai Innovations' open-source "System 1 decision model" ([github.com/receptron/laya](https://github.com/receptron/laya)), named by the owner as the alternative to "jev." It is **not** a chat/completion LLM: it takes a state (ticket, email, JSON object, or — for this product — a proposed action plus intent rules) and returns calibrated probabilities over three question kinds: `choice` (pick one of ≤ 20 options), `score` (expected level on an ordered scale), and `noul` (yes/no). ONNX weights, **≈ 1.7 GB fp32**, published under **Apache-2.0**; the reference wrapper is an MIT-licensed **Node.js/TypeScript** package (`onnxruntime-node`, Node 20+). Its own documentation budgets **≈ 2 GB resident RAM plus a few hundred MB per batch of questions**, and reports **≈ 140 ms for a 3-question call on Apple-silicon CPU, warm**. Input limits: ≤ 192 tokens per option, ≤ 512 tokens of state (English checkpoint). | Gives ADR-005 the pairing it deferred — but see the open point below; this is not the drop-in "an Ollama tag" scenario ADR-005's text assumed |
| **Q-09** | Single-language Rust? | **Yes.** The product is Rust end-to-end — enforcement core, CLI, and TUI (`ratatui`-class) in one static binary. No Node runtime ships in any configuration. | [ADR-002](002-enforcement-core-language.md)'s TypeScript half is **dropped**, not left dormant pending confirmation; its schema-codegen build step is **deleted** from scope, not conditionally retained |

This ADR does not re-argue either decision. Q-01's answer is a fact (which model), not a trade-off;
Q-09's was already argued in ADR-011 and ADR-002 — this records the owner's confirmation of the
recommendation both made.

## Rationale

- **Q-01 was a naming gap, not a design choice.** ADR-005's port and constrained-decoding schema
  were written to be model-agnostic; naming Laya fills in a value, it does not reopen the port.
- **Q-09's argument was already made.** ADR-002 argued the adapter-latency and memory case for
  Rust; ADR-011 observed the TUI left TypeScript with no consumer. The owner's "yes" closes an
  amendment that was already fully reasoned, pending only their sign-off.

## Consequences

**Easier**

- Discovery's sole blockers are cleared; `../01-discovery/README.md` and `requirements.md` move to
  Approved.
- ADR-002 stops hedging: one Rust workspace (`core/`, `adapters/`, `cli/`, `tui/`), no codegen
  step, no second toolchain in CI.
- FR-11's accuracy gate and the < 5 GB memory NFR now have a concrete pairing to measure against,
  once the open point below is settled.

**Harder**

- **A new open point, not present before this session**: Laya's only published runtime is Node,
  and the product now ships no Node. See below — this is new engineering scope, not a
  configuration change.

**The team must now**

1. Propagate "Approved" into `../01-discovery/README.md` and the Q-01/Q-09 rows of
   `requirements.md`.
2. Amend [ADR-002](002-enforcement-core-language.md) to drop the hedge language ("amendment
   pending") and finalize the single-workspace decision.
3. Resolve the open point below — a decision ADR-005 needs before Sprint 1 can size the model
   integration task — before `../07-implementation/` treats the model runtime as a known quantity.
4. Update the Phase 3/4 documents that carried Q-01/Q-09 as open assumptions (`architecture.md`
   A-1/A-2, `component-design.md`, `routing.md`, `testing-strategy.md`) to reflect both as answered.

## One open point this ADR raises, for the owner to confirm

> **Resolved 2026-10-04 by [ADR-014](014-laya-serving-resolution.md).** Neither of the two options
> below was taken — the owner's session that day found a third: run Laya's own reference server as
> a provisioned local sidecar, which needs neither an Ollama tag nor a Rust reimplementation. The
> options as originally posed are left below unedited, as this ADR's record of what was considered
> at the time.

Naming Laya resolves Q-01's text but exposes a mismatch neither ADR-005 nor the brief anticipated.
ADR-005 decision item 2 defaults to **"an Ollama-class local server"** for v1, and its Rejected
Alternatives list **"embedding an inference library directly in the daemon"** as rejected for v1
on maintenance-surface grounds. Laya fits neither cleanly:

- **It is not Ollama-servable.** Ollama serves GGUF-format chat/completion models over an HTTP API.
  Laya ships ONNX weights with a bespoke pre/post-processing contract (state framing, the
  `choice`/`score`/`noul` encodings) — there is no Ollama tag for it, and it is not the kind of
  model Ollama runs.
- **ONNX itself is runtime-portable.** A Rust process can load the same `.onnx` weights directly
  through the `ort` crate (Rust bindings to ONNX Runtime) with no Node involved. But the
  pre/post-processing the Node wrapper implements — prompt/state templating, tokenisation, the
  three question-type encodings — has no existing Rust port. It would have to be reimplemented
  from the `receptron/laya` npm package's source, by this product, before Laya could be called
  in-process from the Rust core.
- That reimplementation is exactly ADR-005's rejected alternative #3 — but that alternative was
  weighed against a generic, Ollama-servable chat model, not against a model whose *only* existing
  runtime is Node. With Q-09 now closing out Node entirely, "run Laya via its reference
  implementation" and "ship single-language Rust, no Node" cannot both hold simultaneously.

Two ways to resolve it — **neither is applied by this ADR**:

- **(a) Keep ADR-005 item 2 as written (Ollama-class server); do not special-case Laya.** Treat
  "laya" as the owner's intent (a small local System-1-style decision model) rather than a literal
  binary dependency, and select an Ollama-servable model that fills the same role. Cheapest, and
  keeps ADR-005 unamended — but it is not literally the model the owner named.
- **(b) Amend ADR-005 item 2 for this pairing specifically.** Embed `ort` plus a from-scratch Rust
  reimplementation of Laya's pre/post-processing, in-process, no server, no Node. This is what
  naming Laya actually implies, but it turns "integrate the model" from a config value into a
  Sprint-1-sized engineering task, and ADR-005's rejected alternative #3 needs its own amendment to
  carry this exception.

This is recorded as an open point rather than resolved here because it is a real consequence of
the answer the owner gave, not a design choice open to inference — `../01-discovery/requirements.md`
and `CLAUDE.md` both say not to resolve Q-01/Q-09-class questions without the owner. **ADR-005 is
not amended by this ADR.**

## Rejected Alternatives

- **Fill in Q-01/Q-09 directly in `requirements.md` and the ADRs they gate, with no dedicated
  ADR.** Cheaper. Rejected for the same reason ADR-011 gave for the same choice: the Q-01 answer
  has a consequence (the Ollama-vs-embedded tension) that the answer text alone does not state, and
  a table of answers is not a decision record.
- **Resolve the Ollama-vs-embedded tension here, by inference, to unblock Sprint 1 sizing
  immediately.** Rejected: it is an architectural trade-off (maintenance surface vs. literal
  fidelity to the named model) that ADR-005 explicitly reserved for the owner, and guessing it
  risks sizing Sprint 1 against the wrong one.
- **Treat Q-01's answer as closing ADR-005 outright.** Rejected: ADR-005's port, constrained-
  decoding schema, and fail-closed behaviour on malformed output are unaffected by which model
  fills the port; only decision item 2 (the serving mechanism) is in question.

---
**ADR Number**: 013
**Date**: 2026-10-02
**Author**: Claude (draft for review by Yu Fai (Aries) Ng)
**Related**: [ADR-011](011-v1-scope-envelope.md) (recorded the prior seven answers; raised Q-09) ·
[ADR-002](002-enforcement-core-language.md) (Q-09 target — single-language Rust) ·
[ADR-005](005-pluggable-local-model-runtime.md) (Q-01 target — model named; serving mechanism
resolved by [ADR-014](014-laya-serving-resolution.md)) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) Q-01, Q-09 ·
[`../01-discovery/README.md`](../01-discovery/README.md) (both were its sole blockers)
