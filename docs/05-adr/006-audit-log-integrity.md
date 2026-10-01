# ADR-006: Hash-chained, single-writer audit log, durable before the decision returns

## Status
Proposed

## Context

Full observability is one of the product's three core promises
(`.ai/context/project-brief.md`, Background §3): today, once permissions are blanket-approved, the
only trace of an agent's session is terminal scrollback.

The demanding reader is persona P3 (Priya, security engineer,
`../01-discovery/user-personas.md`): she has been shown "audit logs" before that the audited
process could itself edit, and she rejects the product if this one is writable by the guarded agent.
The log is not a debugging convenience; it is the evidence artefact.

Constraints:

- FR-19: every intercepted action recorded with decision, deciding rule ids, evaluator, latency,
  policy version, and masked payload.
- FR-20: tampering must be **detectable**.
- FR-21: queryable by session, time range, decision, rule id, action type — P95 < 1 s over 1 M
  records.
- FR-22: exportable as structured events to an external pipeline.
- Availability NFR: **zero decisions unlogged**; a logging failure is itself a deny.
- Audit log write P95 < 5 ms, inside a per-action budget of 20 ms deterministic.
- Growth < 1 GB / 30 days at the reference workload.
- R-07: the guarded agent runs as the same user and has shell access.
- The log holds the very secrets the product masks, so it is itself sensitive.

## Decision

1. **Append-only, hash-chained records.** Each record carries `seq`, `prevHash`, and its own `hash`
   over its canonical serialisation. Verification walks the chain and reports the breaking `seq`.
2. **Exactly one writer.** All appends funnel through a single `AuditWriter` task in the daemon
   owning `(seq, prevHash)`. There is no lock to get wrong because there is no second writer
   (ADR-003).
3. **Durable before the decision returns.** The adapter's `decide` response is gated on the audit
   record's durable acknowledgement. A write failure is a **deny**, not a logged-later allow.
4. **On startup, verify the tail and refuse to append past a break.** A detected break is reported,
   not written over — appending onto a broken chain would launder the tampering.
5. **A local embedded store** with indexes on the five FR-21 dimensions, plus documented rotation.
   Rotation seals a segment with its terminal hash and starts the next chained from it, so rotation
   does not break verification.
6. **Read/write split at the interface.** `AuditQuery` is read-only and is the *only* thing the UI,
   the CLI reader, and the exporter receive. Nothing outside `AuditWriter` can append.
7. **The log directory is excluded from every possible `Confinement`**, enforced in the
   `Confinement` constructor (ADR-003 §5). An agent attempt to write it is denied and recorded as a
   distinct high-severity event.
8. **Payloads are stored masked**, per policy, with stable placeholders — the log must not become
   the place secrets accumulate in clear text.
9. **Cache hits and overrides are full records too** — `evaluator: 'cache'` with the originally
   deciding rule ids; overrides with actor and justification (FR-25). FR-19 admits no gaps.
10. **A chain closes with an explicit terminal record.** Removing the product appends a final
    `kind: 'guard.removed'` record — timestamp, adapters de-registered, whether `--purge` was
    requested — as the last link, written *before* the daemon stops (FR-27,
    `../04-solution-design/routing.md` §2.1). `audit.verify` treats a chain ending on
    `guard.removed` as **complete**; a chain ending on any other record with no running daemon is
    reported as a possible truncation. Without this, an ordinary uninstall is indistinguishable
    from tail-truncation — the product would accuse its own removal of tampering, and a real
    truncation would gain a plausible excuse.
11. **The log survives removal by default.** `guard uninstall` retains the log and prints its path;
    only `--purge` deletes it, with confirmation. The log is the user's evidence record, not the
    product's private state, and it is most likely to be wanted *after* the tool is gone.

## Rationale

- **Hash chaining is the cheapest honest answer to "could this have been edited?"** It does not
  prevent tampering — nothing local can, against a user with root — but it makes tampering
  *detectable*, which is what FR-20 asks for and what P3 actually needs. Claiming prevention would
  be the dishonesty that loses her trust.
- **Single-writer is a structural guarantee, not a discipline.** Two writers fork the chain, and a
  fork is indistinguishable from tampering — so concurrency here would manufacture false alarms and
  destroy the signal.
- **Durable-before-return is the whole of "zero decisions unlogged".** Any other ordering has a
  window in which an action executed and no record exists — precisely the state the product
  promises cannot occur. It costs latency, and that cost is accepted.
- **Sealing segments with a terminal hash** keeps rotation (needed for the 1 GB budget) compatible
  with verification, which is the detail that usually breaks this class of design.
