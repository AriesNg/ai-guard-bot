# 03 — System Design: API Design

**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_

> **Phase-gate note.** Drafted ahead of the Phase 3 prerequisite (**UX Design approved**) at the
> product owner's explicit request; carries assumptions **A-1 … A-3** from
> [`architecture.md`](architecture.md). This document is the **canonical** contract for every
> interface in the product; [`../04-solution-design/routing.md`](../04-solution-design/routing.md)
> is the Phase 4 *shape* it supersedes where the two differ.

Four interfaces, in descending order of how much depends on them being right:

1. **Daemon RPC** (§3) — the enforcement path, latency-budgeted.
2. **CLI** (§4) — how a developer and a CI job drive the tool.
3. **`LocalModelRuntime` port** (§7) — the one place untrusted generated output enters the engine.
4. **`CliAdapter` port** (§8) — the one place a vendor's payload shape is known.

---

## 1. Conventions that hold everywhere

- **One error shape** (§5) on every surface: RPC, CLI `--json`, and the TUI. A caller writes one
  error handler.
- **One identifier**: the `Action.id` ULID threads a decision through the RPC call, the audit record,
  the denial the agent sees, `allow-once`, and the log query. One id end to end is what makes S-04
  ("the agent reads the denial and adapts") and S-07 ("show me what happened") the same lookup.
- **Timestamps** are RFC 3339 with an explicit offset. Never a bare local time, never epoch
  milliseconds on the wire.
- **Stable codes and rule ids.** Both appear in denials that an agent parses and in evidence a human
  reads; renaming either is a breaking change (§5).
- **Every read command has `--json`** and every output respects `NO_COLOR` (Accessibility NFR).
- **No API key, no token, no session secret exists anywhere in this product.** §2.2 explains why
  adding one would be worse than not having one.

---

## 2. Transport, and the REST question answered

### 2.1 Transport

**JSON-RPC 2.0 over a Unix domain socket**, at `$XDG_RUNTIME_DIR/ai-guard-bot/guard.sock` (macOS:
under `~/Library/Application Support/ai-guard-bot/`), mode `0600`, owned by the invoking user.
Newline-delimited framing. **No TCP listener in any configuration**
([ADR-003](../05-adr/003-local-daemon-over-unix-socket.md) item 4).

### 2.2 Why not REST — the review-criteria item, answered rather than waived

The review checklist asks for a RESTful API or a justification for RPC. The justification is
structural, not stylistic:

1. **There is no HTTP surface to be REST over.** REST is an architectural style for HTTP; adopting it
   would require binding a port, which [ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md)
   and [ADR-003](../05-adr/003-local-daemon-over-unix-socket.md) forbid — and that prohibition is
   what makes the Privacy NFR *verifiable* (`lsof` proves it) rather than merely asserted. A REST API
   would trade a checkable guarantee for a convention.
2. **The operations are not resources.** `decide` is a synchronous question with a sub-20 ms budget
   whose answer is a *decision*, not the state of a thing. Modelling it as `POST /decisions` would
   invent a collection nobody reads, and the created resource would never be fetched by its URI.
3. **An HTTP server is attack surface in a security product.** Routing, header parsing, content
   negotiation and middleware would all sit inside the enforcement boundary. JSON-RPC over a
   `0600` socket has one framing rule and one dispatch table.
4. **Filesystem permissions are a stronger authentication than anything REST would bring here.** A
   bearer token on localhost must be stored somewhere readable by the same user — so it adds a
   secret to protect without adding a boundary. Socket mode `0600` is enforced by the kernel.

What is kept from REST's discipline rather than discarded with the style: a fixed method vocabulary, a
read/write classification per method (§3.2), uniform error representation (§5), and no hidden state in
the connection.

---

## 3. Daemon RPC surface

### 3.1 Method catalogue

Seventeen methods. `W` = mutating, `R` = read-only (§3.2).

