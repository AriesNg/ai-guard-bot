# 04 — Solution Design: Routing

**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_

> **Phase-gate note.** Drafted ahead of the Phase 3 gate at the product owner's request; rests on
> the assumptions in [`component-design.md` §0](component-design.md#0-assumed-architecture-pending-phase-3),
> each of which is now filed as a Proposed ADR in [`../05-adr/`](../05-adr/README.md).
> The wire contracts below are a Phase 4 *shape*; their canonical schemas belong in Phase 3's
> `api-design.md`.

This product has three routable surfaces. The UI route table that the Phase 4 template asks for is
the least important of them, so it comes third.

1. **Daemon RPC surface** — the enforcement path. Latency-budgeted, authenticated by filesystem
   permissions, split read/write.
2. **CLI command surface** — how a developer and a CI job drive the tool.
3. ~~**Web UI routes**~~ — **withdrawn** (Q-06 answered: a read-only TUI, no web UI). §3 is retained as the view inventory the TUI must cover.

---

## 1. Daemon RPC surface

Transport: JSON-RPC 2.0 over a Unix domain socket at
`$XDG_RUNTIME_DIR/ai-guard-bot/guard.sock` (macOS: `~/Library/Application Support/...`), mode
`0600`, owned by the invoking user. **No TCP listener**, which forecloses remote reach and keeps
the Privacy NFR verifiable rather than argued.

### 1.1 Method table

| Method | Caller | Direction | Budget | Notes |
|---|---|---|---|---|
| `session.open` | Adapter | write | < 50 ms | Registers agent identity + version; returns session id and the coverage report. Rejects an unsupported agent version (R-05). |
| `decide` | Adapter | write | **P95 < 20 ms deterministic / < 300 ms model** | The hot path. One action in, one decision out. Returns only after the audit record is durable. |
| `content.outbound` | Adapter | write | P95 < 50 ms | Mask secrets/PII in content about to leave (FR-13). |
| `content.inbound` | Adapter | write | P95 < 50 ms | Screen a result for prompt injection (FR-14). |
| `ask.resolve` | CLI / UI | write | — | Answers a pending `ask` with allow-once or deny; records actor + justification (FR-25). |
| `session.close` | Adapter | write | < 50 ms | Finalises the session; flushes metrics. |
| `policy.reload` | CLI | write | < 500 ms | Explicit reload; the watcher does this implicitly (FR-26). |
| `policy.validate` | CLI / UI | read | < 500 ms | Parse + merge + narrow-only check without activating (FR-04, FR-05). |
| `policy.simulate` | CLI / UI | read | — | Evaluate a hypothetical action, or replay recent history against a candidate policy (S-10, S-20). |
| `policy.current` | CLI / UI | read | < 20 ms | Active policy, content hash, version. |
| `audit.query` | CLI / UI | read | P95 < 1 s over 1 M records | FR-21 dimensions: session, time range, decision, rule id, action type. |
| `audit.verify` | CLI / UI | read | — | Walks the hash chain; returns verified or the breaking `seq` (FR-20). |
| `decision.explain` | CLI / UI | read | P95 < 50 ms | Renders a recorded decision's trace — winning rule, every candidate, the eliminating precedence key, provenance — **from the record alone**. Evaluates nothing, so it works with the model runtime stopped and the policy deleted (FR-31). |
| `decision.replay` | CLI / UI | read | Deterministic P95 < 100 ms / model < 300 ms | Re-runs a recorded action through the current pipeline with the audit and cache writers disabled; returns `identical`, `divergent` with attribution, or `unreplayable` (FR-32). |
| `audit.stream` | CLI / UI | read | — | Server-push of new records for the live timeline. |
| `audit.export` | CLI | read | — | Structured export to an external pipeline (FR-22). |
| `health` | Any | read | < 20 ms | Engine status, model-runtime availability, policy version, per-CLI coverage (FR-23). |
| `metrics` | Any | read | < 50 ms | Decisions/s by outcome, evaluator mix, latency percentiles, denial rate per rule, override count. |

### 1.2 Authorisation

There is one local user, so there is no authn/authz model in the usual sense — and saying so
explicitly matters more than inventing one. What the surface does enforce:

- **Socket permissions are the authentication.** `0600`, user-owned. Anyone who can open the
  socket already has the user's privileges.
- **Read/write split is enforced at the method level.** The UI's route handlers and the audit
  reader are permitted only the `read` methods in the table above. No caller outside an adapter can
  invoke `decide`, and nothing at all can write an audit record — that is `AuditWriter`'s private
  capability.
- **The guarded agent cannot reach the socket.** The sandbox's `Confinement` excludes the socket
  path and the engine's config directory for every possible policy
  (`component-design.md` §2.5 invariant). This is R-07's mitigation, and it is a construction, not
  a rule an author could forget.
- **Every mutating method is audited**, including `policy.reload` and `ask.resolve`, with the
  actor recorded.
- **`decision.replay` is a `read` method that runs the decision pipeline**, which is the one place
  the split needs stating rather than assuming. It is a read because of what it is forbidden to do:
  it never enforces (no action is dispatched), never appends (the audit writer is absent, not
  bypassed), and never populates the decision cache (so a replay cannot change a later real
  decision). A replay that violates any of the three fails the determinism gate
  ([`testing-strategy.md`](testing-strategy.md) §2.4), which is how this stays a property rather
  than an intention.

### 1.3 Error schema

One shape for every failure, on every surface — RPC, CLI, and UI (`.ai/instructions.md` quality
gate: consistent error schemas).

```ts
interface GuardError {
  code: string;          // stable, namespaced: 'POLICY_INVALID', 'RULE_VIOLATION',
                         // 'EVALUATOR_UNAVAILABLE', 'EVALUATOR_SATURATED',
                         // 'COVERAGE_GAP', 'AGENT_VERSION_UNSUPPORTED',
                         // 'AUDIT_CHAIN_BROKEN', 'POLICY_WIDENS_BASELINE',
                         // 'POLICY_CONFLICT', 'HOOK_TIMEOUT'
  message: string;       // human-readable, actionable — tells the reader what to do instead
  ruleIds?: string[];    // FR-15
  details?: Record<string, unknown>;
  actionId?: string;
  retryable: boolean;
}
```

The denial returned to the agent is this object rendered into the host's own response shape by
`CliAdapter.renderDenial`. Codes are stable across versions — S-04's premise is that the agent
parses them and adapts, which fails the moment a code is renamed.

### 1.4 Hot-path sequence

```mermaid
sequenceDiagram
    participant Host as AI CLI
    participant Ad as Adapter
    participant D as Daemon
    participant P as Pipeline
    participant A as AuditWriter
    Host->>Ad: hook invocation (pre-execution)
    Ad->>Ad: normalise to canonical Action
    Ad->>D: decide(action)
    D->>P: evaluate
    P->>P: cache lookup, then deterministic, hooks, model
    P-->>D: decision + ruleIds + evaluator + latency
    D->>A: append (hash-chained)
    A-->>D: durable
    D-->>Ad: decision
    alt allow or mask
        Ad-->>Host: proceed (content masked if required)
    else deny
        Ad-->>Host: GuardError rendered as host denial
    else ask
        Ad-->>Host: block pending prompt
        D-->>Ad: ask.resolve outcome
    end
```

The audit append sits **before** the response, not after. That ordering is the whole of the
"zero decisions unlogged" guarantee.

---

## 2. CLI command surface

| Command | Purpose | Story |
|---|---|---|
| `guard install [--agent <name>]` | One-command install and enable, including model-runtime provisioning; prints the coverage matrix | S-09, FR-24 |
| `guard uninstall [--agent <name>] [--purge] [--print]` | Detach adapters and remove the guard; `--agent` detaches one integration only; `--purge` also deletes policy, log and model weights; `--print` lists the files it would touch and changes nothing — see §2.1 | S-25, FR-27 |
| `guard status` | Health, policy version, per-CLI coverage, enforcing vs dry-run | FR-23 |
| `guard policy init` | Write an opinionated safe default policy — the zero-authoring path | R-06, persona P4 |
| `guard policy validate [file]` | Parse, merge, narrow-only check; non-zero exit on failure (CI-usable) | FR-04, FR-05, S-18 |
| `guard policy diff` | What the candidate policy would have decided differently over recent history | S-10, S-20 |
| `guard policy reload` | Explicit hot reload | FR-26 |
| `guard log [--session --from --to --decision --rule --kind]` | Query the audit log | FR-21, S-07 |
| `guard log verify` | Hash-chain verification; non-zero exit on a break | FR-20 |
| `guard log export [--format]` | Structured export | FR-22, S-14 |
| `guard dry-run <command…>` | Run an agent session with enforcement off but logging on | FR-16, S-10 |
| `guard allow-once <actionId> --reason <text>` | Resolve a pending `ask` | FR-25, S-15 |
| `guard audit view` | Open the **read-only TUI** audit viewer in the terminal (Q-06) | S-24 |
| `guard explain <actionId \| --seq N> [--json]` | Why that decision came out that way: the winning rule, every rule that matched, and the precedence key that eliminated each loser, plus the provenance it was decided under. Reads the record; evaluates nothing | S-26, FR-31 |
| `guard replay <actionId \| --seq N> [--policy <version>] [--no-model]` | Would it still decide the same way? Exit `4` on divergence, with the divergence attributed to policy, provenance or model non-determinism | S-26, FR-32 |

Conventions: exit `0` allow/success, `1` operational error, `2` policy invalid, `3` denied,
**`4` replay divergence** — scriptable. Human output respects `NO_COLOR` and works without colour; `--json` on every read
command for machine use (Accessibility NFR).

### 2.1 Removal semantics (`guard uninstall`)

Removal is **not** the install sequence reversed. Install provisions bottom-up (runtime, daemon,
adapters); removal must proceed **top-down**, and the ordering is load-bearing rather than
cosmetic.

```mermaid
flowchart TD
    A["guard uninstall"] --> B{"--print?"}
    B -- yes --> P["list every file that would change; exit 0; touch nothing"]
    B -- no --> C["enumerate installed adapters<br/>(from install receipt + live probe)"]
    C --> D["de-register each adapter from the host CLI config<br/>hooks removed, MCP proxy entry removed"]
    D --> E{"any adapter still registered?"}
    E -- yes --> X["abort, daemon left RUNNING, exit 1<br/>guard stays functional, nothing is half-removed"]
    E -- no --> F["append terminal audit record<br/>kind=guard.removed, chain-valid"]
    F --> G["stop daemon, remove socket + service definition"]
    G --> H{"--purge?"}
    H -- no --> I["retain policy, audit log, model weights<br/>print their paths"]
    H -- yes --> J["confirm, then delete policy, audit log, model weights"]
```

**Why this order.** Under the fail-closed default
([ADR-009](../05-adr/009-fail-closed-default.md)) an adapter that cannot reach the daemon denies the
action. If the daemon were stopped first, every action the host CLI attempted in the interval
between daemon shutdown and hook removal would be **denied**, and a crash inside that interval
would leave the host CLI permanently unable to act. Stopping the engine while a hook is still
registered is therefore the one genuinely destructive sequencing error available to this command,
and step **E** exists to make it unreachable: if any adapter cannot be de-registered, the command
aborts with the daemon still running and the guard still working. A failed uninstall leaves a
working guard, never a broken host CLI.

**Detach versus purge.**

| Invocation | Adapters | Daemon | Policy file | Audit log | Model weights |
|---|---|---|---|---|---|
| `guard uninstall --agent claude-code` | that one removed | kept running | kept | kept | kept |
| `guard uninstall` | all removed | stopped, removed | kept | kept | kept |
| `guard uninstall --purge` | all removed | stopped, removed | **deleted** | **deleted** | **deleted** |

Retention is the default because the audit log is the product's evidence record and is
hash-chained ([ADR-006](../05-adr/006-audit-log-integrity.md)); silently destroying it on removal
would delete exactly the history a user is most likely to want *after* deciding to stop using the
tool. `--purge` prompts for confirmation on an interactive terminal and requires `--yes` when
stdin is not a TTY.

**Terminal audit record.** A hash chain that simply stops is indistinguishable from truncation, so
`guard log verify` would report a removed install as a suspected tamper. Removal therefore appends
a final `guard.removed` record — carrying the timestamp, the adapters removed, and whether
`--purge` was requested — as the last link, before the daemon stops. Verification of a removed
install is then expected to succeed and to end on that record.

**Idempotency and broken state.** `guard uninstall` must succeed (exit `0`) when the install is
already partially gone — binary present but hooks hand-edited away, daemon already dead, receipt
file missing — reporting each component as `removed`, `not found`, or `already absent`. It
discovers adapters from the install receipt *and* by probing the known host-CLI config locations,
so a lost receipt does not orphan a live hook. Exit `1` is reserved for a removal it attempted and
could not complete.

---

## 3. ~~Web UI routes~~ — withdrawn; retained as the TUI's view inventory

> **Q-06 answered 2026-10-02:** there is no web UI and no HTTP surface
> ([ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md),
> [ADR-011](../05-adr/011-v1-scope-envelope.md)); the product binds no TCP port in any configuration
> ([ADR-003](../05-adr/003-local-daemon-over-unix-socket.md) item 4). **No route below is
> implemented.** The table survives as the list of **views the TUI must cover** and the daemon call
> each one needs — read the "Path" column as a view name and ignore the rendering column. The
> `/policy` row becomes a **read-only** policy viewer; authoring stays in the config file, checked
> with `guard policy validate` and applied with `guard policy reload` (§2).

Original (web) design, for the inventory only. Localhost-bound; auth reads "local socket" for every
row — there is no login, because there is no remote access and no second user, and inventing one
would imply a security boundary that does not exist.

| Path | Component | Rendering | Loader | Error boundary |
|---|---|---|---|---|
| `/` | `DashboardPage` | RSC, `revalidate: 30` | `health` + `metrics` | Route-level → "engine unreachable" state |
| `/sessions` | `SessionListPage` | RSC, dynamic (URL filters) | `audit.query` grouped by session | Route-level |
| `/sessions/[id]` | `SessionDetailPage` | RSC shell + streamed timeline | `audit.query` by session, `audit.verify` | Route-level; `notFound()` on unknown id |
| `/decisions/[actionId]` | `DecisionExplainPage` | RSC | `decision.explain` | Route-level; `RECORD_NOT_FOUND` → not-found state, `TRACE_UNAVAILABLE` → an explicit "written before traces" state, never a blank panel |
| `/policy` | `PolicyEditorPage` | RSC shell + client editor | `policy.current` | Route-level; keeps the unsaved draft |
| `/policy/simulate` | `SimulatePage` | RSC shell + client form | `policy.current` | Route-level |
| `/settings` | `SettingsPage` | RSC | local preferences + `policy.current` paths | Route-level |
| `/api/*` | Route handlers | Server only | Proxy to daemon **read methods only** | Returns `GuardError` unchanged |

### 3.1 Route-level rules

- **No client component calls the daemon.** Everything goes through a Server Component or a route
  handler, so the socket path and the read-only restriction cannot be bypassed from the browser.
- **Route handlers are a read-only proxy**, with the permitted method list allowlisted in code, not
  derived from the request. The single exception is the policy-save Server Action, which writes the
  policy file (not an audit record) with optimistic concurrency on the content hash
  (`state-management.md` §B.3).
- **Filters are URL state** (`state-management.md` §B.4), so every view is deep-linkable —
  `/sessions?decision=deny&rule=R-014&from=…` is the shareable artefact Priya hands to a developer.
- **Error boundaries are per route segment**, and the daemon-unreachable state is an explicit
  render, never an empty table. A UI that shows an empty audit log because it could not reach the
  engine misleads the person relying on it.
- **Layouts**: one root `AppShell` with `NavRail`; `/policy/*` shares a layout carrying the
  unsaved-draft guard across its two routes.
- **Navigation accessibility**: skip-to-content link, `aria-current` on the active nav item, focus
  moved to the `<h1>` on route change, and route transitions announced in an `aria-live` region.

### 3.2 Route-to-story map

| Route | Stories |
|---|---|
| `/` | S-06, S-17, FR-23 |
| `/sessions`, `/sessions/[id]` | S-06, S-07, S-19 |
| `/policy` | S-01, S-10, S-18, S-19, S-20 |
| `/policy/simulate` | S-10, S-20 |
| `/decisions/[actionId]` | S-26, FR-30, FR-31 |
| `/settings` | S-21 |

---

## 4. Blocking questions

Q-02, Q-04 and Q-06 were answered on 2026-10-02: §1.1 is implemented **twice** (Claude Code hook and
MCP proxy), the socket path convention covers **macOS and Linux only**, and §3 is withdrawn
([ADR-011](../05-adr/011-v1-scope-envelope.md)). Q-09 was answered later the same day
([ADR-013](../05-adr/013-model-and-language-resolution.md)): the product is **single-language
Rust**, so the RPC codec and `shared/api` stay one hand-written type set with no code-generation
step. Nothing in this document is blocked any more.

**Related**: [`component-design.md`](component-design.md) ·
[`state-management.md`](state-management.md) · [`testing-strategy.md`](testing-strategy.md) · ADRs
[003](../05-adr/003-local-daemon-over-unix-socket.md) (socket transport, method split),
[007](../05-adr/007-cli-integration-strategy.md) (`GuardError` rendered per host),
[009](../05-adr/009-fail-closed-default.md) (adapter timeout, error codes)