- **A read-only query interface means no UI bug can corrupt the evidence**, which is what lets the
  UI be built in a different language with a looser threat model (ADR-002).
- **Storing masked payloads** keeps the log from becoming a higher-value target than the files it
  describes.

Trade-offs accepted:

- **Latency on the hot path.** The fsync is real and sits inside the per-action budget. The 5 ms
  target constrains the storage engine choice.
- **Detection, not prevention.** A user with root can delete the whole log. The chain tells you it
  happened; it cannot stop it. This must be stated in the threat model (FR-18) and never oversold.
- **Append-only conflicts with data deletion.** A request to remove a record cannot be honoured
  in place; the answer is segment expiry via rotation, and that limitation is a product statement.
- **Write amplification** from indexing on five dimensions against a 1 GB/30-day budget.

## Consequences

**Easier**

- Answering "what did the agent do?" with something a security reviewer accepts (S-06, S-07).
- Proving no decision went unlogged.
- Exporting to an existing pipeline (S-14) — records are already structured and immutable.
- Caching in the UI: historical records are immutable, so cache invalidation for history is not a
  problem that exists (`../04-solution-design/state-management.md` §B.2).

**Harder**

- Meeting the 5 ms write budget with durability; the storage engine must be chosen against a
  measured fsync cost, not a feature list.
- Rotation correctness — the seal-and-chain step is easy to get subtly wrong and must be tested by
  verifying across a rotation boundary.
- Any future need to redact a record after the fact.

**The team must now**

1. Choose the embedded store against a measured durable-append benchmark, and record it (a Phase 3
   task; this ADR fixes the shape, not the engine).
2. Implement `audit.verify` and wire it into CI's adversarial gate: edit-in-place, delete-middle,
   truncate-tail, and replay-old-chain must each be detected with the correct `seq`.
3. Test verification **across** a rotation boundary, not only within a segment.
4. Set the log directory's permissions at install time and assert the `Confinement` exclusion in a
   test that tries every policy shape.
5. State plainly in the threat model that the guarantee is detection, not prevention.
6. Add `guard.removed` to the record-kind enum and extend `audit.verify`'s outcomes to distinguish
   *complete*, *closed by removal*, and *suspected truncation* — then test verification of a
   removed install, and of a chain truncated to look like one (the terminal record is hash-chained,
   so forging it requires the chain, which is the same assumption the rest of this ADR rests on).

## Rejected Alternatives

- **Plain append-only text or JSONL with no chaining.** Simplest, fastest, trivially exportable,
  and greppable. Rejected: it cannot detect an edit, so it fails FR-20 and fails the one reader who
  matters most for this feature — P3 explicitly rejects a log the audited process could edit.
- **A conventional mutable database table.** Best query story and the easiest to build. Rejected:
  mutability is the property being designed against; an `UPDATE` on an audit record must not be
  expressible.
- **Signing each record with a private key instead of chaining.** Stronger cryptographically for
  authenticity. Rejected for v1: the key must live on the same machine the threat model concedes to
  a root attacker, so it adds key management without adding a guarantee against the actual
  adversary. Chaining detects reordering and deletion, which is the realistic failure. Revisit for a
  team deployment (Q-05) where a remote verifier holds the public key.
- **Remote or append-only cloud log as the primary store.** Would genuinely resist local tampering.
  Rejected: it contradicts the local-only privacy premise and would ship action payloads off the
  machine. Available later as an *export* target (FR-22), where the user opts in.
- **Log asynchronously, return the decision immediately.** Removes the fsync from the hot path and
  would comfortably meet the latency budget. Rejected: it creates a window where an action executed
  with no record, which is exactly the guarantee being sold. If the budget proves unreachable, the
  correct response is to widen the latency budget, not to weaken the logging guarantee.
- **Best-effort logging: on a write failure, proceed and log the failure.** Rejected: it makes the
  log unreliable under exactly the conditions (disk full, permissions changed, tampering in
  progress) where it matters most. A logging failure is a deny.
- **Log only denials and asks.** Would cut volume dramatically and meet the size budget easily.
  Rejected: "what did the agent do?" is mostly a question about allowed actions. A log of refusals
  answers nothing about what happened.

---
**ADR Number**: 006
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-003](003-local-daemon-over-unix-socket.md) ·
[ADR-009](009-fail-closed-default.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) FR-19–FR-22, FR-27, R-07 ·
[`../04-solution-design/state-management.md`](../04-solution-design/state-management.md) §A.4
