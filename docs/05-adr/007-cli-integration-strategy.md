# ADR-007: Per-CLI adapters over documented hook interfaces, with a coverage matrix

## Status
Proposed

## Context

The product must intercept every action of AI CLIs it does not own, whose release cadence it does
not control, and which do not agree on any integration surface. Discovery rates two risks here:

- **R-04** — incomplete interception. An action class that slips past gives *false assurance*,
  which is worse than no guardrail, because the developer has granted broad autonomy on the strength
  of it.
- **R-05** — host interfaces change or are withdrawn. Rated **high likelihood**: these are young
  tools shipping fast.

Fixed constraints:

- FR-08: integrate via the host's own hook/permission interface; **no forks or patches** of the
  host agent.
- FR-07: intercept shell commands, filesystem reads/writes, network requests, and MCP tool calls,
  before execution.
- FR-09: CLIs without such an interface must still be servable — via an MCP proxy or process-level
  interception.
- FR-10: where coverage cannot be guaranteed for an action class, **deny**, and report the gap at
  startup rather than silently.
- Adapter process start sits inside a P95 < 10 ms overhead budget (ADR-002).
- Q-04 (which CLI is supported end-to-end first) is still open.

## Decision

1. **One adapter per host CLI**, each implementing a single internal `CliAdapter` contract:
   `normalise`, `renderDenial`, `install`, plus declared `supportedVersions` and `coverage`. An
   adapter is the **only** place a vendor's payload shape is known.
2. **Integrate through the host's documented hook or permission interface** where one exists. No
   forks, no patches, no monkey-patching of the host's internals.
3. **MCP proxy as the fallback** for CLIs with no hook interface (FR-09), behind the same contract,
   so the core is unaware which path delivered the action.
4. **A per-CLI coverage matrix is a declared, first-class artefact**: for each `ActionKind`, either
   `intercepted` or `unavailable`. It is asserted at startup, reported by `health` (FR-23), and
   printed by `guard install`.
5. **An `unavailable` action class is denied**, not allowed and not ignored (FR-10). Coverage gaps
   reduce what the agent may do; they never reduce what the guard sees.
6. **Support is advertised per CLI only when its matrix is complete** for the action classes that
   CLI can perform. A partially-integrated CLI ships as explicitly experimental, with the gaps
   printed on every session start.
7. **Host versions are pinned to a declared range.** An unknown or out-of-range host version is
   detected at `session.open` and rejected with `AGENT_VERSION_UNSUPPORTED`, rather than assumed
   compatible.
8. **Recorded hook payloads per supported host version are test fixtures**, so a vendor's shape
   change fails CI rather than a user's session.
9. **Denials are rendered into the host's own response shape** by the adapter, from one
   `GuardError` (`../04-solution-design/routing.md` §1.3), so the stable error codes S-04 depends on
   are identical across hosts.

## Rationale

- **Adapters contain vendor breakage.** R-05 is high-likelihood, so the design question is not how
  to prevent breakage but how to bound it. One directory per vendor, one contract, and the core
  never learns a vendor's payload shape.
- **Deny-on-gap is the only honest handling of incomplete coverage.** The alternative — allowing
  what cannot be seen — converts a known limitation into a silent one, and silent is what makes R-04
  worse than having no guardrail at all.
- **The coverage matrix makes the product's limits legible** to the person taking the risk. A
  developer granting broad autonomy is entitled to know which action classes are actually watched.
  Publishing it also prevents the team from quietly shipping "supports X" on partial integration.
- **Version pinning turns a vendor's breaking change into a clear refusal** rather than a subtly
  mis-parsed payload — a mis-parsed action is a wrong decision, which is the worst available outcome.
- **The MCP proxy path is what keeps the vendor-agnostic promise credible**, since it does not
  depend on a vendor choosing to offer hooks.
- **Refusing to fork the host** is not only a constraint from the brief: a fork would make the
  product responsible for the host's behaviour and would be bypassed by the user's next `npm
  install -g`.