| Method | Caller | R/W | Budget | Request | Response |
|---|---|---|---|---|---|
| `session.open` | adapter | W | < 50 ms | `{ agent, coverage, mode }` | `{ sessionId, policyVersion, coverageReport }` |
| `decide` | adapter | W | **P95 < 20 ms det. / < 300 ms model** | `{ action: Action }` | `Decision` |
| `content.outbound` | adapter | W | P95 < 50 ms | `ContentScreenRequest` | `OutboundResult` |
| `content.inbound` | adapter | W | P95 < 50 ms | `ContentScreenRequest` | `InboundResult` |
| `ask.resolve` | CLI / TUI | W | — | `{ actionId, outcome, actor, justification }` | `{ recorded: true, seq }` |
| `session.close` | adapter | W | < 50 ms | `{ sessionId }` | `{ decisions, byOutcome, p95Ms }` |
| `policy.reload` | CLI | W | < 500 ms | `{ paths? }` | `{ from, to, ruleCount }` |
| `policy.validate` | CLI / TUI | R | < 500 ms | `{ paths?, inline? }` | `{ valid, errors: GuardError[], ruleCount }` |
| `policy.simulate` | CLI / TUI | R | — | `{ candidate?, action? , replay? }` | `{ results: SimulatedDecision[] }` |
| `policy.current` | CLI / TUI | R | < 20 ms | `{}` | `VersionedPolicySummary` |
| `audit.query` | CLI / TUI | R | **P95 < 1 s / 1 M** | `AuditQuery` | `{ records, nextCursor? }` |
| `audit.verify` | CLI / TUI | R | — | `{ fromSeq?, toSeq? }` | `VerifyResult` |
| `audit.stream` | CLI / TUI | R | — | `{ sinceSeq? }` | server-push `AuditRecord` |
| `audit.export` | CLI | R | — | `{ format, filter }` | stream |
| `health` | any | R | < 20 ms | `{}` | `HealthReport` |
| `metrics` | any | R | < 50 ms | `{}` | `MetricsSnapshot` |
| `install.probe` | CLI | R | < 200 ms | `{ agent? }` | `{ adapters: AdapterState[] }` |

`install.probe` is new in Phase 3 and exists because FR-27 made registration state a **probed**
property rather than a remembered one ([`data-model.md`](data-model.md) §6.4). `guard uninstall` and
`guard status` both need the same answer — "is this adapter actually registered in the host's config"
— and it must come from one implementation, or the two commands could disagree about whether the
product is installed.

### 3.2 Authorisation

| Mechanism | What it is |
|---|---|
| **Authentication** | The socket's file permissions: `0600`, user-owned. Anyone able to connect already holds the user's privileges. There is no second principal to distinguish, and inventing a token would add a secret without adding a boundary (§2.2). |
| **Authorisation** | The **method-level read/write split**, enforced in the dispatch table by an allowlist written in code — not derived from the request, and not a property a caller asserts about itself. |
| **Capability restriction** | Only an adapter may call `decide` and `content.*` (a connection that has not completed `session.open` with a valid agent identity cannot). **No caller can append an audit record**: appending is not on the method catalogue at all. |
| **Reachability** | The guarded agent cannot reach the socket: every `Confinement` excludes the socket path and the engine's config directory, for every possible policy. A construction, not a rule (R-07; [`security.md`](security.md) §4.2). |
| **Accountability** | Every `W` method appends an audit record with the actor. `ask.resolve` and `policy.reload` are audited as first-class events, not as side-effects. |

Every method in §3.1 is therefore covered by the checklist item "authn/authz on every endpoint": the
authentication is uniform (the socket) and the authorisation is explicit per method (the R/W column
plus the capability restriction).

### 3.3 Core request/response schemas

```ts
// ---- decide ----
interface DecideRequest { action: Action; }          // data-model.md §2.2

interface Decision {
  actionId: string;
  decision: DecisionKind;                            // allow | deny | ask | mask
  ruleIds: string[];                                 // every rule that contributed, FR-15
  evaluator: 'deterministic' | 'hook' | 'model';
  confidence?: number;                               // model path only
  reason: string;                                    // actionable: what to do instead
  latencyMs: number;
  policyVersion: string;
  mode: 'enforcing' | 'dry-run';
  auditSeq: number;                                  // proof the record exists before this reply
  confinement?: Confinement;                         // present for allow | mask — how to execute
  maskedPayload?: MaskedPayload;                     // present for mask
}
```

`auditSeq` is in the response deliberately: it makes the FR-19 ordering guarantee **observable by the
caller**. A `Decision` without an `auditSeq` is malformed, so an implementation that responded before
appending could not produce a valid reply — the guarantee is enforced by the schema, not by a comment.

