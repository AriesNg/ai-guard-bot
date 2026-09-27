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

## Who

- **Individual developers** running AI coding agents on machines that hold real credentials,
  customer data, or production access.
- **Engineering teams and platform/DevEx groups** that want a single, reviewable policy file
  governing AI agent behaviour across every tool their engineers choose.
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
   remain available for cases needing exactness. Rules are versionable, shareable across a
   team, and portable across every supported CLI.
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
- **Accessibility**: any UI surface meets WCAG 2.1 AA.

## Stack Preferences

- **Binding**: ADR-001 (Accepted) — Next.js 14+ App Router, TypeScript, React Server Components
  by default. This governs any web/UI surface (policy editor, audit log viewer, dashboard).
- The **enforcement core** (interceptor, policy engine, sandbox) has different constraints —
  startup time, latency, OS-level sandboxing — and its language and runtime are an **open
  question for Phase 3**, to be settled by a new ADR rather than assumed from ADR-001.
- **Local model runtime**: a pluggable local inference layer (Ollama or equivalent) rather than
  a hard dependency on one model.
- **Avoid**: any hard dependency on a specific AI vendor's SDK in the enforcement path, and any
  cloud service in the policy-decision path.

## Timeline

Not yet set.

## Open Questions for the Human

These block or materially shape Phase 1 and should be answered before Discovery is approved:

1. **Local model choice.** The request named "jev / laya" — these were read as small local models
   in the Llama/Gemma/Qwen class. Please confirm the intended models or runtimes.
2. **Target platforms.** macOS only to start, or macOS + Linux + Windows? This drives the sandbox
   technology choice heavily.
3. **"100% safe sandbox."** No sandbox is absolutely safe. What is the threat model — an agent
   that errs, or an agent actively trying to escape (e.g. driven by prompt injection)? The
   answer changes the design substantially.
4. **First target agent.** Which AI CLI should be supported end-to-end first?
5. **Distribution.** Single-user local tool, or team deployment with centrally-managed policy?
6. **Scope of the UI.** Is a web UI in scope for v1, or is v1 CLI-and-config-file only?

---
**Instructions**: After filling this in, share this file with the AI and ask it to begin Phase 1 (Discovery).