Trade-offs accepted:

- **Per-CLI work does not amortise.** Each new CLI is a real integration, not a configuration entry.
  This caps how fast the supported list can grow.
- **Coverage is bounded by what the host exposes.** Where a host offers no hook for an action class,
  the honest outcome is denial, which may make the product feel restrictive on that host.
- **Version pinning creates a lag** between a host's release and our support for it, during which
  users on the newest version are refused.
- **Fixtures must be refreshed** per host release, which is ongoing maintenance with no end date.

## Consequences

**Easier**

- Containing a vendor's breaking change to one directory and one fixture set.
- Reasoning about what is and is not guarded, from data rather than from documentation prose.
- Keeping one policy portable across hosts (S-11) — portability lives in the canonical `Action`,
  not in per-host rules.

**Harder**

- Onboarding each new CLI; the roadmap is gated on integration work per host.
- Explaining a refusal to run on a brand-new host version to a developer who just upgraded.
- Keeping fixtures current across several vendors' release cadences.

**The team must now**

1. Answer **Q-04**, which fixes the Sprint-1 adapter.
2. Write the `CliAdapter` contract before the first adapter, so the first integration does not
   become the de facto contract.
3. Build the red-team interception-bypass suite (`../04-solution-design/testing-strategy.md` §2.2)
   against the real host: relative and symlinked paths, shell chaining and command substitution, a
   shell spawned to run a blocked command, an interpreter one-liner performing a blocked write.
4. Define the coverage matrix's `ActionKind` list in Phase 3 and make an incomplete matrix a
   loud startup report, not a log line.
5. Decide the support policy for a host version outside the declared range — refuse, or run with a
   printed warning and every class degraded to `ask`. Recommendation: refuse, since a mis-parsed
   payload is a wrong decision.

## Rejected Alternatives

- **Fork or patch each host CLI** to insert interception exactly where wanted. Gives complete
  coverage and no dependence on vendor hooks. Rejected: forbidden by FR-08 and the brief; forks
  diverge immediately, break on every host release, and are silently replaced by the user's next
  global upgrade — a guardrail that vanishes on upgrade is worse than none.
- **Pure OS-level interception only** (syscall filtering, `LD_PRELOAD`/`DYLD_INSERT_LIBRARIES`,
  filesystem event hooks), with no per-host integration. Genuinely vendor-agnostic and complete for
  filesystem and process actions. Rejected as the *primary* mechanism: it sees syscalls, not intent,
  so it cannot distinguish an MCP tool call from any other write, cannot render a denial the agent
  can parse (S-04), and cannot easily answer *pre-execution* for network or tool calls. Retained as
  a component of the FR-09 fallback and as defence in depth.
- **A universal shim that proxies the host's stdio** and parses its output to infer actions.
  Rejected: inferring actions from rendered output is guesswork, races execution, and would decide
  after the fact.
- **A single generic adapter driven by per-CLI configuration** instead of code. Attractive for
  maintenance. Rejected: the payload shapes differ structurally, not just in field names, so the
  configuration language would grow into a programming language — with the vendor-specific logic
  still present, only less testable.
- **Allow action classes the host does not expose** (fail-open on coverage gaps), so the product
  never feels restrictive. Rejected: this is the false-assurance failure R-04 describes. The whole
  proposition is that a developer can grant broad autonomy *because* something is watching.
- **Best-effort support for any host version**, parsing whatever arrives. Rejected: a mis-parsed
  action yields a confidently wrong decision, which is the one outcome worse than a refusal to run.
- **Publish "supports every AI CLI" and integrate opportunistically.** Rejected as a marketing
  claim the coverage matrix would immediately contradict; the matrix exists so that support claims
  are checkable.

---
**ADR Number**: 007
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-003](003-local-daemon-over-unix-socket.md) ·
[ADR-008](008-sandbox-confinement-primitive.md) · [ADR-009](009-fail-closed-default.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) FR-07–FR-10, R-04, R-05 ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) §2.8