```ts
// ---- session.open ----
interface SessionOpenRequest {
  agent: { name: string; version: string };
  coverage: Record<ActionKind, 'intercepted' | 'unavailable'>;   // total, 11 cells
  mode: 'enforcing' | 'dry-run';
}
interface SessionOpenResponse {
  sessionId: string;
  policyVersion: string;
  coverageReport: {
    accepted: boolean;
    gaps: ActionKind[];            // cells reported `unavailable` — each denies at runtime
    warnings: string[];
  };
}
```

A `coverage` map missing any of the eleven kinds is a **validation failure** (`COVERAGE_GAP`), not a
partial acceptance. An unsupported `agent.version` is rejected with `AGENT_VERSION_UNSUPPORTED` and
the session never opens — under fail-closed that means the host is denied, which is the intended
outcome: an adapter that does not understand its host's payload shape must not be trusted to normalise
it (R-05).

```ts
// ---- audit.query ----
interface AuditQuery {
  sessionId?: string;
  from?: string; to?: string;                        // RFC 3339
  decision?: DecisionKind[];
  ruleId?: string[];
  kind?: ActionKind[];
  limit?: number;                                    // default 100, max 1000
  cursor?: string;                                   // opaque; encodes seq
}
```

Exactly the five FR-21 dimensions, each backed by an index ([`data-model.md`](data-model.md) §6.2).
Cursor paging is on `seq`, so a page boundary cannot duplicate or skip a record even while the log is
being appended to.

```ts
// ---- audit.verify ----
interface VerifyResult {
  outcome: 'complete' | 'closed-by-removal' | 'suspected-truncation' | 'broken';
  checkedFrom: number; checkedTo: number;
  brokenAtSeq?: number;                              // present iff outcome = 'broken'
  oldestRetainedSeq: number;                         // honesty about rotation, data-model.md §5.3
}

// ---- health ----
interface HealthReport {
  status: 'enforcing' | 'dry-run' | 'degraded';
  policyVersion: string;
  modelRuntime: 'ready' | 'warming' | 'unavailable' | 'saturated';
  adapters: { agent: string; version: string; coverage: CoverageSummary }[];
  auditChain: 'valid' | 'broken';
  uptimeSeconds: number;
  guardVersion: string;
}
```

`status: 'degraded'` is reported when the model runtime is unavailable — and it is **not** a
permissive state: intent rules deny while it is down. `health` says so explicitly rather than letting
a developer infer "degraded" as "mostly working".

---

## 4. CLI surface

| Command | R/W | Purpose | Story / FR |
|---|---|---|---|
| `guard install [--agent <name>] [--print]` | W | Provision bottom-up: runtime, service, adapters. Prints the coverage matrix. | S-09, FR-24 |
| `guard uninstall [--agent <name>] [--purge] [--print] [--yes]` | W | Teardown top-down (§4.2). | S-25, FR-27 |
| `guard status [--json]` | R | Health, policy version, per-CLI coverage, enforcing vs dry-run | FR-23 |
| `guard policy init` | W | Write the opinionated safe default — the zero-authoring path | R-06 |
| `guard policy validate [file] [--json]` | R | Parse, merge, narrow-only check. **Exit 2 on invalid** — CI-usable | FR-04, FR-05, S-18 |
| `guard policy diff [file]` | R | What a candidate policy would have decided differently over recent history | S-10, S-20 |
| `guard policy reload` | W | Explicit hot reload | FR-26 |
| `guard log [--session --from --to --decision --rule --kind] [--json]` | R | Query the audit log | FR-21, S-07 |
| `guard log verify [--json]` | R | Chain verification. **Non-zero exit on a break** | FR-20 |
| `guard log export [--format <fmt>]` | R | Structured export | FR-22, S-14 |
| `guard dry-run <command…>` | W | Run a session with enforcement off, logging on | FR-16, S-10 |
| `guard allow-once <actionId> --reason <text>` | W | Resolve a pending `ask` | FR-25, S-15 |
| `guard audit view` | R | Read-only TUI viewer | S-24 |

**Exit codes**, uniform and scriptable: `0` allow/success · `1` operational error · `2` policy invalid
· `3` denied. The split between `2` and `3` is what lets CI distinguish "your policy is broken" from
"your policy worked and said no" — conflating them would make a CI failure ambiguous in exactly the
case a developer most needs it to be clear.

### 4.1 Machine output is a contract

