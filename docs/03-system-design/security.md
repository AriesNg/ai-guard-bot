# 03 — System Design: Security Architecture

**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_

> **Phase-gate note.** Drafted ahead of the Phase 3 prerequisite (**UX Design approved**) at the
> product owner's explicit request; carries assumptions **A-1 … A-3** from
> [`architecture.md`](architecture.md).

This is a security product, so this document has an unusual obligation: it must be **publishable**.
FR-18 requires a threat model that names what is and is not stopped, and
[ADR-008](../05-adr/008-sandbox-confinement-primitive.md) fixes the governing rule:

> **A boundary claim without a passing adversarial test is deleted from the threat model, not
> softened.**

Everything below is written to that standard. §3 is the list of things this product does **not**
prevent, stated plainly and first-class, because a guardrail that overstates its boundary is more
dangerous than one that has none — the user stops checking.

---

## 1. The adversary, fixed

**Q-03 answered 2026-10-02** ([ADR-011](../05-adr/011-v1-scope-envelope.md)): the v1 adversary is **an
agent that errs**, not one actively trying to escape.

| In the model | Out of the model |
|---|---|
| An agent that misunderstands a task and runs a destructive command | A human attacker with local shell access |
| An agent that reads a credential file it had no reason to read | Local root, or anything with `CAP_SYS_ADMIN` |
| An agent that exfiltrates a secret into a prompt or an API call without intent to | Kernel vulnerabilities in the confinement primitive |
| An agent **steered by injected content** in a tool result or MCP response | A user who deliberately disables the guard (they own the machine) |
| An agent that attempts an action class the adapter does not intercept | Supply-chain compromise of the host CLI itself |

The injected-content row is the sharp edge, and §3 states exactly what is claimed there — because this
is the one row where the honest claim is "detected and logged", not "prevented".

---

## 2. The confinement boundary, per platform

[ADR-008](../05-adr/008-sandbox-confinement-primitive.md) chose OS-native primitives and delegated the
`BoundaryDescription` to Phase 3. **The boundary is data, not prose**: the executor publishes it, the
threat model is generated from it, and the adversarial gate tests it. A claim that is not in this
structure cannot be published, and a structure field whose test fails is removed from the structure.

```ts
interface BoundaryDescription {
  platform: 'macos' | 'linux';
  primitive: string;                     // the mechanism, named
  enforces: Enforcement[];               // each entry REQUIRES a passing adversarial test
  doesNotEnforce: string[];              // published verbatim; see §3
  verifiedBy: string[];                  // test ids in the adversarial gate
}

interface Enforcement {
  dimension: 'fs.read' | 'fs.write' | 'exec' | 'net' | 'proc';
  mechanism: string;
  granularity: string;
  testId: string;                        // must exist and must pass, or this entry is deleted
}

interface Confinement {
  fs:   { read: AbsolutePath[]; write: AbsolutePath[] };
  net:  { allow: HostPattern[] };
  proc: { allowExec: boolean; allowFork: boolean };
}
```

### 2.1 macOS

| Dimension | Mechanism | Granularity | Claim |
|---|---|---|---|
| `fs.read` / `fs.write` | Seatbelt (`sandbox_init`) with a generated profile | Path prefix, allowlist | **Enforced** — reads and writes outside the allowlist fail at the syscall |
| `exec` | Seatbelt `process-exec` restriction | Boolean plus path allowlist | **Enforced** |
| `net` | Seatbelt `network-outbound` restriction | Deny-all, or allowlist by host where the profile can express it | **Enforced for deny-all**; host-granularity allowlisting is claimed **only** where a passing test demonstrates it, and otherwise the allowlist degrades to deny-all rather than to allow-all |
| `proc` | Fork restriction via the profile | Boolean | **Enforced** |

The `net` row shows the rule working. Seatbelt's host-level expressiveness is not uniform across
versions, so the claim is conditional on a test — and the **degradation direction is specified**: an
inexpressible allowlist becomes deny-all. A guardrail that widened on uncertainty would be the
fail-open this product does not have.

### 2.2 Linux

