# Project Brief

## What

**AI Guard Bot** is a local, vendor-agnostic guardrail layer that sits between an AI CLI agent
and the machine it runs on. Every action the agent attempts — tool call, function call, MCP
request, or shell command — is intercepted, evaluated against user-defined rules by a small
locally-run model plus deterministic policy checks, and either allowed, rewritten (PII/secret
masking), or rejected with a machine-readable error code naming the violated rule. Allowed
actions execute inside a sandbox that confines filesystem, network, and process access.

It ships first as a guardrail for AI **CLIs** (Claude Code, Codex CLI, Gemini CLI, and others),
with a path to extending the same policy engine to AI **desktop** applications.

**v1 scope, confirmed 2026-10-02** (full reasoning in
[`docs/05-adr/011-v1-scope-envelope.md`](../../docs/05-adr/011-v1-scope-envelope.md)):

| Dimension | v1 |
|---|---|
| Platforms | **macOS and Linux**, both adversarially tested. **Windows unsupported**, and no Windows boundary claim published |
| Threat model | **An agent that errs**, not one actively escaping. Injection-driven escape is detected and logged, not claimed to be prevented |
| Integrations at ship | **Two**: Claude Code via its hook interface, and the vendor-neutral **MCP proxy** |
| Distribution | **Single-user local tool** — no control plane, no centrally-managed baseline |
| Interface | **CLI + config file + a read-only TUI audit viewer.** No web UI, and no process that binds a TCP port |
| Day-one posture | **Enforcing immediately.** Dry-run is opt-in, not an onboarding phase |
| Timeline | **Side project, intermittent** — each sprint must land something independently useful |

## Who

- **Individual developers** running AI coding agents on machines that hold real credentials,
  customer data, or production access.
- **Engineering teams and platform/DevEx groups** that want a single, reviewable policy file
  governing AI agent behaviour across every tool their engineers choose. *(Not a v1 audience: v1 is
  a single-user local tool. The policy format, the adapter contract, and the precedence resolver are
  designed not to foreclose this, but nothing is distributed in v1.)*
- **Security, compliance, and risk functions** that need an enforcement point and an audit
  trail for AI agent activity, without banning the tools outright.

## Background / Existing Problems

The trigger for this project is the way developers actually use AI CLIs today, not a
hypothetical risk.

1. **Blanket approval is the default in practice.** Tools such as Claude Code ship interactive
   permission prompts, but a prompt on every file write and every shell command interrupts the
   work it is meant to protect. The path of least resistance is to launch the agent with full
   permissions (`--dangerously-skip-permissions` and its equivalents) and accept whatever it
   does. The control that exists is therefore routinely switched off — not because developers
   do not care, but because the granularity is wrong: they are asked about individual actions
   when what they hold in their head is a handful of high-level intentions.

2. **Per-tool permission configuration costs more effort than it is worth.** Each CLI does have
   a settings mechanism (allow/deny lists, hook configuration), but authoring one means
   enumerating concrete tool names, command prefixes, and glob patterns up front, in a
   tool-specific syntax, and then maintaining it as the agent finds new commands. The effort is
   front-loaded and never finished, so most developers never start. And the work does not
   transfer: a policy written for one CLI has to be rewritten for the next.

3. **There is no record of what the agent did.** Once permissions are blanket-approved, the
   only trace is terminal scrollback. There is no queryable history of which actions were
   attempted, which were risky, or what the agent read and sent outward — so neither the
   developer nor a security reviewer can answer "what happened in that session?" after the fact.

