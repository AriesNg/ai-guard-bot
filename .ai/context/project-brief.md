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
3. **Configurable rules and hooks.** Declarative rule file (allow/deny/ask/mask) matching on
   tool name, command, path, network destination, and content. User-supplied hooks for custom
   checks. Rules are versionable and shareable across a team.
4. **Structured violation responses.** On denial, return a stable error code plus the list of
   violated rules, in a form the calling agent can parse and act on rather than a free-text
   refusal.
5. **Sandboxed execution.** Approved actions run inside a confined environment with an explicit
   filesystem, network, and process allowlist.
6. **PII and secret handling.** Detect and mask or strip PII, credentials, and user-defined
   sensitive keywords from both what the agent is about to send outward and what it receives.
7. **Audit log.** Append-only record of every intercepted action and the decision taken.

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