| Dimension | Mechanism | Granularity | Claim |
|---|---|---|---|
| `fs.read` / `fs.write` | **Landlock** ruleset, nested per execution | Path hierarchy, allowlist | **Enforced** where the kernel's Landlock ABI supports the needed access rights |
| `exec` | **seccomp-bpf** filter on `execve`/`execveat` | Syscall-level boolean | **Enforced** |
| `net` | **Network namespace** with no interfaces (deny-all), or a restricted path for allowlisting | Deny-all is absolute; host allowlisting requires a proxy, not a kernel filter | **Deny-all enforced.** Host-level allowlisting is **not claimed at the kernel boundary** — it is policy-level, applied at `net.request` interception, and the threat model says so |
| `proc` | seccomp-bpf on `clone`/`fork` | Syscall-level boolean | **Enforced** |

**Kernel ABI is a startup check, not a runtime hope.** If the running kernel's Landlock ABI cannot
express the rights the confinement needs, the daemon **refuses to start** (`CONFINEMENT_UNAVAILABLE`)
rather than executing with a weaker boundary than the one the threat model publishes. Degrading
silently would make the published document false on exactly the machines where it mattered.

### 2.3 Windows

**Unsupported. No Windows boundary claim is published** ([ADR-011](../05-adr/011-v1-scope-envelope.md)).
There is no `BoundaryDescription` for Windows, no partially-tested profile, and no "best effort" mode.
A boundary nobody tested on a real kernel is not a boundary, and shipping one would be the single
cheapest way to make everything else in this document untrustworthy.

---

## 3. What this product does not prevent

Published verbatim, as [ADR-008](../05-adr/008-sandbox-confinement-primitive.md) item 12 requires.
This section is part of the product's documentation, not an internal caveat.

1. **Injection-driven escape is detected and logged, never prevented.** An agent steered by malicious
   content in a tool result, a fetched page, or an MCP server response is still an agent acting within
   its granted capabilities. The guard evaluates the *action*, so an injected instruction that asks for
   something policy permits will be permitted. Inbound screening (FR-14) **annotates and logs**
   suspicion; it does not block, and it must not be read as a defence.
2. **A human with local shell access is not constrained.** They own the machine. They can edit the
   policy, stop the daemon, or remove the product.
3. **Local root, or any privilege able to load kernel code, debug the daemon, or alter its binary, is
   outside the model.** Confinement is applied by the kernel at our request; a privilege that outranks
   that request outranks the guard.
4. **Kernel vulnerabilities in Seatbelt, Landlock, seccomp or namespaces are not mitigated.** Choosing
   OS-native primitives means inheriting their bugs — which remains better than hand-rolling a boundary
   that would be a new attack surface claiming to be a mitigation.
5. **An action class the adapter does not intercept is denied, not guarded.** A `COVERAGE_GAP` denial is
   a refusal to act, not a successful inspection. Where interception is impossible, the product refuses
   to advertise support for that CLI at all (R-04).
6. **The guard does not protect the agent's own model provider channel.** The agent's inference traffic
   is outside the decision path entirely ([`architecture.md`](architecture.md) §2).
7. **Timing and resource side-channels are not addressed.** An agent can learn a rule exists from a
   denial; that is intended (FR-15) and the denial names the rule on purpose.
8. **Masking is detection-bounded.** FR-13's targets are ≥ 99 % recall on structured secrets and
   ≥ 90 % on semantic PII — explicitly not 100 %. A secret in a shape no detector knows will pass, and
   the audit log records what was screened so the gap is discoverable after the fact.
9. **The audit log proves tampering, it does not prevent it.** A user who can write the log file can
   truncate or delete it. The hash chain makes that **evident** — which is the achievable guarantee, and
   it is stated as such rather than dressed up as immutability.

---

## 4. Authentication, authorisation, and the engine's own perimeter

### 4.1 One principal, stated rather than modelled

There is **one local user**. The authentication is the socket's file permissions (`0600`, user-owned);
anyone who can connect already holds the user's privileges. No token, key or session secret exists
anywhere in the product, and adding one would create a secret to protect without creating a boundary
([`api-design.md`](api-design.md) §2.2).

Authorisation is the **method-level read/write split**, allowlisted in the dispatch table in code and
not derived from anything the caller asserts; `decide` and `content.*` additionally require an opened
session with an accepted agent identity, and **no caller can append an audit record** because appending
is not on the method catalogue at all ([`api-design.md`](api-design.md) §3.2).

### 4.2 R-07: the engine's state is outside the agent's reach, by construction

R-07 is the risk that the guarded agent modifies the thing guarding it. It is mitigated **structurally**,
as four invariants enforced where the types are built rather than as rules a policy author must
remember:

| # | Invariant | Enforced by |
|---|---|---|
| 1 | No `Confinement` can include the socket path, the policy file, the audit log, the install receipt, or the engine's config directory in `fs.write` | `Confinement`'s **validating constructor** subtracts the engine's reserved path set from every allowlist it is asked to build. There is no path through which a policy — however written — produces a confinement containing them. |
| 2 | The reserved path set is computed from the engine's own resolved paths at startup, not from a constant list | A relocated config directory cannot fall outside the protection by being unlisted |
| 3 | Audit append is unreachable from outside the pipeline | Not an RPC method; `AuditWriter` is a private capability ([`architecture.md`](architecture.md) §4.3) |
| 4 | Policy writes belong to the CLI, never to the daemon or the TUI | The daemon only ever *reads* policy; the TUI holds read methods only |

Invariant 1 is on the **never-mocked** list
([`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md) §3) and is
property-tested: for arbitrary generated policies, the resulting confinement never contains a reserved
path. A test that could only be written by mocking the constructor would be testing the mock.

### 4.3 The socket path is part of the threat model

[ADR-003](../05-adr/003-local-daemon-over-unix-socket.md) requires treating the socket path as a
security-relevant decision, not an implementation detail:

- The parent directory is created by the engine with mode `0700`, **and its mode and ownership are
  verified on every startup**. A pre-existing directory with wrong permissions or wrong ownership is a
  refusal to start, not a corrected-and-continued condition.
- The socket is unlinked and recreated at startup; a stale socket from a dead daemon is inert, but a
  socket that is *not* ours — a symlink, a different file type, or a file owned by another uid — is
  treated as hostile and refuses startup rather than being replaced.
- The path lives under a per-user runtime directory (`$XDG_RUNTIME_DIR`, or the macOS equivalent),
  **never** `/tmp` or any world-writable location, which would make a pre-creation race available to
  any local process.
- The socket path is in the reserved set of §4.2 invariant 1, so no policy can grant the guarded agent
  write access to it.

---

## 5. Input validation

Every boundary, and what makes each one adversarial rather than merely malformed-input handling:

| Boundary | Validation | If invalid |
|---|---|---|
| Host payload → `Action` | Total `normalise`; path canonicalisation with a validating `AbsolutePath` newtype; argv parsed, never guessed; URL host IDNA-normalised ([`data-model.md`](data-model.md) §2.3) | `NORMALISATION_FAILED` → **deny**. Never evaluated partially parsed |
| Policy file → `VersionedPolicy` | Total schema + semantic validation; narrowing check; precedence-tie check ([`data-model.md`](data-model.md) §3.1) | `POLICY_INVALID` / `POLICY_WIDENS_BASELINE` / `POLICY_CONFLICT`; **previous version stays active** |
| RPC request | JSON-RPC envelope, method allowlist, R/W check, schema per method, total `coverage` map | `INVALID_REQUEST`; no partial application |
| Model output | **Constrained decoding** — the grammar makes non-conforming output unreachable; a runtime that cannot be constrained is rejected at startup ([`api-design.md`](api-design.md) §7) | `EVALUATOR_MALFORMED` → **deny** |
| Hook output | Fixed schema, hard timeout, bounded output size | `HOOK_TIMEOUT` or malformed → **deny** |
| Inbound content | Screened, size-bounded, **never interpreted as instruction by the engine** | Annotated and logged; content returned unchanged |
| Host config (on removal) | Parsed, our entry located structurally, surrounding content preserved byte-for-byte | Report `already-absent` and exit `0` rather than rewriting the user's file |

The row that distinguishes this product from ordinary input validation is the model-output row.
Everything else validates data that is merely wrong; that row validates data that is *generated*, and
the defence is to make the invalid shape undecodable rather than to parse it carefully.

---

## 6. Rate limiting, saturation and backpressure

The review checklist asks for a rate-limiting strategy. There is no untrusted network caller to
rate-limit, so the real problem is **resource exhaustion on the decision path** — and a guardrail under
load must get slower or refuse, never permissive.

| Mechanism | Limit | Behaviour at the limit |
|---|---|---|
| Model work queue | Bounded depth (configured, with a conservative default) | **Reject with `EVALUATOR_SATURATED` → deny.** Never queue unboundedly, never time-out into allow |
| Per-session fairness | Round-robin across open sessions | One runaway session cannot starve the other three (≥ 4 concurrent sessions NFR) |
| Hook execution | Hard wall-clock timeout, bounded output, no network | `HOOK_TIMEOUT` → deny. A hook cannot hold the pipeline open |
| Decision cache | Bounded entries, per-session scope, LRU | Eviction costs latency, never correctness ([`data-model.md`](data-model.md) §5.4) |
| Audit append | Single writer; durability barrier per record | Failure is `AUDIT_WRITE_FAILED` → **deny**. A decision whose record is not durable is not returned |
| Content screening | Size cap per request | Over-cap content is **not** silently truncated and passed — it denies for outbound, and is annotated as unscreened for inbound |
| Policy reload | Debounced on filesystem events | A file written in a loop cannot thrash the swap; the previous version stays active until a new one validates |

**`retryable: true` is a hint to the agent, never an adapter's licence to retry automatically**
([`api-design.md`](api-design.md) §5). An adapter retrying a saturation denial on its own would convert
backpressure into a stampede, which is the standard way a bounded queue stops being a protection.

---

## 7. Secrets, privacy and data handling

| Rule | Where it is enforced |
|---|---|
| **No network egress from the guard, in any configuration.** No telemetry, no update check, no model download at decision time | [ADR-003](../05-adr/003-local-daemon-over-unix-socket.md); inspectable with `lsof`/`ss` because there is no listener and no outbound client in the decision path |
| **The canonical `Action` never carries secret values** — env **names** only, byte counts instead of contents | [`data-model.md`](data-model.md) §2.4 |
| **`Finding` has no `value` field**, by construction — detector id, category and span only | [`data-model.md`](data-model.md) §4. A detector that returned matched text would put every secret it found into the audit log |
| **Only a `RedactedAction` reaches the model** — structure, no content | [`api-design.md`](api-design.md) §7.3 |
| **The audit log stores `MaskedPayload`**, with findings already replaced | [`data-model.md`](data-model.md) §5.1 |
| **Log and policy are user-owned, `0600`**, in the user's own directories | §4.3 |
| **Removal retains the log by default** and prints its path; `--purge` deletes it with confirmation | FR-27; [`api-design.md`](api-design.md) §4.2 |

The audit log is the one place secrets could plausibly accumulate, which is why masking happens
**before** the record is built rather than at query time. Masking at read time would mean the plaintext
was on disk and the protection was a view.

---

## 8. CORS — not applicable, with the reason

**N/A.** The product binds **no TCP port in any configuration** and serves no browser origin: there is
no HTTP surface, no web UI, and no asset-serving path
([ADR-003](../05-adr/003-local-daemon-over-unix-socket.md) item 4,
[ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md),
[ADR-011](../05-adr/011-v1-scope-envelope.md)). CORS is a browser mechanism for cross-origin HTTP; with
no origin and no HTTP there is nothing for a policy to govern.

**Publishing a CORS policy here would be actively harmful**, not merely redundant: it would imply an
HTTP surface exists, and a future reader could reasonably conclude that binding a port is within the
design's intent. The correct artefact is this statement plus the structural guarantee behind it — and
the guarantee is testable: the adversarial gate asserts that no listening socket other than the UDS
exists in any supported configuration.

Related checklist items for the same reason: there is no CSRF surface (no browser, no cookies), no
session fixation surface (no sessions in the HTTP sense), and no TLS configuration (no network
transport).

---

## 9. Threat-to-mitigation map

| Threat | Mitigation | Verified by |
|---|---|---|
| Agent runs a destructive command | Deterministic rules cover every catastrophic class and decide first; `deny` outranks everything on strength | Accuracy gate (≥ 95 % deny recall, ≤ 2 % false deny, FR-11) |
| Agent reads credentials | Path canonicalisation + credential-path deterministic rules; confinement `fs.read` allowlist | Adversarial: path-normalisation bypass set (`../../`, `~`, symlink, case) |
| Secret exfiltrated in content | Outbound screening ≥ 99 % structured-secret recall, ≤ 1 % FP (FR-13) | Accuracy gate, secret/PII corpus |
| **Interception bypassed** | Deny-by-default for unmapped kinds (FR-10); total coverage matrix asserted at startup; the matrix's eleven kinds are the `ActionKind` enum | **Adversarial gate: red-team action set that tries to reach the OS around every interception point** |
| **Self-weakening** — the agent edits policy, log, or the engine's config | R-07 invariants in §4.2, enforced in `Confinement`'s constructor; policy writes belong to the CLI alone | Adversarial + property test over generated policies |
| **Audit tampering** | Hash chain, single writer, durable-before-return, refuse-to-append-past-a-break, segment sealing, `guard.removed` terminal record | Adversarial: edit/truncate/reorder/forge-terminal-record cases |
| **Prompt injection via inbound content** | Screened, annotated and **logged**; never claimed as prevented (§3 item 1) | Adversarial: injection corpus asserts detection and logging — **not** blocking |
| **Model manipulation** | The model answers only `{matches, confidence, reason}`; the **policy author** supplies the decision, so a compromised runtime cannot widen policy or invent a rule | Adversarial: adversarial intent-rule inputs; grammar-violation and conformance-probe cases |
| **Saturation as a way to get a permissive answer** | Bounded queue → `EVALUATOR_SATURATED` → **deny**; no timeout path reaches allow | Adversarial: flood the queue and assert deny; performance gate measures the degradation |
| Confinement escape | OS-native primitive, per-platform claims each backed by a test; unavailable primitive → refuse to start | Adversarial on **real kernels**, macOS **and** Linux, in CI |
| **Boundary over-claiming** | A claim without a passing test is **deleted** from `BoundaryDescription`; Windows has no claim at all | The generated threat model is diffed against the gate's results; an undefended claim fails the build |
| Broken uninstall bricks the host CLI | Top-down teardown, probe-verified, abort-with-guard-running | Adversarial: kill the process at each teardown step; E2E 11 and 12 |

The last-but-one row is the structural one: **the published threat model is generated from
`BoundaryDescription` and diffed against the adversarial gate's results, so an undefended claim fails
CI.** That is what makes §2 and §3 maintainable rather than a document that drifts from the code.

---

## 10. Accessibility as a security property

Not a courtesy item. A security control a developer cannot read is a control that gets bypassed:

- **A denial is never conveyed by colour alone.** Every denial carries the rule id and the reason as
  text; `NO_COLOR` and non-TTY output lose no information ([`api-design.md`](api-design.md) §4.1).
- **`guard audit query` is the full screen-reader-equivalent path** to everything the TUI can show, so
  reviewing the evidence record never requires a visual grid.
- **Contrast ≥ 4.5:1** for TUI body text in both themes; keyboard-only operation throughout.
- Verified by the blocking a11y CI stage and 80×24 / 120×40 golden text grids
  ([`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md) §1a).