`--json` output is part of the API, not a debug convenience: stable field names, the `GuardError`
shape on failure, one JSON document per invocation (or newline-delimited objects for `log` and
`export`). Stdout carries data, stderr carries diagnostics, so `guard log --json | jq` never ingests a
warning. `NO_COLOR` and a non-TTY stdout both switch human output to plain text with no loss of
information — colour is never the only carrier of meaning (WCAG 2.1 AA, applied in
[`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md) §1a).

### 4.2 `guard uninstall` — the contract, because the ordering is the requirement

Canonical statement of FR-27; flow and matrix in
[`../04-solution-design/routing.md`](../04-solution-design/routing.md) §2.1.

```ts
interface RemovalReport {
  adapters: { agent: string; outcome: 'removed' | 'already-absent' | 'failed';
              filesChanged: string[]; error?: GuardError }[];
  terminalRecord: { seq: number; hash: string } | null;
  daemon: 'stopped' | 'left-running' | 'already-stopped';
  retained: { policyPath?: string; auditPath?: string; weightsPath?: string; weightsBytes?: number };
  purged: string[];
  exitCode: 0 | 1;
}
```

Guarantees the command must satisfy, each testable:

1. **Adapters de-register before the daemon stops.** If any adapter still probes `true`, the command
   **aborts with the daemon running** and exits `1`. A failed uninstall leaves a working guard, never a
   broken host CLI ([ADR-009](../05-adr/009-fail-closed-default.md) item 12).
2. **Probe, don't trust the receipt.** Adapters are enumerated from the receipt **and** by probing every
   known host-config location (`install.probe`, §3.1).
3. **A terminal `guard.removed` record is appended before the daemon stops**, so `guard log verify`
   reports `closed-by-removal` rather than `suspected-truncation`.
4. **Retention by default.** Policy file, audit log and model weights survive and their paths are
   printed; `--purge` deletes them, prompting on a TTY and requiring `--yes` otherwise. A runtime the
   product *adopted* rather than installed is never deleted
   ([ADR-005](../05-adr/005-pluggable-local-model-runtime.md) item 9).
5. **Idempotent.** Exit `0` from a partially-installed, hand-edited, or already-removed state, naming
   each component as `removed` / `already-absent`. Exit `1` is reserved for a removal attempted and not
   completed.
6. **`--print` changes nothing** and lists every file that would be touched (`plannedChanges`, §8).
7. **Surgical edits.** The host's config file comes back with its other entries and its formatting
   intact — our entry is deleted, the document is not rewritten.

---

## 5. The error catalogue — closed, not illustrative

```ts
interface GuardError {
  code: GuardErrorCode;
  message: string;                  // actionable: says what to do instead
  ruleIds?: string[];               // FR-15
  actionId?: string;
  details?: Record<string, unknown>;
  retryable: boolean;
}
```

Phase 4 listed these codes as examples. **Phase 3 closes the set**: a failure that does not fit a code
below needs a new code added here by review, not an ad-hoc string — because S-04's premise is that the
*agent* parses the code and adapts, which fails silently the moment codes multiply informally.

| Code | Meaning | Decision | `retryable` |
|---|---|---|---|
| `RULE_VIOLATION` | A rule denied the action | deny | `false` |
| `POLICY_INVALID` | Policy failed schema/semantic validation | previous version stays active | `false` |
| `POLICY_WIDENS_BASELINE` | Project policy tried to widen the baseline (FR-05) | reject policy | `false` |
| `POLICY_CONFLICT` | Precedence tie the total order cannot break (§6) | reject policy | `false` |
| `COVERAGE_GAP` | Action kind not intercepted by this adapter (FR-10) | **deny** | `false` |
| `AGENT_VERSION_UNSUPPORTED` | Host version outside `supportedVersions` | session refused → deny | `false` |
| `EVALUATOR_UNAVAILABLE` | Model runtime down, or a hook's binary missing | **deny** | `true` |
| `EVALUATOR_SATURATED` | Bounded model queue full (§6.3 of `security.md`) | **deny** | `true` |
| `EVALUATOR_MALFORMED` | Runtime returned output the constrained schema rejects (§7) | **deny** | `true` |
| `HOOK_TIMEOUT` | A hook exceeded its hard timeout | **deny** | `true` |
| `NORMALISATION_FAILED` | The host payload could not be canonicalised ([`data-model.md`](data-model.md) §2.3) | **deny** | `false` |
| `AUDIT_CHAIN_BROKEN` | Verification found a hash mismatch | refuse to append past the break | `false` |
| `AUDIT_WRITE_FAILED` | Durable append did not complete | **deny** — the decision cannot be returned | `true` |
| `ENGINE_UNREACHABLE` | Adapter could not reach the daemon | **deny** (fail-closed) | `true` |
| `CONFINEMENT_UNAVAILABLE` | OS primitive missing or unsupported platform | refuse to start | `false` |
| `REMOVAL_INCOMPLETE` | An adapter could not be de-registered (§4.2) | abort, daemon left running | `true` |
| `INVALID_REQUEST` | Malformed RPC, unknown method, or a read-only caller invoking a `W` method | reject | `false` |

**Every code whose "Decision" column says deny is a path to the pipeline's initial value, not a branch
that chooses deny** — which is the whole of [ADR-009](../05-adr/009-fail-closed-default.md). Note
`AUDIT_WRITE_FAILED`: if the record cannot be made durable, the decision is not returned, because
returning an allow whose record does not exist would break FR-19 in the one case where it matters.

`retryable: true` means *the same action may succeed later without any change to the policy* — it is a
hint to the agent (S-04), never a licence for the adapter to retry automatically. An adapter that
retried a saturation denial on its own would convert backpressure into a stampede.

---

## 6. Precedence: the formal relation

[ADR-004](../05-adr/004-layered-policy-model.md) asserts a fixed total order. Phase 3's
obligation is to make it **total in fact**, because "more specific wins" is not an order until
specificity is defined. This section discharges that.

### 6.1 The comparison, in order

Given two candidate results `A` and `B`, compare on these keys in sequence; the first that
differentiates decides:

1. **Decision strength**: `deny` > `mask` > `ask` > `allow`.
2. **Evaluator authority**: `deterministic` > `hook` > `model`.
3. **Specificity** of the matching rule: higher wins (§6.2).
4. **Source layer**: `baseline` > `project`.
5. **Declaration order** within the same file: later wins.

Key 1 before key 2 is a deliberate choice with a consequence worth naming: a *model* deny beats a
*deterministic* allow. The alternative — deterministic sources always winning — would mean a broad
`allow` rule silently disabling every intent rule beneath it, which is how a policy acquires a hole
its author cannot see. Strength first means the safe answer is never overridden by a less careful
layer; the price is that a confident-but-wrong model deny can block a permitted action, which is R-01,
mitigated by `confidenceThreshold`, `ask` as a middle outcome, and `allow-once` (S-15) — a tuning
annoyance rather than a silent hole.

### 6.2 The specificity relation

`specificity` is a derived integer, computed once per policy version into `specificityIndex`
([`data-model.md`](data-model.md) §3), never authored by hand:

```
specificity(rule) = Σ over the rule's match constraints of weight(constraint)

weight(kind constraint)        = 10 × (11 − |kinds|)      // 11 ActionKinds; fewer kinds is more specific
weight(exact path or command)  = 100
weight(path prefix pattern)    = 60 − min(50, depth_bonus)   // deeper prefix is more specific
weight(glob / regex pattern)   = 30
weight(destination host exact) = 100
weight(destination host glob)  = 30
weight(content pattern)        = 20
weight(server constraint)      = 40                       // MCP server identity
weight(intent rule)            = 5                        // plain language is inherently least specific
```

Where `depth_bonus = 10 × (path segment count)`, capped. The properties that matter:

- **An exact match always outranks a pattern** that also matches it, which is the intuition "more
  specific wins" actually encodes.
- **An intent rule never outranks a deterministic rule on specificity**, so the cheap layer stays
  authoritative within its scope.
- **It is a total preorder, and keys 4–5 break its ties**, which makes the full comparison a **total
  order on rules**.

### 6.3 Ties are a validation failure, not a runtime coin-flip

If two rules with **different decisions** compare equal on all five keys, the policy is rejected at
load with `POLICY_CONFLICT`, naming both rule ids. The alternative — picking one — would make the same
policy decide differently across versions, platforms, or hash-map iteration orders, and the audit log
would faithfully record an arbitrary choice as though it were intended.

The resolver is implemented **once** and shared by the daemon, `policy.simulate` and `policy.diff`, so
a simulation cannot disagree with enforcement. It is on the **never-mocked** list
([`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md) §3) and is
property-tested for totality, antisymmetry and transitivity over generated rule sets.

