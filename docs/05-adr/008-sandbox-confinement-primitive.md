# ADR-008: Sandbox confinement — OS-native primitives, and no absolute isolation claim

## Status
Proposed — **unblocked 2026-10-02**; Q-02 and Q-03 are answered by
[ADR-011](011-v1-scope-envelope.md)

The primitive is now fixed rather than conditional:

| Platform | Primitive | v1 status |
|---|---|---|
| **macOS** | Seatbelt / `sandbox_init` profile per executed action | Supported, tested |
| **Linux** | Landlock (filesystem) + seccomp-bpf (syscalls) + network namespace | Supported, tested |
| **Windows** | AppContainer would be the candidate | **Not supported, no boundary claim published** — it cannot be tested (ADR-011), and item 3 below deletes untested claims |

This follows from Q-03 answering **erring agent**: confinement by allowlist is sufficient, and the
heavier container/microVM boundaries stay rejected. Prompt-injection-driven escape is **not** claimed
to be prevented, and the threat model must say so.

## Context

The original framing asked for a "100 % safe sandbox". No sandbox is absolutely safe, and the
project brief already records this as Open Question Q-03: is the adversary an agent that **errs**,
or one **actively trying to escape** — for instance because a prompt injection told it to
(R-02)? The two produce materially different designs:

- *Erring agent*: confinement by configuration is sufficient. A wrong path or an overreaching
  command is stopped by an allowlist.
- *Actively escaping agent*: the boundary must resist deliberate attempts — chained commands,
  spawned interpreters, symlink games, environment manipulation, and attacks on the guard itself.

Other forces:

- FR-17: approved actions execute within explicit filesystem, network, and process allowlists.
- FR-18: the boundary must be documented as a **concrete threat model, including what it does not
  stop**, with no absolute claim.
- Q-02 decides the platforms, and the available primitives differ completely per OS.
- R-07: the guarded agent must never be able to weaken its own guard.
- Persona P3 (`../01-discovery/user-personas.md`) **rejects the product** if it markets itself as a
  complete sandbox — an absolute claim makes her trust the whole thing less, not more.
- The developer must still be able to work: a boundary tight enough to break normal development is
  a boundary that gets disabled.

## Decision

Decided now, independent of Q-02/Q-03:

1. **Use OS-native confinement primitives. Never a hand-rolled boundary.** Interposition tricks
   (`LD_PRELOAD`/`DYLD_INSERT_LIBRARIES`, PATH shims, wrapper scripts) are not a security boundary
   and will not be presented as one; they may serve only as defence in depth.
2. **The boundary is data, not prose.** `SandboxExecutor.boundary()` returns a
   `BoundaryDescription` enumerating what is confined and what is not. The published threat model,
   the health check, and the docs are all generated from it, so they cannot drift apart.
3. **Every boundary claim must have a passing adversarial test.** For each claim in
   `BoundaryDescription`, a test attempts exactly that escape. **A claim without a passing test is
   deleted from the threat model** (`../04-solution-design/testing-strategy.md` §2.2). The product
   claims only what it demonstrates.
4. **No absolute isolation claim, in any material** — docs, README, marketing, or CLI output. The
   threat model states what is not stopped, including: a local attacker with root, a kernel
   vulnerability, and anything outside the enumerated action classes.
5. **A weaker boundary is reported, not hidden.** If the platform offers less than the policy asks
   for, `health` and session start say so (FR-23), and the affected action classes degrade to
   `deny` (FR-10) rather than to an unenforced allow.
6. **Invariant, unconditional on platform or policy: the engine's own config, policy file, audit
   log, and socket are never in `confinement.fs.write`.** Enforced in the `Confinement`
   constructor, so it is unexpressible rather than merely discouraged — this is R-07's mitigation
   and it does not depend on which primitive is chosen.
7. **Deny-by-default confinement**: the allowlist is the whole of what is permitted; anything
   unlisted is outside.
8. **Confinement is derived from the policy**, not configured separately, so there is one place a
   developer expresses intent.

Decided per platform (Q-02 and Q-03 answered — [ADR-011](011-v1-scope-envelope.md)):

9. **macOS: a Seatbelt (`sandbox_init`) profile per executed action.**
10. **Linux: Landlock for filesystem scoping, seccomp-bpf for syscall restriction, and a network
    namespace for the network allowlist.**
11. **Windows: not supported in v1, and no Windows boundary claim is published** — it cannot be
    tested, and item 3 deletes untested claims. AppContainer is the candidate when it returns.
12. **Prompt-injection-driven escape is in scope for detection and logging, and explicitly not
    claimed to be prevented.** The published threat model must state this limitation in those terms.

The heavier boundaries stay rejected on the erring-agent threat model: a microVM is the right answer
to a deliberate adversary, but it is a different product in cost, start-up latency, and developer
friction, and would put the < 2 s cold start and the "developers can still work" requirement at
risk.