---

## 11. Security review checklist

| Criterion | Status | Where |
|---|---|---|
| Authentication on every endpoint | ✅ | §4.1 — socket permissions, uniform across all 17 methods |
| Authorisation on every endpoint | ✅ | §4.1, [`api-design.md`](api-design.md) §3.2 — method-level R/W allowlist plus capability restriction |
| Encryption in transit | **N/A, with reason** | No network transport exists; a UDS does not leave the kernel. Encrypting it would protect against nothing and imply remote reach |
| Encryption at rest | **Not claimed** | Log and policy are user-owned `0600` files; the product relies on the OS and the user's full-disk encryption, and says so rather than implying its own. Integrity (not confidentiality) is the log's guarantee — §3 item 9 |
| Input validation at every boundary | ✅ | §5 |
| Rate limiting | ✅ | §6 |
| Secrets handling | ✅ | §7 |
| CORS policy | **N/A, with reason** | §8 |
| Threat model published | ✅ | §1–§3, §9 — and generated from `BoundaryDescription`, so it cannot drift from the tests |
| Audit logging of security-relevant events | ✅ | Every decision, every override, every policy transition, every removal ([`data-model.md`](data-model.md) §5.1) |
| Least privilege | ✅ | Runs as the invoking user, never root; confinement allowlists; §4.3 |

---

**Related**: [`architecture.md`](architecture.md) · [`data-model.md`](data-model.md) ·
[`api-design.md`](api-design.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) (FR-18, R-02, R-04, R-07) ·
[`../05-adr/008-sandbox-confinement-primitive.md`](../05-adr/008-sandbox-confinement-primitive.md) ·
[`../05-adr/009-fail-closed-default.md`](../05-adr/009-fail-closed-default.md) ·
[`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md)
