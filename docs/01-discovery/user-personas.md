# 01 — Discovery: User Personas

**Status**: Draft
**Last updated**: 2026-09-28
**Approved by**: _pending_

Companion to [`requirements.md`](requirements.md). Four personas; each maps to specific user
stories and, where the persona would reject the product, says what that rejection looks like.

---

## P1 — Dana, the autonomy-first senior engineer

*Primary persona. If Dana uninstalls it, the product has failed.*

| | |
|---|---|
| **Role** | Senior product engineer, 18-person startup, ships to production daily |
| **Technical level** | Expert. Comfortable with shell, containers, and hand-written CI. Will read a config file; will not maintain a list of glob patterns. |
| **Environment** | macOS laptop, 32 GB. One AI CLI open most of the working day, often two. Repo holds `.env` files with staging credentials; her shell has an authenticated cloud CLI session. |

**Goals**

- Let the agent work in long, uninterrupted stretches — multi-file refactors, test runs, dependency upgrades.
- Not think about safety during the work; think about it once, up front.
- Keep her own trust in the tool: she wants to *know* it cannot `rm -rf` the wrong directory, not hope so.

**Pain points**

- She runs with permissions skipped. She knows this is wrong and has decided the prompts cost more.
- The one time she tried the CLI's allow-list settings, she spent 40 minutes and still hit prompts, so she reverted.
- She has no idea what any past session actually touched.
- A near-miss (agent deleted an untracked scratch directory with a day's notes) is what would make her try this product.

**What she needs from v1**

- Install-to-enforcing in minutes, one command (S-09).
- Rules she can write in five lines of English (S-01).
- Silence in the common case — if it interrupts her as often as the vendor prompt, it is the same product she already rejected (S-03).
- The catastrophic cases blocked deterministically, not probabilistically (FR-11, R-01).

**Stories**: S-01, S-02, S-03, S-04, S-05, S-06, S-08, S-09, S-10, S-15, S-17

**She rejects it if**: it adds noticeable latency to her session, asks her more than a couple of
times a day, or blocks something reasonable and leaves her editing rules mid-task.

---

## P2 — Miguel, the platform / DevEx engineer

> **Not a v1 persona** (confirmed 2026-10-02). Q-05 scoped v1 to a **single-user local tool**, and
> every one of Miguel's needs — a distributed baseline, uniform rollout, an aggregate denial view —
> requires distribution machinery that v1 does not build. The stories written for him (S-11, S-12,
> S-23) are deferred post-v1. He is retained here unchanged because he is the reason the policy
> format, the `CliAdapter` contract, and the precedence resolver are designed to generalise: v1 must
> not foreclose him. See [`../05-adr/011-v1-scope-envelope.md`](../05-adr/011-v1-scope-envelope.md).

*Buyer and rollout owner. Decides whether the product exists at 120 engineers rather than one.*

| | |
|---|---|
| **Role** | Platform engineer, ~120-engineer company; owns internal CLIs, dev-environment bootstrap, and CI templates |
| **Technical level** | Expert. Writes the tooling everyone else consumes. Thinks in defaults, distribution, and version pinning. |
| **Environment** | Mixed macOS and Linux fleet. Engineers use at least three different AI CLIs and will not be told to standardise on one. |

**Goals**

- One policy, reviewed once, in effect on every engineer's machine regardless of which agent they chose.
- A rollout he can stage: observe first, enforce later, without a flag day.
- No new service to operate. If it needs a server, it is a much harder sell.

**Pain points**

- Every CLI has its own permission syntax, so anything he writes covers one tool and rots.
- He cannot answer his security team's question ("what governs agent behaviour?") with anything verifiable.
- Previous attempts at developer-machine controls were bypassed within a week because they were annoying.

**What he needs from v1**

- Portability of the policy across CLIs (S-11) — this is his single most important requirement.
- A baseline he ships that engineers can tighten but not loosen (S-12).
- Policy as a reviewed file in a repo, with history (S-18).
- Aggregate visibility into which rules fire, so he can remove friction rather than field complaints (S-23, P2).

**Stories**: S-11, S-12, S-14, S-18, S-23, and Dana's P0 set as a precondition

**He rejects it if**: it requires a hosted control plane in v1, or if adoption depends on each
engineer authoring their own rules.

---

## P3 — Priya, the security engineer

*Approver. Cannot be the one to make it usable, but can be the one to block it.*

| | |
|---|---|
| **Role** | AppSec lead. Writes the standards, reviews exceptions, answers audit questions. |
| **Technical level** | Strong engineer, but not the author of the agent workflows she is governing. |
| **Environment** | Reviews controls across the org. Has an existing log pipeline and expects anything new to land in it. |

**Goals**

- An actual enforcement point for AI agent activity, not a policy memo.
- Evidence: a trustworthy record she can query when asked "did an agent touch production data in Q3?".
- Assurance that developer prompts and file contents are not leaking credentials to a model vendor.

**Pain points**

- Her current control is a written policy nobody can verify compliance with.
- Banning the tools is not politically available and would not work anyway.
- She has been shown "audit logs" before that the audited process could itself edit.

**What she needs from v1**

- Append-only, tamper-evident log (S-06, FR-20) — an editable log is worthless to her.
- Structured export into her existing pipeline (S-14).
- Outbound secret and PII masking with a stated recall number, not a claim (S-05, FR-13).
- An honest threat model that says what the sandbox does *not* stop (FR-18). An absolute claim
  makes her trust the whole product less, not more.
- Every override recorded with who and why (S-15, FR-25).

**Stories**: S-05, S-06, S-07, S-14, S-16, S-21

**She rejects it if**: the audit log is writable by the guarded agent, or the product markets
itself as a complete sandbox.

---

## P4 — Tom, the multi-client agency engineer

*The persona served by defaults, not by configuration. Represents the majority of eventual users.*

| | |
|---|---|
| **Role** | Mid-level engineer at a 25-person agency; works across four client codebases in a week |
| **Technical level** | Intermediate. Uses the AI CLI heavily and effectively; has never opened its settings file. |
| **Environment** | One laptop, four client repos, four sets of client credentials, four NDAs. |

**Goals**

- Move fast across unfamiliar codebases with the agent's help.
- Not be the person who leaked client A's source or data into a session for client B.
- Not have to learn a policy language to be safe.

**Pain points**

- Does not know which of his actions are risky; would not know what rules to write.
- The agent has read files from outside the current repo before and he did not notice until later.
- Contractual obligations he cannot personally verify he is meeting.

**What he needs from v1**

- A safe default policy that is genuinely useful with zero authoring (R-06 mitigation) — this is
  the requirement Tom exists to justify.
- Repo-scoped confinement out of the box so cross-client reads simply do not happen (S-13, S-21).
- Denial messages in plain language that tell him what to do instead (S-04, FR-15).
- Masking he does not have to configure (S-05).

**Stories**: S-05, S-13, S-04, S-21 — and critically, the *default policy*, not the rule authoring

**He rejects it if**: first run presents him with an empty policy file, or a denial gives him an
error code with no explanation.

---

## Persona-to-priority check

| Story band | Dana | Miguel *(post-v1)* | Priya | Tom |
|---|---|---|---|---|
| P0 (S-01 … S-10, S-24) | ✅ all | precondition | S-05/06, S-24 essential | S-04/05 essential |
| P1 (S-13 … S-18) | S-15, S-17 | ✅ core, but deferred | ✅ core | S-13 |
| P2 (S-20 … S-22) | S-20 | — | S-21 | S-21 |
| Post-v1 (S-11, S-12, S-23) | — | ✅ his whole set | S-12 | — |

The P0 band is Dana's set, which is correct: without a single developer keeping it installed,
none of the other three personas' needs can be met. Miguel's requirements concentrate in the
post-v1 band — deliberate, and confirmed as the scope decision on 2026-10-02: a team-wide sell
before a single-user product works would be premature. Priya is served within v1, because the
append-only audit log and the read-only TUI (S-24) answer her evidence question on one machine
without any distribution.
Tom's needs are met mostly by *defaults* rather than features, which is why the default policy is
tracked as a first-class deliverable under risk R-06 rather than as a nice-to-have.

**Anti-persona (explicitly not designed for in v1)**: a CI/CD pipeline or an unattended
autonomous agent fleet. Both need central policy, machine identity, and a server-side control
plane, all out of scope per `requirements.md`.
