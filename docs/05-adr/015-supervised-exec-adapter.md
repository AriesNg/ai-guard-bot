# ADR-015: Supervised-exec as a third adapter shape — Linux-only, post-v1, declared not claimed

## Status
Proposed — **post-v1**. Blocked on **Q-10** (is a Linux-only capability acceptable under ADR-007 §6's
complete-matrix rule) in [`../01-discovery/requirements.md`](../01-discovery/requirements.md).

This ADR does not add work to v1. It exists because [ADR-007](007-cli-integration-strategy.md)
leaves a hole that is currently invisible, and a deferral whose reasoning is written down is
reopenable; one that is not written down is re-argued from scratch.

## Context

FR-09 requires that a CLI without a documented hook interface still be servable — "via an MCP proxy
**or** process-level interception". [ADR-007](007-cli-integration-strategy.md) designs the first and
leaves the second undesigned. The consequence is narrow but real:

> A host CLI that offers **neither** a hook interface **nor** MCP traffic — a plain agent that
> spawns a shell and writes files directly — has no interception point. Under ADR-007 §5 every
> `ActionKind` is then `unavailable`, and under FR-10 every action is denied. The product does not
> *mis-serve* such a host; it cannot serve it at all.

ADR-007's Rejected Alternatives already dismiss "pure OS-level interception only" as the *primary*
mechanism, and retain it as "a component of the FR-09 fallback and as defence in depth". Nothing
since has said what that component is. This ADR names it, bounds it, and defers it.

The proposal considered here is the one raised in review on 2026-10-02: rather than integrate per
host, run the host CLI inside a confinement domain and have the kernel ask the guard about each
action — a "sandbox the guardrail reviews". The mechanism exists on Linux. It does not exist
portably, and that asymmetry is what this ADR has to resolve.

Forces:

- **Platform parity is a confirmed v1 constraint** ([ADR-011](011-v1-scope-envelope.md)): macOS and
  Linux, both adversarially tested on real kernels.
- **ADR-007 §6** forbids advertising support for a CLI until its coverage matrix is complete.
- **ADR-008 §1** forbids presenting a non-boundary as a boundary, and **§3** deletes any claim
  without a passing adversarial test.
- **ADR-009** makes fail-closed a default value rather than a branch, which constrains what a
  supervisor may do when it cannot answer in time.
- **ADR-002**'s P95 < 10 ms adapter overhead budget, per action.
- **S-09**'s one-command, five-minute install.

### Mechanism availability

| Capability | Linux | macOS |
|---|---|---|
| Hold an action pre-execution, ask userspace, allow/deny | `seccomp` user notification (`SECCOMP_USER_NOTIF`) | Endpoint Security framework `AUTH` events |
| Ships without vendor permission | Yes — ordinary unprivileged process | **No** — notarized system extension **plus** the `com.apple.developer.endpoint-security.client` entitlement, granted by Apple per organization on review |
| Response deadline | Supervisor-paced; no kernel-imposed deadline on the notification | **Yes** — `AUTH` events must be answered within the kernel's window or the default action is applied |
| Install cost | None beyond the binary | System-extension approval, Full Disk Access |

`seccomp` is a Linux kernel facility. macOS runs the XNU/Darwin kernel and has no `seccomp`, no
Landlock, and no network namespaces; the shell in use (`zsh`, `bash`) is irrelevant, because the
mechanism is in the kernel and not in the shell. The same shell binary is supervisable on Linux and
not on macOS.

## Decision

1. **Process-level supervision is a third `CliAdapter` implementation**, behind the same contract as
   the hook adapter and the MCP proxy ([ADR-007](007-cli-integration-strategy.md) §1, §3). The core
   remains unaware of which path delivered an action; the adapter is the only place the supervision
   mechanism is known.
2. **Interception is at process granularity, never syscall granularity.** The adapter supervises
   `execve` and `connect` only, synthesising `shell.exec` and `net.request` actions. `openat`-level
   supervision — and therefore `fs.read` / `fs.write` via this path — is **rejected in this
   document** so that the latency argument is settled once rather than relitigated per sprint:
   `execve` carries `argv`, which is intent; `openat` arrives tens of thousands of times per
   ordinary build and carries none.
3. **Linux only.** No macOS implementation is planned, and no macOS equivalent is pursued. On macOS
   the affected action classes remain with the hook and proxy adapters, and this adapter's **macOS
   row in the coverage matrix is empty rather than optimistic**
   ([ADR-007](007-cli-integration-strategy.md) §4).
4. **Defence in depth, never a published boundary claim.** Supervised exec does not appear in any
   `BoundaryDescription` ([ADR-008](008-sandbox-confinement-primitive.md) §2) and is not described as
   confinement in any material. It is an *interception point* — a source of actions for the pipeline
   — and the confinement that bounds an approved action remains ADR-008's spawn-time primitive.