## Rationale

- **Honesty is a feature here, not a compliance chore.** The reader who most needs this component
  (P3) explicitly rejects absolute claims. A product that says "we stop A, B, C and not D" is
  trusted and deployable; one that says "fully sandboxed" is disbelieved and blocked.
- **Boundary-as-data with test-backed claims is the mechanism that keeps honesty true over time.**
  Prose threat models rot as code changes; a generated one cannot claim what no test supports.
- **OS primitives are maintained by people with more resources than this project**, and they are
  the only things in this space that are actually boundaries. A hand-rolled interposition layer
  would provide the *appearance* of confinement, which given R-04's logic is worse than none.
- **Reporting a weaker boundary and denying the affected classes** keeps the product's assurance
  claim proportional to what it can actually enforce.
- **Deriving confinement from the policy** avoids the classic failure where the allowlist and the
  rules disagree and the looser one wins.
- **The engine-files invariant is unconditional** because R-07 does not depend on the threat model:
  even an erring agent can `>>` the wrong file.

Trade-offs accepted:

- **v1 will not stop a determined, injection-driven escape**, and will say so. This is a real
  limitation and the main argument for a heavier boundary.
- **Per-platform implementations** mean the confinement code does not amortise across the OS matrix.
- **Developer friction** from deny-by-default; the default policy's allowlist must be generous
  enough for normal work, which is itself a tuning problem.

## Consequences

**Easier**

- Making truthful, checkable statements about what the product protects.
- Reviewing the boundary: it is enumerable data with a test per claim.
- Adding a platform: implement the port, declare a `BoundaryDescription`, satisfy its tests.

**Harder**

- Per-platform engineering, and a CI matrix that must actually run on each OS for the adversarial
  suite to mean anything.
- Tuning the default allowlist so normal development is not broken.
- Managing expectations against "100 % safe", which is what was originally asked for.

**The team must now**

1. Write the `BoundaryDescription` for macOS and for Linux, each enumerating what is confined and
   what is not — the primitives are now fixed, so this is buildable.
2. State the prompt-injection limitation (item 12) verbatim in the published threat model, rather
   than leaving it implied by the absence of a claim.
3. Write the boundary-claims adversarial suite and wire it into CI per platform.
4. Draft the published threat model from `BoundaryDescription`, and have Phase 3's `security.md`
   own it.
5. Assert the engine-files invariant in a test that enumerates policy shapes attempting to include
   them.

## Rejected Alternatives

- **A hand-rolled boundary via `LD_PRELOAD` / `DYLD_INSERT_LIBRARIES` / PATH shims.** Portable,
  easy, no OS-specific code. Rejected as a security boundary: trivially bypassed by a static binary,
  a direct syscall, or an unset environment variable. Its real danger is that it *looks* like
  confinement, which under R-04's logic is worse than having none. Permissible only as defence in
  depth, never as a claim.
- **A container (Docker-class) per session.** Strong, familiar, cross-platform-ish. Rejected for
  v1 as the default: it requires a container runtime the developer may not have (breaking the
  5-minute install, S-09), and mounting the developer's real repo, credentials, and toolchain into
  it recreates most of the exposure while adding large friction. Remains the recommended shape for
  a deliberate-adversary threat model if Q-03 answers that way.
- **A microVM per session.** The strongest boundary available locally and the correct answer to an
  actively-escaping agent — which Q-03 confirms is not v1's threat model. Rejected for v1: start-up cost against a < 2 s cold start, memory against
  a < 5 GB budget already mostly spent on the model, and file-sharing friction that would make
  normal development painful. This is a different product, and possibly a later one.
- **No sandbox at all — rely solely on pre-execution policy decisions.** Defensible, since the
  policy engine is the primary control and FR-17 could be deferred. Rejected: an `allow` is
  sometimes made on incomplete information, and confinement is what bounds the cost of being wrong.
  Removing it makes every model error unbounded.
- **Claim "100 % safe sandbox"** as originally framed. Rejected on two grounds: it is false, and it
  loses the security reader the feature exists for. Replaced by FR-18's requirement to state what is
  not stopped.
- **Let the user configure the sandbox separately from the policy.** More flexible. Rejected: two
  sources of truth about what is permitted, which eventually disagree, and the looser one wins.

---
**ADR Number**: 008
**Date**: 2026-09-28
**Author**: Claude (draft for review by Aries Ng)
**Related**: [ADR-011](011-v1-scope-envelope.md) (answers Q-02 and Q-03) ·
[ADR-002](002-enforcement-core-language.md) ·
[ADR-007](007-cli-integration-strategy.md) · [ADR-009](009-fail-closed-default.md) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) FR-17, FR-18, R-02, R-07,
Q-02, Q-03 ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) §2.5
