# ADR-009: Fail-closed by default, implemented as a default value rather than a branch

## Status
Proposed

## Context

Things will fail mid-session: the model runtime dies or saturates, a user hook times out, the audit
write fails, the policy reload finds a typo, an adapter receives a payload shape it cannot parse, an
action class turns out not to be interceptable on this host.

Each failure needs an answer to one question: **does the action proceed?**

The forces:

- Answering "yes" makes the guardrail weakest exactly when the machine is most stressed — and
  silently, since the developer has granted broad autonomy precisely because something is watching.
- Answering "no" halts the developer's session on any component failure, which is disruptive and is
  itself an uninstall risk (R-03's logic applied to reliability).
- The Availability NFR already states the intended posture: fail-closed by default, configurable
  per rule, with every fail-open decision logged as such.
- The Availability NFR also requires that a halt costs no work: *if the engine dies, the guarded
  agent stops acting; it does not lose work.*
- Software has a strong gravitational pull toward the lenient branch: `if (!decision) allow` is one
  character from correct and impossible to spot in review.

## Decision

1. **Fail-closed is the default for every unevaluable action.** No decision means `deny`.
2. **It is implemented as the pipeline's initial value, not as a branch.** The evaluation pipeline
   starts holding `deny` with reason `EVALUATOR_UNAVAILABLE`; evaluators may only *replace* that
   value. **There is no code path in which the absence of a decision yields an allow**, because
   absence is not a state the pipeline can be in.
3. **Fail-open is opt-in per rule and requires a written justification** in the policy:
   `failOpen: { justification: string }`. It cannot be set globally, and it cannot be set as a bare
   boolean.
4. **Every fail-open decision is logged as such**, with the rule id and its justification, so the
   audit log distinguishes "allowed because permitted" from "allowed because we could not tell".
5. **Failure of the audit write is itself a deny** (ADR-006). An action that cannot be recorded does
   not execute.
6. **Saturation denies rather than queues indefinitely**: model-queue overflow yields `deny` with
   `EVALUATOR_SATURATED` and its own metric (ADR-005).
7. **Hook timeout or crash yields `deny`, never a skip**, and is recorded as a distinct event.
8. **Coverage gaps deny** the affected action class (ADR-007, FR-10).
9. **A failed policy reload keeps the previous policy** and logs the rejection. It does not fall
   back to "no policy", which would deny everything and halt a session over a typo.
10. **Denial is legible and actionable**: every fail-closed denial carries a stable error code and a
    reason saying *why the engine could not tell*, distinct from a rule violation, so the developer
    knows to check the engine rather than their rules — and so the agent does not treat it as a
    policy boundary to work around.
11. **The adapter applies a timeout with a fail-closed default**, so an unresponsive daemon denies
    rather than hanging the developer's session indefinitely (ADR-003).
12. **Uninstall is the one lifecycle operation that must not be fail-closed, and the ordering is
    what guarantees it.** Fail-closed means a registered adapter with no engine denies everything,
    so teardown de-registers every adapter **before** stopping the daemon, and aborts with the
    daemon still running if any adapter cannot be de-registered
    (`../04-solution-design/routing.md` §2.1, ADR-007 items 10–12, FR-27). There is no "fail-open
    during shutdown" mode: the guard is either present and enforcing, or absent and not registered.
    The invariant is that **no state exists in which a hook is registered and the engine is gone**.

## Rationale

- **The product's promise is conditional on the guard being present.** A developer grants broad
  autonomy *because* something is watching. Allowing when the watcher cannot see silently voids that
  condition, and silence is the part that makes it dangerous: the session looks identical.
- **Failures correlate with stress, and stress correlates with risk.** Saturation happens during
  heavy agent activity — the moment when the most actions are attempted and the least supervision is
  available. Fail-open concentrates unguarded execution exactly there.
- **Making it a default value rather than a branch removes an entire class of bug.** Any missed
  branch, early return, or unhandled error path lands on `deny`. This is the difference between a
  posture that is stated and one that is structural, and it is the most important sentence in this
  ADR.
- **Requiring a justification string for fail-open** makes the exception visible in policy review
  (S-18) and makes it awkward to add casually. A boolean flag would be set once and forgotten.
- **Keeping the previous policy on a failed reload** is the one place leniency is correct: the
  previous policy is a known-good, human-approved artefact, so using it is not an unsupervised
  action — it is the supervised one.
- **Distinguishing "could not evaluate" from "violated a rule"** matters for both audiences: the
  developer needs to know to restart the runtime rather than rewrite rules, and the agent must not
  learn to treat an outage as a boundary to route around.

Trade-offs accepted:

- **A component failure halts productive work.** This is the real cost, and the correct mitigation
  is engine reliability (the < 5 s crash-recovery target), not leniency.
- **Saturation denials may be surprising** under heavy parallel use, and will read as flakiness
  unless the reason is clear — which is why the reason text is part of the decision, not an
  afterthought.
- **Fail-closed turns an incomplete uninstall into a bricked host CLI**, which is why removal is
  specified as carefully as enforcement. Every other fail-closed consequence is recoverable by
  fixing the guard; this one is reached *by removing the guard*, so the usual remedy has already
  been taken away and the error has no author left to blame. It is the strongest argument for
  pairing `uninstall` with `install` in the adapter contract rather than documenting manual removal
  steps.
- **Fail-closed can mask a misconfiguration as a policy problem** if the error codes are not
  distinct, which is why item 10 is a requirement rather than a nicety.

## Consequences

**Easier**

- Reasoning about the security guarantee: there is no state in which an unevaluated action ran.
- Reviewing the code — the lenient path does not exist to be reviewed.
- Auditing: `allowed because permitted` and `allowed because we could not tell` are different
  records.

**Harder**

- Reliability becomes a product requirement rather than an operational nicety: every crash is now a
  work stoppage.
- Error-message quality becomes load-bearing; a bad message turns a correct denial into a support
  burden and an uninstall.
- Capacity planning for the model queue matters more, since overflow is user-visible as denial.

**The team must now**

1. Implement the pipeline's initial-value pattern and add a test asserting that removing every
   evaluator yields `deny` — the canary for this whole ADR.
2. Give each fail-closed cause its own stable error code (`EVALUATOR_UNAVAILABLE`,
   `EVALUATOR_SATURATED`, `HOOK_TIMEOUT`, `COVERAGE_GAP`, `AUDIT_WRITE_FAILED`) and a reason that
   names the remedy.
3. Meet the < 5 s crash-recovery target, and auto-restart the daemon on adapter connect.
4. Add the "kill the model runtime mid-session" E2E journey
   (`../04-solution-design/testing-strategy.md` §5, case 5) and the saturation case to the
   adversarial gate.
5. Size the model queue against the 4-session target so saturation is rare in normal use.
6. Add the uninstall-ordering test to the adversarial gate: kill the process mid-teardown at each
   step and assert the host CLI is left either fully guarded or fully unguarded, never with a
   registered hook and no engine (`../04-solution-design/testing-strategy.md` §5, case 12).

## Rejected Alternatives

- **Fail-open by default.** Never blocks the developer; failures are invisible and productivity is
  preserved. Rejected: it makes the guarantee unsound in exactly the conditions where it matters,
  and it does so silently. It would also make every reliability bug a security incident, which
  inverts the severity of the engineering work.
- **Fail-open with a warning.** The pragmatic middle: log loudly, proceed. Rejected because warnings
  during an autonomous agent session are not read — the product exists because developers stopped
  reading permission prompts. A control the user is expected to notice in real time is a control
  that does not work.
- **Global fail-open switch for the impatient user.** Rejected: it would be the first thing turned
  on after a frustrating denial, and it would turn off the product while leaving it installed,
  producing an audit log that implies protection that is not there. `guard dry-run` already serves
  the legitimate version of this need (observed, logged, not enforced) without the false assurance.
- **Fail-closed with an automatic time-boxed retry before denying.** Considered: absorb a transient
  runtime blip. Rejected for the hot path — it spends the latency budget on every failure and, if
  retried enough, converts a deny into an eventual allow, inverting the posture. Transient recovery
  belongs in daemon supervision, not in the decision path.
- **Fail-closed as an `if` at the end of the pipeline.** The conventional implementation. Rejected
  on defensive grounds: every future early return or error path becomes a potential silent allow, and
  that bug is invisible in review. The initial-value pattern costs nothing and forecloses it.
- **Deny everything on a failed policy reload** (treat "no valid policy" as "no permissions").
  Rejected as over-application: it halts a session over a typo when a known-good, human-approved
  previous policy is in hand. The previous policy is a supervised state, not an unsupervised one.

---
**ADR Number**: 009
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-003](003-local-daemon-over-unix-socket.md) ·
[ADR-004](004-layered-policy-model.md) · [ADR-005](005-pluggable-local-model-runtime.md) ·
[ADR-006](006-audit-log-integrity.md) · [ADR-007](007-cli-integration-strategy.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) S-08, S-25, FR-10, FR-27, Availability NFR ·
[`../04-solution-design/state-management.md`](../04-solution-design/state-management.md) §A.5