---

## 7. `LocalModelRuntime` — the port, and constrained decoding

[ADR-005](../05-adr/005-pluggable-local-model-runtime.md) delegated the decoding schema to Phase 3.
This is the only place in the product where **generated text** crosses into the enforcement core, so
the contract is written as a boundary, not as an integration.

```ts
interface LocalModelRuntime {
  readonly id: string;                      // runtime identity, not model identity (A-2)
  capabilities(): RuntimeCapabilities;      // checked at startup, §7.2
  evaluate(req: IntentEvalRequest): Promise<IntentEvalOutput>;
  warm(): Promise<void>;
  shutdown(): Promise<void>;
}

interface RuntimeCapabilities {
  constrainedDecoding: 'grammar' | 'enum' | 'none';   // 'none' is rejected at startup
  maxConcurrency: number;
  supportsCancellation: boolean;
}

interface IntentEvalRequest {
  rule: { id: string; intent: string; decision: DecisionKind };
  action: RedactedAction;                   // §7.3 — never the raw payload
  deadlineMs: number;                       // hard; expiry denies
}
```

### 7.1 The output schema is the grammar

The runtime may emit **only** a value of this shape. It is not a prompt instruction and not a
post-hoc parse; it is a decoding constraint, so a non-conforming token sequence is **unreachable**
rather than rejected after the fact:

```ts
interface IntentEvalOutput {
  matches: boolean;                 // does the action fall under this rule's intent?
  confidence: number;               // one of a fixed 0.00 … 1.00 lattice, two decimals
  reason: string;                   // <= 200 chars, single line, from a constrained character set
}
```

The engine then applies the rule's own `decision` if `matches && confidence >= rule.confidenceThreshold`.
**The model never names the decision.** It answers one bounded question — does this action fall under
this intent — and the policy author's `decision` field supplies the outcome. The model therefore cannot
widen policy, invent a rule, or emit `allow` for a rule whose author wrote `deny`, no matter what it
generates; the worst a compromised or confused runtime can do is misclassify within a single rule's
scope. That containment is the entire reason the schema looks like this, and it is the mitigation for
the model-manipulation case in the adversarial gate.

### 7.2 A runtime that cannot be constrained is rejected at startup

`capabilities().constrainedDecoding === 'none'` → the daemon **refuses to start**, reporting
`CONFINEMENT_UNAVAILABLE`-style startup failure with a distinct message. It does not fall back to
parsing free text defensively, because a defensive parser is a tolerated unconstrained channel — and
it would quietly become the only thing standing between generated text and the decision path. Startup
also runs a **conformance probe**: a handful of recorded requests whose outputs must parse and whose
confidence values must land on the lattice. A runtime that fails the probe is rejected, not warned
about.

### 7.3 Only a redacted action reaches the model

```ts
interface RedactedAction {
  kind: ActionKind;
  target: string;                   // path/command/host — structure, not content
  summary: string;                  // normalised, bounded description built by the engine
  cwdRelative: string;              // relative to cwd; the absolute home path is not sent
  // no env names, no file contents, no request bodies, no argv beyond the normalised form
}
```

The model is a classifier over *structure*, so sending content would add risk (content is where
injection lives) without adding signal. This also means an injected instruction inside a file the
agent read cannot reach the evaluator that judges the action — a property worth having explicitly
rather than by accident.

### 7.4 Failure is always deny

| Condition | Result |
|---|---|
| Deadline expired | `EVALUATOR_UNAVAILABLE` → deny |
| Queue full | `EVALUATOR_SATURATED` → deny |
| Output violates the grammar | `EVALUATOR_MALFORMED` → deny |
| Confidence below the rule's threshold | the rule **does not fire**; the fold continues (not itself a deny) |
| Runtime crashed | `EVALUATOR_UNAVAILABLE` → deny; restart is attempted out of band |

The fourth row is the one distinction that matters: "below threshold" is *not* an error. It means this
rule has no opinion, and the pipeline moves on with the initial value still in place.

### 7.5 The test double is a recorded-response stub

