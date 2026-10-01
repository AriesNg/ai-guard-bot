# ADR-003: A long-lived local daemon addressed over a Unix domain socket

## Status
Proposed

## Context

Something must hold the policy, the loaded model, the audit chain head, and the decision cache
between actions. Three candidate shapes exist: a per-action process that loads everything each
time; a long-lived daemon the adapters call; or a library linked directly into each host CLI.

The constraints that decide it:

- **Model load cost.** A small local model takes seconds to load and gigabytes of RAM. The
  model-path budget is P95 < 300 ms per action. Loading per action is off by orders of magnitude.
- **Cold start** < 2 s excluding model warm-up, < 15 s including it — a once-per-session cost,
  not a per-action one.
- **The audit chain has exactly one writer.** `../04-solution-design/state-management.md` §A.4:
  two concurrent writers fork the chain, and a forked chain is indistinguishable from tampering
  (FR-20), which destroys the log's value as evidence.
- **The decision cache** is the main mitigation for R-03 (latency) and needs to survive between
  actions within a session.
- **The guarded agent must not be able to reach the engine** (R-07). The agent has shell access as
  the same user.
- **Privacy NFR**: no policy decision leaves the machine. Whatever the transport is, it must make
  that verifiable rather than merely intended.
- **4 concurrent agent sessions** on one laptop, sharing one model runtime.

## Decision

1. **A single long-lived per-user daemon** (`guardd`) owns the policy, the model runtime handle,
   the audit writer, and one session entry per connected agent.
2. **Adapters are short-lived processes** invoked by the host CLI's hook interface; each normalises
   the host payload into the canonical `Action` and makes one RPC call.
3. **Transport is JSON-RPC 2.0 over a Unix domain socket**, mode `0600`, owned by the invoking
   user, at `$XDG_RUNTIME_DIR/ai-guard-bot/guard.sock` (platform equivalent on macOS).
4. **No TCP listener exists in the product**, in any configuration, for any purpose.
5. **The socket path and the engine's config directory are excluded from every possible
   `Confinement`** — the exclusion is enforced in the `Confinement` constructor, not left to
   policy authoring.
6. **Method-level read/write split**: only adapters may call `decide`; the UI and the audit reader
   are permitted read methods only; nothing outside `AuditWriter` can append a record.
7. **The daemon's lifecycle is owned by `install` / `uninstall`, and it is the *last* thing torn
   down.** Removal stops the daemon, unlinks the socket, and deletes the service definition
   (launchd agent / systemd user unit) so nothing restarts it — but only after every adapter is
   de-registered (FR-27, [ADR-009](009-fail-closed-default.md) item 12). A stopped daemon with a
   live hook is not a degraded state, it is a host CLI that denies everything; a stale socket with
   no adapters, by contrast, is inert. The asymmetry is why the order is fixed.

## Rationale

- **The model must be loaded once.** This alone eliminates the per-action process, and it is not a
  close call.
- **Single-writer serialisation of the audit chain falls out of the architecture** rather than
  being bolted on: there is one daemon, therefore one writer. Any design with multiple writers
  needs a lock whose correctness the log's integrity then depends on.
- **The socket's file permissions *are* the authentication**, which is the honest model for a
  single-user local tool. There is exactly one user; inventing a login would imply a security
  boundary that does not exist.
- **Absence of a TCP listener makes the Privacy NFR testable.** "No network in the decision path"
  stops being a claim and becomes an observable property of the binary — the integration and
  accuracy test stages run with networking disabled and pass
  (`../04-solution-design/testing-strategy.md` §6).
- **Excluding the socket from the sandbox by construction** is what makes R-07 a design property
  rather than a rule an author could forget.
- **Cross-session fairness and back-pressure need a shared view.** A bounded model queue with
  round-robin across four sessions is only possible in a process that sees all four.

Trade-offs accepted:

- The daemon is a **new lifecycle to manage** — start, restart, upgrade, and crash recovery.
- It is a **shared failure domain**: if it dies, every guarded session stops. Given fail-closed
  (ADR-009), stopping is the correct behaviour, but it is still a stop.
- Unix domain sockets **are not available on Windows** in the same form, which couples this
  decision to Q-02.

## Consequences

**Easier**

- Meeting the model-path latency budget; caching across actions; fair scheduling across sessions.
- Guaranteeing one audit writer without a lock.
- Proving the no-network property.
- Reporting health and coverage for all sessions from one place (FR-23).

**Harder**

- Daemon lifecycle: supervision, auto-start on first adapter call, upgrade while sessions are
  live, and the < 5 s crash-recovery target.
- Debugging becomes cross-process; the adapter and daemon need correlated logs keyed on
  `action.id`.
- Windows support, if Q-02 asks for it, needs a named-pipe transport behind the same contract.

**The team must now**

1. Decide daemon supervision: on-demand auto-start from the adapter, or a user-level service. (A
   Phase 6 concern; the socket contract does not depend on it.)
2. Implement chain-tail verification on daemon start, refusing to append past a detected break.
3. Add an adapter-side timeout with a fail-closed default, so a hung daemon denies rather than
   blocks the developer's session indefinitely.
4. Treat the socket path as part of the security boundary in the Phase 3 threat model.

## Rejected Alternatives

- **A per-action process that loads policy and model each time.** Simplest possible lifecycle: no
  daemon, no socket, no supervision, and no shared state to get wrong. Rejected on arithmetic —
  multi-second model load against a 300 ms budget — and it would also give up the decision cache
  and cross-session fairness. Retained as the shape of the `policy.validate` CLI path, which has
  no latency budget and needs no model.
- **A library linked into each host CLI.** Lowest latency of all, no IPC. Rejected on the hard
  constraint that host agents are not forked or patched (FR-08), and because it would put the
  policy engine inside the process it is meant to constrain — the agent could then reach the
  engine's memory, which defeats R-07 entirely.
- **TCP on localhost.** Easier cross-platform story and trivial tooling. Rejected: any local
  process can connect, including the guarded agent, so the socket's file-permission authentication
  disappears and R-07 is reopened; and the existence of a listening socket makes "no network in
  the decision path" an argument rather than an observation.
- **A named pipe / platform-specific IPC chosen per OS from the start.** Rejected for v1 as
  premature until Q-02 names the platforms; the JSON-RPC contract is transport-agnostic, so adding
  a named-pipe transport later changes no caller.
- **gRPC or another binary RPC over the socket.** Better wire efficiency and generated clients.
  Rejected: the payloads are small enough that JSON is not the bottleneck, JSON keeps the audit
  and debug story legible, and a schema-generated JSON contract already serves the CLI and UI.
  Revisit only if profiling shows codec cost inside the 20 ms budget.
- **One daemon per agent session.** Would isolate sessions from each other. Rejected: it
  multiplies model memory by the session count, breaking the < 5 GB budget at two sessions, and
  reintroduces multiple audit writers.

---
**ADR Number**: 003
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-002](002-enforcement-core-language.md) ·
[ADR-006](006-audit-log-integrity.md) · [ADR-007](007-cli-integration-strategy.md) ·
[ADR-009](009-fail-closed-default.md) ·
[`../04-solution-design/routing.md`](../04-solution-design/routing.md) §1