5. **A supervisor that cannot answer in time denies.** Whatever the mechanism's deadline behaviour,
   the adapter's own timeout fires first and resolves to `deny`, per
   [ADR-009](009-fail-closed-default.md). The audit record distinguishes a **deadline-driven denial**
   from a **policy denial**, because conflating them makes a performance problem look like a policy
   problem and would be debugged as the wrong thing for a long time.
6. **Supervision is not an escape boundary, and the threat model says so.** A supervised process can
   defeat `execve`-granularity interception by doing the work in-process — an interpreter one-liner
   performing a write is one `execve`, and its contents are not inspected. Under
   [ADR-011](011-v1-scope-envelope.md)'s erring-agent threat model this is acceptable; it would not
   be under an actively-escaping one, and the limitation is published in those terms.
7. **Post-v1, gated behind the contract being proven.** v1 ships exactly two adapters
   ([ADR-011](011-v1-scope-envelope.md)), and ADR-007 §1 wants the `CliAdapter` contract validated by
   the hook/proxy pair — two deliberately different shapes — before a third is added. Building this
   adapter concurrently would make the contract accommodate a mechanism no v1 user runs.
8. **A host served only by this adapter ships as explicitly experimental**, with its gaps printed on
   every session start ([ADR-007](007-cli-integration-strategy.md) §6), and on macOS such a host is
   **unsupported** rather than partially supported.

## Rationale

- **The hole is real and currently invisible.** FR-09 offers two paths and the design has one. A
  reader of ADR-007 would reasonably conclude process-level interception is designed somewhere. It
  is not, and the first person to need it would rediscover every constraint in this document.
- **Process granularity is the only version that survives the latency budget.** The P95 < 10 ms
  budget is per action. At `execve` granularity the event rate is tens per minute and a
  model-in-the-loop decision fits; at `openat` granularity the rate is thousands per second and it
  does not. This is not a tuning gap to be closed later — it is two orders of magnitude, and writing
  it into the decision prevents a future sprint from "just adding `fs` coverage".
- **Declaring a Linux-only capability is honest; advertising support on it is not.** ADR-007 §6
  exists so that support claims are checkable against the matrix. A capability that improves Linux
  coverage while leaving the macOS row empty is a legitimate thing to *have* and an illegitimate
  thing to *claim*. Q-10 is what decides whether the matrix machinery tolerates the asymmetry at all.
- **Separating interception from confinement keeps ADR-008's honesty discipline intact.** The word
  "sandbox" invites the reader to infer per-action kernel review. ADR-008's boundary is spawn-time
  allowlisting. Putting supervised exec on the interception side of that line, explicitly, is what
  stops the stronger property from being implied by vocabulary.
- **Apple's entitlement is a distribution blocker, not an engineering one.** The macOS analogue to
  `SECCOMP_USER_NOTIF` genuinely exists and genuinely blocks, so the reason to decline it has to be
  stated precisely: the entitlement is granted to an organization on review, a single-user side
  project ([ADR-011](011-v1-scope-envelope.md)) cannot assume it, and without it the code runs on no
  user's machine. ADR-008 §3 would then delete any claim resting on it.

Trade-offs accepted:

- **The FR-09 hole stays open through v1.** A hookless, MCP-less host remains unservable until this
  is built. The mitigation is that it is now a named gap rather than an unexamined one.
- **Linux and macOS coverage will differ** if this is ever built, permanently, and the product's own
  matrix will show that asymmetry to every user.
- **`execve`-granularity interception is defeatable in-process**, so this path is weaker than a hook
  that reports semantic actions. It is additive, never a substitute.
- **A third adapter shape costs contract generality.** Two shapes prove a contract; three constrain
  it. Deferring to post-v1 is what keeps the cost from landing before the benefit.

## Consequences

**Easier**

- Serving a host CLI that exposes no integration surface at all, on Linux.
- Answering "why not just sandbox everything?" — a question this design will be asked repeatedly —
  from a document rather than from memory.
- Keeping the interception/confinement distinction legible, since one ADR now owns the boundary
  between them.

**Harder**

- A third mechanism to maintain, with its own adversarial suite, on one platform only.
- Explaining a capability that exists on Linux and not on macOS to a user who runs both.
- Resisting scope creep toward `openat` supervision once the `execve` path exists and appears to
  work.

**The team must now**

1. **Answer Q-10** before any work starts: whether a platform-asymmetric capability is admissible
   under ADR-007 §6's complete-matrix rule. A "no" closes this ADR as Rejected rather than leaving it
   Proposed indefinitely.