**The intended shift.** The developer writes a small number of rules in plain language
("never touch production credentials", "stay inside this repository", "no network calls to
anything but our package registry"). A small model running locally applies those rules to each
concrete action the agent attempts and decides on the developer's behalf — allow, mask, or
reject — so the developer is neither interrupted nor forced to pre-enumerate every case. Every
decision is recorded, making the session fully observable after the fact. Intent is authored
once at a level a human can actually hold; the translation to specific actions is the tool's
job, not the developer's.

## Why

AI CLI agents execute arbitrary commands with the full privileges of the user who launched them.
Today the only controls are each vendor's own permission prompts — inconsistent between tools,
not centrally configurable, not auditable, and easily fatigued into blanket approval. Sensitive
data also flows outward: secrets and PII in files or command output are sent to a remote model
provider with nothing in between.

The goal is a **single enforcement point that the user owns**: one policy, applied identically
to every agent, running entirely on the local machine so no prompt or file content has to leave
it for a policy decision to be made.

Success means a developer can grant an AI agent broad autonomy and still be confident that
(a) destructive or out-of-scope actions are blocked before execution, (b) secrets and PII never
leave the machine unmasked, and (c) everything the agent did is recorded.

## Core Capabilities

1. **Agent-agnostic interception.** Works with any AI CLI. No forks of the host agent; integrate
   via each tool's hook/permission interface where one exists, and via an MCP proxy or
   process-level interception where it does not.
2. **Local small-model policy evaluation.** A small model running locally (Llama/Gemma/Qwen-class,
   served via Ollama or an equivalent local runtime) handles judgement calls that static rules
   cannot express — intent classification, prompt-injection detection, semantic PII detection.
   No policy decision requires a network call.
3. **High-level rules, not enumerated permissions.** The developer authors a small set of
   intent-level rules in plain language; the engine — deterministic matchers plus the local
   model — resolves them against concrete actions. A declarative rule file (allow/deny/ask/mask
   matching tool name, command, path, network destination, content) and user-supplied hooks
   remain available for cases needing exactness. Rules are versionable and portable across every
   supported CLI; *sharing them across a team is post-v1.*
4. **Structured violation responses.** On denial, return a stable error code plus the list of
   violated rules, in a form the calling agent can parse and act on rather than a free-text
   refusal.
5. **Sandboxed execution.** Approved actions run inside a confined environment with an explicit
   filesystem, network, and process allowlist.
6. **PII and secret handling.** Detect and mask or strip PII, credentials, and user-defined
   sensitive keywords from both what the agent is about to send outward and what it receives.
7. **Full observability.** An append-only audit log of every intercepted action, the decision
   taken, the rule that drove it, and the evaluation latency — queryable after the fact, so a
   whole agent session can be reconstructed rather than read out of terminal scrollback.

## Non-Functional Requirements

To be quantified during Phase 1 (Discovery) and fixed in Phase 3 (System Design). Starting
targets for discussion:

- **Latency**: P95 added latency per intercepted action under 50 ms for deterministic rule
  evaluation; under 300 ms when local model evaluation is required. Deterministic rules are
  evaluated first so the model path is not on the hot path for most actions.
- **Throughput**: sustain the action rate of at least 4 concurrent agent sessions on a developer
  laptop without exceeding a defined CPU/RAM budget.
- **Availability / fail mode**: fail-closed by default — if the guardrail cannot evaluate an
  action, the action is denied. Configurable per rule.
- **Sandbox isolation**: the strength and exact boundary of the sandbox must be stated as a
  concrete threat model, not as an absolute claim.
- **Privacy**: no action content, file content, or prompt leaves the local machine as part of a
  policy decision.
- **Observability**: every decision emits a structured event with rule id, decision, and latency.
- **Accessibility**: WCAG 2.1 AA, applied to v1's actual surfaces — the **terminal and the TUI**:
  no information carried by colour alone, keyboard-operable end to end, and every TUI query
  answerable as linear text through `guard audit query` for screen-reader users.

## Stack Preferences

- **No UI framework is binding.** ADR-001 (Next.js / React Server Components) was inherited from
  the project scaffold, predates this brief, and is **superseded by
  [ADR-010](../../docs/05-adr/010-supersede-adr-001-no-web-server-ui.md)**: it binds nothing. Four of
  its five stated reasons do not apply to a local daemon, and a Next.js server would bind a TCP port,
  which [ADR-003](../../docs/05-adr/003-local-daemon-over-unix-socket.md) forbids outright.
- **The UI is a read-only TUI audit viewer**, in-process, shipped inside the same binary. No server
  runtime, no listening port, no write path to policy — policy writes go through the CLI so the write
  path has one entry point.
- The **enforcement core** (interceptor, policy engine, sandbox) is proposed as **Rust** in
  [ADR-002](../../docs/05-adr/002-enforcement-core-language.md), for startup time, latency, and
  direct access to the OS sandboxing primitives. *Amendment pending:* with a TUI rather than a web
  UI, nothing consumes the TypeScript half of that ADR, so the recommendation is a **single-language
  Rust** product — one static binary, no Node runtime inside a security tool. **Needs your
  confirmation** (Q-09 below).
- **Local model runtime**: a pluggable local inference layer (Ollama or equivalent) rather than
  a hard dependency on one model.
- **Avoid**: any hard dependency on a specific AI vendor's SDK in the enforcement path, and any
  cloud service in the policy-decision path.

## Timeline

**Side project, worked on intermittently.** No fixed date. Two consequences are treated as binding
rather than advisory: each sprint must land something independently useful, and the design must be
documented thoroughly up front, because the context will not survive multi-week gaps.

## Open Questions for the Human

### Still open — these block Discovery approval

1. **Local model choice (Q-01).** "laya" is a specific model you have in mind, not a Llama-class
   placeholder. Which model, and which runtime serves it? This gates
   [ADR-005](../../docs/05-adr/005-pluggable-local-model-runtime.md): the accuracy thresholds, the
   memory budget against the 16 GB laptop floor, and whether constrained decoding is available are
   all properties of a named model, not of "a small local model".
2. **Single-language Rust (Q-09).** Raised *by* the answers below rather than carried from this
   brief. Choosing a TUI removed the only consumer of TypeScript, so the recommendation is to build
   the TUI in-process in Rust and ship one binary, deleting the schema-codegen step ADR-002
   introduced to keep two languages in sync. This is an amendment to ADR-002 and has not been
   applied unilaterally.

### Answered 2026-10-02

| # | Question | Your answer |
|---|---|---|
| 2 | Target platforms | **macOS + Linux, both properly tested; Windows untested and therefore declared unsupported.** Your condition was "all three *if* we can test all three" — it fails for Windows, so no Windows claim is published |
| 3 | Threat model | **An agent that errs.** Injection-driven escape is detected and logged; prevention is explicitly not claimed |
| 4 | First target agent | **Two at ship**, not one: a hook-based adapter (Claude Code) and the MCP proxy. Your instinct was that the product must be CLI-agnostic — two differently-shaped integrations are what make that claim demonstrated rather than asserted |
| 5 | Distribution | **Single-user local tool.** Team deployment, shared baselines, and the team denial view move post-v1 |
| 6 | Scope of the UI | **CLI + config file, plus a read-only TUI audit viewer.** No web UI |
| — | Day-one posture | **Enforcing immediately.** You declined the dry-run-first-session recommendation; in exchange the shipped default policy and the accuracy gate become release blockers, since a false deny now lands before the product has earned any credit |
| — | Timeline | **Side project, intermittent** |

Each answer and its consequences are recorded in
[`docs/05-adr/011-v1-scope-envelope.md`](../../docs/05-adr/011-v1-scope-envelope.md); the Discovery
document was re-scoped to match on the same date.

---
**Instructions**: After filling this in, share this file with the AI and ask it to begin Phase 1 (Discovery).

**Edit note (2026-10-02):** this file is human-owned per `.ai/workflow.md`. The scope table, the
Stack Preferences rewrite, the timeline, and the Open Questions section above were written by Claude
**at the product owner's explicit request** ("make sure we document these details and update both
.ai and docs folders' files"), recording the owner's own answers from the confirmation session of
that date. Nothing here is Claude's own decision; the two questions left open are left open.