Tests use a stub replaying recorded `(IntentEvalRequest → IntentEvalOutput)` pairs, so evaluation
tests are deterministic and the accuracy gate measures the **corpus**, not the weather. The real
runtime is exercised only in the accuracy and performance gates. The stub implements the same port and
is subject to the same startup conformance probe, so it cannot drift into accepting outputs the real
boundary would reject.

---

## 8. `CliAdapter` — the contract written before either adapter

Ratifies [ADR-007](../05-adr/007-cli-integration-strategy.md). The contract comes first precisely so
that the second adapter does not reshape itself around the first one's accidents.

```ts
interface CliAdapter {
  readonly agent: string;
  readonly supportedVersions: SemverRange;
  readonly coverage: Record<ActionKind, 'intercepted' | 'unavailable'>;   // total: 11 cells

  normalise(hostPayload: unknown): Result<Action, NormalisationError>;
  renderDenial(d: Denial): HostResponse;                  // FR-15, in the host's own shape

  install(): Promise<InstallReport>;                      // S-09, FR-24
  uninstall(): Promise<RemovalReport>;                     // S-25, FR-27
  isRegistered(): Promise<boolean>;                        // probes host config, never the receipt
  plannedChanges(op: 'install' | 'uninstall'): Promise<FileChange[]>;   // --print; performs no writes
}

interface FileChange {
  path: string;
  operation: 'create' | 'modify' | 'delete';
  description: string;                 // what, in one line a human can check
}
```

Contract obligations, all testable against the shared conformance suite:

| # | Obligation | Why |
|---|---|---|
| 1 | `coverage` is **total** over all eleven `ActionKind`s | A missing cell would default to something; `unavailable` must be a stated claim (FR-23, FR-28) |
| 2 | `install` / `uninstall` are a **required pair**; both idempotent | An adapter that can register but not de-register leaves a hook with no engine, which denies everything (ADR-007 item 10) |
| 3 | `isRegistered` reads the **host's real config**, never the receipt | A stale receipt must not orphan a live hook ([`data-model.md`](data-model.md) §6.4) |
| 4 | `plannedChanges` performs **no writes** | `--print` is a promise; a `--print` with a side effect is worse than no `--print` |
| 5 | `normalise` is total: every input yields an `Action` or a `NormalisationError` | A partially-parsed action must never be evaluated ([`data-model.md`](data-model.md) §2.3) |
| 6 | `renderDenial` preserves the `GuardError` code and rule ids verbatim | S-04 depends on the agent parsing them |
| 7 | `uninstall` edits host config **surgically** | It is the user's file, possibly hand-maintained |
| 8 | Fixtures are **recorded real host payloads**, not hand-written | A hand-written fixture tests our idea of the host, which is exactly the thing R-05 says will drift |

**One conformance suite runs against every adapter.** This is what makes "the contract before the
adapters" more than an ordering preference: the second adapter either passes the first adapter's suite
or the contract was wrong, and both outcomes are useful.

---

## 9. Compatibility and versioning

| Surface | Stability rule |
|---|---|
| `GuardErrorCode` | **Add only.** Renaming or repurposing a code is breaking; agents parse them |
| Rule ids | Author-owned; the engine never rewrites one. A changed id is a changed rule in the audit log |
| `ActionKind` | Adding a kind is a **breaking change for every adapter** by design ([`data-model.md`](data-model.md) §2.1) |
| RPC methods | Add only; `Policy.apiVersion` gates policy-format changes, and an unknown value is rejected rather than coerced |
| Audit record schema | Add optional fields only. The canonical encoding distinguishes absent from null, so adding a field does not alter existing hashes |
| CLI exit codes | Frozen. CI depends on `2` vs `3` |
| `--json` field names | Add only; removals need a major version |

Under A-1 the adapter and the engine ship in one binary, so RPC skew cannot occur in practice; the
rules above still hold because the **policy file** and the **audit log** outlive any single install,
and both are read by versions that did not write them.

---

**Related**: [`architecture.md`](architecture.md) · [`data-model.md`](data-model.md) ·
[`security.md`](security.md) ·
[`../04-solution-design/routing.md`](../04-solution-design/routing.md) ·
[`../05-adr/004-layered-policy-model.md`](../05-adr/004-layered-policy-model.md) ·
[`../05-adr/005-pluggable-local-model-runtime.md`](../05-adr/005-pluggable-local-model-runtime.md) ·
[`../05-adr/007-cli-integration-strategy.md`](../05-adr/007-cli-integration-strategy.md)
