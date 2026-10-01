# ADR-011: v1 scope envelope — platforms, adapters, interface, posture

## Status
Proposed — records the product owner's confirmation session of **2026-10-02**

## Context

Discovery (`../01-discovery/requirements.md`) was drafted with eight open questions, four of them
marked as blocking approval, because the answers change the design materially rather than
cosmetically. Phase 3 (System Design) cannot start while they are open: Q-02 fixes the sandbox
primitive, Q-04 fixes what Sprint 1 builds, Q-06 decides whether a UI stack is needed at all.

On 2026-10-02 the product owner answered seven of the eight. This ADR records those answers as a
single scope envelope, because several of them interact — the platform answer changes what the
adapter answer costs, and the interface answer changes what language the product needs.

This ADR does not re-argue the decisions it records. Where an answer has consequences the owner did
not weigh explicitly, those are stated under Consequences and flagged, not silently absorbed.

## Decision

| # | Question | Answer | What it closes |
|---|---|---|---|
| Q-02 | Target platforms | **macOS and Linux, both properly tested. Windows is declared unsupported in v1.** | ADR-008's primitive table resolves to Seatbelt (macOS) and Landlock + seccomp + netns (Linux) |
| Q-03 | Threat model | **An agent that errs**, not one actively trying to escape | ADR-008's conditional recommendation; confinement by allowlist is sufficient |
| Q-04 | First integration | **Two adapters at ship: one hook-based (Claude Code) and the vendor-neutral MCP proxy** | ADR-007's Sprint-1 scope; the `CliAdapter` contract is validated against two different integration shapes |
| Q-05 | Distribution | **Single-user local tool** | No baseline/project policy layering, no policy distribution, no central management in v1 |
| Q-06 | Interface | **CLI and config file, plus a TUI audit viewer** | ADR-010 item 2; no web UI, no browser, no asset-serving path |
| Q-07 | Timeline | **Side project, intermittent** | Sprints must each land something independently useful and survive long gaps |
| Q-08 | Day-one posture | **Enforcing immediately** — no dry-run grace period | FR default mode; `guard dry-run` remains available voluntarily |
| Q-01 | Local model | **Still open.** "laya" is a specific model the owner has in mind, not a Llama-class placeholder | ADR-005 stays blocked |

Derived decisions, following directly from the above:

1. **Windows is out of scope for v1 and no Windows boundary claim is published.** Per ADR-008 item
   3, a claim without a passing adversarial test is deleted from the threat model. Untested means
   unsupported, stated plainly, not quietly shipped.
2. **The CI matrix must run the adversarial suite on both macOS and Linux**, on real kernels. If
   hosted runners cannot exercise Seatbelt or Landlock reliably, that is a Sprint-1 finding that
   changes the platform answer, not something to paper over.
3. **The two-layer policy precedence (baseline narrow-only) drops out of v1** as a consequence of
   single-user distribution, but the precedence *resolver* stays, since deterministic-over-model
   and specific-over-general precedence is still needed (ADR-004).
4. **Stories gated on team distribution (S-11, S-12, S-23) move to post-v1**, and the personas they
   served (Miguel, platform/DevEx) are explicitly not v1 personas.
5. **The TUI is read-only**, consistent with ADR-010 item 3: policy writes go through the CLI, so
   the write path keeps one entry point.

## Rationale

- **Windows-as-declared-unsupported rather than best-effort** is the only answer consistent with
  ADR-008. The owner's own framing was conditional — all three platforms *if we can test all three*
  — and the honest reading of "Windows untested" is that the condition fails for Windows.
- **Two adapters rather than one** is what makes the agnostic claim demonstrated rather than
  asserted. The owner's instinct was that the product should be CLI-agnostic; agnosticism is an
  architectural property of the `CliAdapter` contract, and a contract validated against exactly one
  implementation is a contract shaped by that implementation. A hook-based adapter and a proxy-based
  one are different enough in shape to force generality.
- **An erring-agent threat model keeps v1 achievable and honest.** It is also the model that matches
  the brief's own background section, which describes developers granting blanket approval to a tool
  they broadly trust, not defending against a hostile one.
- **Single-user distribution removes the largest block of v1 scope** for the smallest loss, since a
  file-based policy can be shared by convention later without a control plane.
- **A TUI is the right fit for the one surface that benefits from a GUI.** The audit log is the only
  component where a table beats a terminal dump, and a TUI delivers that without a port, a second
  process, or a frontend stack — which is what ADR-010's constraints were protecting.
- **Intermittent timeline argues for more design up front, not less**, because the context will not
  survive the gaps. It also argues for each sprint being independently shippable.

Trade-off accepted, with a reservation recorded:

- **Enforcing immediately** was chosen over a dry-run first session. This is the owner's call and it
  is defensible — it is the only posture where the product's promise holds from the first action,
  and a tool that enforces nothing while appearing to protect is the worse failure. The reservation
  is R-01: the first false denial lands before the product has earned any credit, and the brief's own
  background explains that developers switch off controls that interrupt them. The mitigation is
  therefore load-bearing rather than optional, and is listed below.

## Consequences

**Easier**

- Phase 3 can start. The sandbox primitive, the adapter set, and the interface are all fixed.
- The threat model is publishable: two platforms, one adversary class, tested claims only.
- v1 is materially smaller — no web UI, no policy distribution, no Windows.

**Harder**

- **R-01 is now the top risk.** With no dry-run grace period, the shipped default policy must be
  conservative and heavily tested before first release: every deny-class rule needs a deterministic
  matcher (ADR-004), the accuracy gate becomes a release blocker rather than a target, and
  `guard allow-once` plus a legible denial reason are the difference between a tuning annoyance and
  an uninstall.
- Two platforms means two confinement implementations and a real two-OS CI matrix from Sprint 1,
  not later.
- Two adapters at ship means two fixture sets to maintain against two vendors' release cadences.

**The team must now**

1. **Answer Q-01.** It is the only remaining blocker, and it gates ADR-005's accuracy and memory
   budgets.
2. **Resolve the language question this ADR opens** — see the open point below.
3. Amend ADR-008 to fix the primitive per platform now that Q-02 and Q-03 are answered, and write
   the `BoundaryDescription` for each.
4. Re-scope `../01-discovery/requirements.md`: Windows, team distribution, and the web UI move to
   out-of-scope; S-11/S-12/S-23 move to post-v1.
5. Promote the default-policy work and the accuracy gate to Sprint 1, since enforcing-immediately
   makes them release blockers.
6. Add WCAG 2.1 AA checks for the terminal and TUI surfaces to
   `../04-solution-design/testing-strategy.md`, which currently scopes accessibility to a web UI.

**One open point this ADR raises, for the owner to confirm**

Choosing a TUI instead of a web UI removes the only reason the product needed TypeScript.
**ADR-002's "Rust core, TypeScript UI" split is now a Rust core and a dormant TypeScript half.** The
recommendation is to make the product **single-language Rust**, with the TUI built in-process
(`ratatui`-class) and shipped inside the same static binary. That removes a Node runtime from a
security tool, makes the one-command install (S-09) genuinely one binary, and deletes the
schema-codegen build step ADR-002 introduced to keep two languages in sync. ADR-002 is still
Proposed, so this is an amendment rather than a supersession — but it is a real change and is not
applied unilaterally.

## Rejected Alternatives

- **Ship all three platforms including Windows, untested.** What the owner's first answer literally
  asked for. Rejected because it contradicts ADR-008 item 3 and the owner's own condition ("if we
  can test for all 3"): an untested boundary claim is exactly the false assurance R-04 describes.
  Windows remains on the roadmap, with AppContainer as the candidate primitive.
- **One adapter at ship, agnosticism asserted architecturally.** Cheaper, and defensible since the
  contract exists either way. Rejected: a single implementation does not prove a contract is
  general, and the agnostic claim is the product's main differentiator.
- **MCP proxy only, as the purest agnostic answer.** Rejected: it sees only MCP tool calls, leaving
  shell and filesystem actions unguarded — the false-assurance failure again, on the action classes
  that matter most.
- **Dry-run for the first session**, which was the Discovery recommendation under Q-08. Rejected by
  the owner in favour of enforcing immediately. Recorded here because the trade-off is real and the
  R-01 mitigations above are the consequence of rejecting it.
- **Defer the whole scope envelope to Phase 3** and let System Design decide these. Rejected: they
  are product decisions, not architectural ones, and Phase 3 would have had to invent answers —
  which is the failure mode ADR-001 and ADR-010 already demonstrated.
- **Record the answers only in the brief and requirements**, with no ADR. Rejected: several answers
  interact and several have consequences the answers alone do not state (Windows claims, R-01's
  promotion, the language question). A table of answers is not a decision record.

---
**ADR Number**: 011
**Date**: 2026-10-02
**Author**: Claude (draft for review by Yu Fai (Aries) Ng)
**Related**: [ADR-002](002-enforcement-core-language.md) (its TypeScript half is now dormant) ·
[ADR-004](004-layered-policy-model.md) · [ADR-005](005-pluggable-local-model-runtime.md) (still
blocked on Q-01) · [ADR-007](007-cli-integration-strategy.md) (Q-04 answered) ·
[ADR-008](008-sandbox-confinement-primitive.md) (Q-02, Q-03 answered — unblocked) ·
[ADR-010](010-supersede-adr-001-no-web-server-ui.md) (Q-06 answered; item 2 closes with a TUI) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) Q-01 … Q-08, R-01 ·
[`.ai/context/project-brief.md`](../../.ai/context/project-brief.md) Open Questions
