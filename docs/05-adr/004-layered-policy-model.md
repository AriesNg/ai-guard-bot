# ADR-004: Layered policy — deterministic rules decide first, intent rules fill the gap

## Status
Proposed

## Context

This is the product's central design decision. The premise
(`.ai/context/project-brief.md`, Background) is that developers disable AI CLI guardrails because
per-action prompts interrupt them and per-tool allow-lists cost more effort than they return. The
proposed answer is a handful of plain-language rules interpreted by a local model.

Taken literally, that answer has a fatal property: **a small local model would be the only thing
between the agent and an irreversible action.** Discovery records this as R-01, the highest-rated
risk in the project. Both error directions are fatal in different ways:

- A **false allow** on `rm -rf`, a credential read, or an exfiltrating request defeats the entire
  product.
- A **false deny** rate a developer notices makes the tool annoying, and an annoying guardrail gets
  uninstalled — the exact failure mode of the prompts it replaces.

Meanwhile FR-11 requires ≥ 80 % of actions to be resolved without the model at all, to keep the
model off the hot path (P95 < 20 ms deterministic vs < 300 ms model), and FR-03 requires that rule
conflicts resolve deterministically with the winning rule recorded.

So the policy model must deliver intent-level authoring *without* making a probabilistic judgement
the sole gate on catastrophic actions.

## Decision

A **layered policy** with a fixed, total precedence order.

1. **Two rule kinds in one policy file.**
   - `IntentRule` — plain language, no tool names, commands, or globs required (FR-01). Carries a
     `confidenceThreshold`.
   - `DeterministicRule` — literal matching on action kind, command, path, destination, or content
     (FR-02).
2. **Deterministic rules are evaluated first and short-circuit.** The model is invoked only for
   actions no deterministic rule and no hook decided (FR-11).
3. **Every catastrophic action class MUST be covered by a deterministic rule in the shipped default
   policy.** Credential and key paths, destructive filesystem commands, privilege escalation,
   history rewriting, and egress to non-allowlisted hosts. The model is never the only gate on an
   irreversible action. This is a shipping requirement, not a recommendation, and is asserted by a
   test over the default policy.
4. **Fixed precedence, asserted as a total order**: `deny` > `mask` > `ask` > `allow`; within a
   decision, `deterministic` > `hook` > `model`; within deterministic, more-specific match >
   less-specific; within equal specificity, `baseline` > `project`. Policy validation **fails** if
   two rules are indistinguishable under this ordering — a tie is a bug, not a coin flip.
5. **`ask` is the model's uncertainty outcome.** Below its rule's `confidenceThreshold`, a model
   evaluation yields `ask`, never a guess in either direction.
6. **Baseline may only be narrowed, never widened** (FR-05); a project policy that widens fails to
   load with `POLICY_WIDENS_BASELINE`.
7. **The winning rule ids are recorded on every decision** (FR-19), so every outcome is
   attributable to a rule a human wrote.
8. **The accuracy of the intent layer is a CI gate**, not a hope: ≥ 95 % deny recall and ≤ 2 %
   false-deny against a ≥ 500-entry versioned corpus, with a held-out slice, and a false-deny
   regression fails the build even if deny recall improves.

## Rationale

- **It separates the authoring experience from the enforcement guarantee.** The developer still
  writes five lines of English (S-01); they simply are not the only thing standing between the
  agent and disaster. The product's promise is kept without its central risk being load-bearing.
- **Deterministic-first is what makes the latency budget reachable.** ≥ 80 % of a real session's
  actions are repetitive file reads and routine commands that literal rules settle in microseconds.
  Without this layering, R-03 (latency → uninstall) becomes unavoidable.
- **`ask` as a first-class middle outcome** converts model uncertainty into a rare, high-value
  interruption instead of a coin flip. The failure mode of prompts was their *frequency*, not their
  existence — asking twice a day is a different product from asking twice a minute.
- **A total order makes decisions explainable and reproducible.** Same action, same policy version,
  same outcome, always, with a named rule. This is what makes the audit log usable as evidence and
  what lets an agent adapt to a denial (S-04) rather than retry blindly.