2. **Leave v1 untouched.** No Sprint-1 task derives from this ADR; the Sprint-1 adapter work is the
   `CliAdapter` contract plus the two v1 adapters ([ADR-011](011-v1-scope-envelope.md)).
3. **Record the FR-09 gap where a reader will meet it** — the hookless-and-MCP-less host is
   unservable in v1 — rather than leaving it inferable only by composing ADR-007 §5 with FR-10.
4. **State item 6's in-process limitation in the published threat model** if this is ever built, in
   those terms, per [ADR-008](008-sandbox-confinement-primitive.md) §3.
5. **Carry the ADR-007 red-team cases over**: the interpreter one-liner and the spawned shell
   (ADR-007, "The team must now" item 4) are exactly the cases that bound this adapter's value, so
   they become its acceptance criteria rather than a separate suite.

## Rejected Alternatives

- **Replace the Claude Code hook adapter with supervision entirely** — the proposal as originally
  raised, on the reasoning that hooks are vendor-specific. Rejected on five independent grounds, each
  sufficient alone: (a) no macOS mechanism ships without Apple's entitlement, so the product would
  lose a confirmed v1 platform; (b) syscalls are not intent — `mcp.call` and `tool.call` are not
  recoverable from a `write(2)` on a pipe, so the intent-rule layer
  ([ADR-004](004-layered-policy-model.md)) would have nothing to match on; (c) the latency budget,
  per item 2; (d) a supervised syscall returns `EACCES`, not the structured `GuardError` that S-04
  and ADR-007 §9 require, so the agent sees a broken filesystem and retries rather than adapting;
  (e) outbound credential masking (FR-13) requires parsing a request body before it is sent, which
  is impossible once it is TLS bytes on a socket. The vendor-agnosticism concern is also misdirected:
  the **MCP proxy** is the vendor-neutral path ([ADR-007](007-cli-integration-strategy.md) §3), and
  the hook adapter exists because it is the best surface that one host offers.
- **Syscall-granularity supervision** (`openat`, `write`, full filesystem coverage). Complete for
  filesystem actions and genuinely vendor-agnostic. Rejected per item 2: two orders of magnitude over
  the latency budget, and no intent in the event.
- **`ptrace`-based supervision** as a portable substitute. Rejected: SIP-restricted on macOS for any
  process the user did not build, trivially detectable by the tracee, racy on multi-threaded hosts,
  and — decisively — it is interposition wearing a kernel-API costume, so
  [ADR-008](008-sandbox-confinement-primitive.md) §1 already forbids presenting it as a boundary.
- **Endpoint Security framework on macOS, for parity.** The correct analogue, and it genuinely
  blocks. Rejected for the reasons tabulated above — entitlement granted on review, kernel response
  deadlines against a local model's latency, and a system-extension install that breaks S-09.
  Revisit only if the project acquires an organizational identity that can hold the entitlement.
- **Run the host CLI in a Linux VM on macOS** so one mechanism covers both platforms. Rejected:
  [ADR-008](008-sandbox-confinement-primitive.md) already rejected container- and microVM-shaped
  answers for v1, and this is the same exposure — the developer's real repository, credentials and
  toolchain must be mounted in for the setup to be useful, which recreates most of the risk while
  adding the friction that was the reason for rejection.
- **Fold this entirely into ADR-008's Rejected Alternatives and skip ADR-015.** Cheaper, and avoids
  carrying a post-v1 ADR in the tree. Rejected, narrowly: ADR-008 is about the *confinement
  boundary*, and the substance here is an *interception point*. Filing it there would merge the two
  concepts that item 4 exists to keep apart — and the FR-09 gap, which is an ADR-007 concern, would
  stay unrecorded in either.
- **Leave FR-09's "or process-level interception" clause undesigned** and treat the MCP proxy as the
  whole of the fallback. Defensible, since every CLI worth supporting may well speak MCP. Rejected:
  that is a bet on the ecosystem, and if it is the real position then FR-09's clause should be
  amended to say so rather than left as an undesigned promise.

---
**ADR Number**: 015
**Date**: 2026-10-02
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-007](007-cli-integration-strategy.md) (the `CliAdapter` contract and the coverage
matrix this adapter must satisfy) · [ADR-008](008-sandbox-confinement-primitive.md) (the confinement
boundary this is explicitly **not** part of) · [ADR-009](009-fail-closed-default.md) (item 5) ·
[ADR-011](011-v1-scope-envelope.md) (platform parity, two adapters at ship, erring-agent threat
model) · [`../01-discovery/requirements.md`](../01-discovery/requirements.md) FR-09, FR-10, FR-13,
R-04, S-04, S-09, **Q-10** ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) §2.8