- **Narrow-only layering is what lets a platform team ship a baseline** (S-12) without engineers
  quietly disabling it.

Trade-offs accepted:

- **Two rule kinds is more concept than one.** Mitigated by the shipped default policy carrying the
  deterministic layer, so most users only ever author intent rules and never see the other kind.
- **The deterministic catastrophic-class list must be maintained** as new dangerous commands appear.
  This is real ongoing work and is the price of not trusting the model with irreversible actions.
- **Specificity comparison must be well-defined** for the total-order assertion to hold, which
  constrains what the matcher language may express.

## Consequences

**Easier**

- Meeting FR-11's latency split and the ≥ 80 % no-model share.
- Explaining any decision: a rule id and a reason, every time.
- Shipping a useful default policy with zero authoring (R-06, persona P4 in
  `../01-discovery/user-personas.md`).
- Reviewing a policy like code (S-18): the deterministic layer is diffable and unambiguous.

**Harder**

- Policy validation must implement and prove a total order, including specificity comparison.
- The catastrophic-class deterministic list needs an owner and a review cadence.
- Two authoring surfaces to document, and a story for when they disagree (they cannot, by
  precedence, but users will ask).

**The team must now**

1. Write the default policy's deterministic catastrophic-class rules, with a test asserting every
   class is covered — this is a Sprint-1-adjacent deliverable, not a later refinement.
2. Implement precedence as a resolver with a property test over arbitrary rule sets
   (`../04-solution-design/testing-strategy.md` §1).
3. Build the ≥ 500-entry evaluation corpus with a held-out slice before the intent layer is trusted.
4. Define the specificity relation formally in Phase 3's `api-design.md`.
5. Answer Q-08 (enforce vs dry-run on day one) — the recommendation of dry-run for the first
   session exists precisely to measure this layer's false-deny rate on real work.

## Rejected Alternatives

- **Model-only evaluation.** The literal reading of the original request, and the best possible
  authoring experience: write intent, nothing else exists. Rejected because it makes a small local
  model the sole gate on irreversible actions (R-01) and puts inference on every action, breaking
  the latency budget and with it R-03. A guardrail that is probabilistic about `rm -rf /` is not
  one a developer can grant broad autonomy behind, which is the product's stated success condition.
- **Deterministic rules only** (a better allow-list tool). Fast, fully explainable, zero model
  risk. Rejected: it is the status quo the Background section identifies as failing — authoring
  cost is front-loaded and never finished. It would be a better version of the thing users already
  refuse to use.
- **Model first, deterministic rules as a post-check.** Considered: let the model judge, then
  veto with literal rules. Rejected: it pays model latency on every action for no additional
  safety, since the veto is what actually provides the guarantee.
- **Model compiles intent rules into deterministic rules ahead of time.** Attractive — intent
  authoring, deterministic enforcement, no inference on the hot path. Rejected for v1 as a
  *replacement*, because compilation cannot anticipate every concrete action, so the residual
  must still be decided at run time; it also moves the model's errors into a generated artefact
  that looks authoritative. Worth revisiting as an *optimisation* that pre-warms the deterministic
  layer, with generated rules clearly marked and reviewable.
- **Ask on everything uncertain, with no model.** Rejected: uncertainty is the common case for
  literal rules, so this degenerates into the vendor prompt — the product's stated problem.
- **Priority numbers on rules instead of a fixed precedence order.** Familiar from firewall
  configuration. Rejected: it makes correctness the author's problem, invites ties, and makes the
  effect of a baseline unpredictable when a project policy renumbers.
- **Last-match-wins or first-match-wins ordering.** Rejected: both make a policy's meaning
  depend on file order, so appending a rule can silently weaken an earlier deny — unacceptable
  when a baseline is meant to be un-weakenable (FR-05).

---
**ADR Number**: 004
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-005](005-pluggable-local-model-runtime.md) ·
[ADR-009](009-fail-closed-default.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) FR-01–FR-05, FR-11, R-01 ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) §2.2–2.3
