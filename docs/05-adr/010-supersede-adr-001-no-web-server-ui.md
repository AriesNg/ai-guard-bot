# ADR-010: Supersede ADR-001 — no web-server UI; the CLI is v1's interface

## Status
Proposed — **supersedes [ADR-001](001-use-react-and-typescript.md)**

**Amended 2026-10-02:** Q-06 is answered — v1's interface is the **CLI, the config file, and a
read-only TUI audit viewer**. No web UI, no browser, no asset-serving path. Item 2 below ("no UI
stack is chosen now") therefore **closes**: the stack is a terminal UI. See
[ADR-011](011-v1-scope-envelope.md). Item 4's TypeScript preference is consequently moot, and
ADR-002's TypeScript half is dormant — ADR-011 raises making the product single-language Rust.

## Context

ADR-001 (Accepted, 2026-05-10) fixed Next.js 14+ App Router, TypeScript, and React Server
Components as binding for this project. It was written before `.ai/context/project-brief.md`
described what the product is, and its stated context is:

> We need a frontend framework that supports SSR, static generation, and API routes with minimal
> configuration.

**None of those forces exist in this product.** AI Guard Bot is a local guardrail daemon for a
single developer's machine. Checking ADR-001's rationale line by line against the brief:

| ADR-001's reason | Does it hold here? |
|---|---|
| "SSR, SSG, ISR, and API routes out of the box" | No. There are no anonymous visitors, no documents to render server-side, no SEO surface. Every reader is the one authenticated local user. |
| "no separate backend server needed for BFF" | No. The backend already exists and is not negotiable — `guardd`, reached over a Unix domain socket ([ADR-003](003-local-daemon-over-unix-socket.md)). A BFF would be a third hop to the same data. |
| "App Router enables RSC, reducing client-side JS" | Irrelevant. Bundle size over loopback on the user's own machine is not a constraint worth an architectural commitment. |
| "Vercel ecosystem simplifies deployment if needed" | No. Nothing is deployed. The product installs onto a laptop in one command (S-09) and must run with no network at all. |
| "TypeScript provides type safety across the stack" | **Partly holds** — see the Decision. |

Two further problems make ADR-001 not merely ill-fitting but actively wrong:

1. **It contradicts ADR-003.** ADR-003 item 4 states: *"No TCP listener exists in the product, in
   any configuration, for any purpose."* Both Next.js's dev server and its production server bind
   a TCP port. ADR-001 as written cannot be implemented without breaking the invariant that makes
   the Privacy NFR testable.
2. **It binds a decision about a surface that may not exist.** Q-06 — *is a web UI in scope for
   v1?* — is still unanswered. ADR-001 pre-commits the stack for a component whose existence is
   undecided, which inverts the phase gate: the decision arrived before the requirement.

There is also a trust-surface cost that ADR-001 never considered. A Next.js server process holding
read access to the audit log is a second long-lived process inside the trust boundary, listening on
a port, in a product whose threat model (R-07) requires that the guarded agent cannot reach or
weaken its own guard, and whose security persona (P3, `../01-discovery/user-personas.md`) rejects
the product outright if the audit log is reachable by the thing being audited.

## Decision

1. **ADR-001 is superseded and binds nothing.** No framework, router, or rendering strategy is
   decided for this project by inheritance from the scaffold.
2. ~~**No UI stack is chosen now.** The choice waits on Q-06 being answered.~~ **Closed 2026-10-02:**
   the UI is a **read-only TUI audit viewer**, in-process, shipped inside the same binary. A terminal
   UI satisfies items 3a–3c below by construction — there is nothing to serve and no port to bind.
3. **Any future UI must satisfy these constraints, which are decided now** and are what ADR-001
   should have been reasoning about:
   - **No server runtime ships as part of the product.** The UI is statically built assets.
   - **No TCP listener, preserving ADR-003 item 4 without exception.** Assets are served over the
     existing Unix domain socket, or opened as local files.
   - **Read-only.** The UI reaches only `audit.query`, `audit.verify`, and `policy.current`
     (`../04-solution-design/routing.md` §1). Policy writes go through the CLI, so the write path
     has one entry point.
   - **It is outside the enforcement path.** No decision ever waits on the UI, and the UI being
     absent, broken, or closed changes no decision.
4. ~~**TypeScript survives as the language for any UI client code**, and React remains the
   recommended rendering library.~~ **Moot as of 2026-10-02:** with a TUI rather than a web UI, no
   browser-facing code exists, so nothing of ADR-001's stack survives in practice. The TUI's
   language follows the enforcement core's — see [ADR-011](011-v1-scope-envelope.md).
5. **The WCAG 2.1 AA requirement is not superseded.** It attaches to whatever interface exists,
   and in a CLI-only v1 that means the terminal surface: no information conveyed by colour alone,
   denial reasons legible without ANSI styling, and output that reads correctly through a screen
   reader.

**Q-06 outcome (2026-10-02):** CLI and config file, **plus a read-only TUI audit viewer**. This is
the recommendation's reasoning taken one step further: the audit log was identified above as the one
surface that genuinely benefits from a richer view, and a TUI delivers that without a port, a second
process, or a frontend stack. The trust surface stays at one process.

## Rationale

- **An ADR inherited from a scaffold is worse than no ADR.** It carries the authority of a
  decision with none of the reasoning, and it is cited downstream — ADR-001 is referenced in the
  brief, the requirements' Constraints table, `component-design.md` A-6, and the ADR index. Each
  citation propagated a premise nobody had checked against this product.
- **The real UI question is architectural, not framework-shaped.** Whether a local security tool
  ships a second listening process is a security decision; which library renders the table is
  nearly a matter of taste. ADR-001 answered the easy question and never asked the hard one, which
  is why superseding it with *constraints* rather than a different framework is the correct repair.
- **Deciding the constraints now while deferring the stack** is what keeps this from being a punt:
  the parts that interact with ADR-003, R-07, and P3 are settled, and the part that genuinely
  depends on Q-06 waits for Q-06.
- **Superseding rather than editing** follows `.ai/workflow.md`: *"A decision that changes later is
  superseded by a new ADR rather than edited in place."* The mistake is part of the record — and
  the record is the point, since the same scaffold-inheritance error is easy to repeat.
- **Keeping TypeScript** avoids throwing away a sound conclusion because its stated reasons were
  wrong. It is the right default for the UI layer on its own merits.

Trade-offs accepted:

- **v1 ships without a graphical audit viewer**, which is the most demo-friendly part of the
  product. Reviewing a long session in a terminal is genuinely worse than in a table with filters.
- **Deferring the stack means a later decision cost**, and some Phase 4 UI design work
  (`../04-solution-design/component-design.md` §3) is now explicitly provisional rather than
  merely gated.
- **The static-assets-over-UDS constraint rules out the most familiar local-web-app shape** and
  will feel unnecessarily strict to anyone who has shipped a localhost dashboard.

## Consequences

**Easier**

- Holding ADR-003's no-TCP-listener invariant without an exception clause — the Privacy NFR stays
  testable by the simple assertion that the product opens no port.
- Reasoning about the trust boundary: one long-lived process, not two.
- Answering Q-06 on its merits, rather than against a stack already declared binding.

**Harder**

- Explaining the absence of a UI, which is what people expect to be shown first.
- Building a UI later under the static-assets constraint: no server-side rendering, no API routes,
  no server actions — the policy-editor design in `component-design.md` §3 assumed a Server Action
  and must be reworked if a UI is approved.

**The team must now**

1. ~~**Answer Q-06.**~~ **Done 2026-10-02:** a read-only TUI. Item 2 above is closed.
2. Update every citation of ADR-001 so nothing still describes it as binding — `README.md`,
   `docs/01-discovery/requirements.md` (Constraints, Q-06), `docs/04-solution-design/component-design.md`
   (A-6, §3), `docs/04-solution-design/state-management.md` (§B), `docs/05-adr/README.md`, and
   `CLAUDE.md`. Done in the same change as this ADR.
3. ~~**Ask the human to amend `.ai/context/project-brief.md` → Stack Preferences**, which still reads
   "**Binding**: ADR-001 (Accepted)".~~ **Done 2026-10-02**, at the product owner's explicit request:
   Stack Preferences now records that no UI framework is binding, that the UI is a read-only TUI, and
   that Q-09 (single-language Rust) is open. That file is human-owned per `.ai/workflow.md`, so the
   edit is marked as owner-requested at the foot of the file. **Q-09 was itself answered later the
   same day** ([ADR-013](013-model-and-language-resolution.md)) — the brief's "Q-09 open" line is
   now stale, but since `.ai/` is human-owned, updating it to reflect single-language Rust is
   proposed in chat, not written here.
4. ~~Rework `component-design.md` §3's Server-Action-based policy editor into the CLI write path~~
   **Done:** §3 is withdrawn as a build target and retained only as the TUI's view inventory;
   `state-management.md` Part B is re-based on the TUI with the policy-write flows moved to the CLI.
5. ~~Add the WCAG 2.1 AA checks for the CLI surface to `../04-solution-design/testing-strategy.md`~~
   **Done:** §1a of that document now specifies the terminal/TUI accessibility checks, including the
   `guard audit query` equivalent path for screen-reader users, as a blocking CI stage.

## Rejected Alternatives

- **Keep ADR-001 as binding.** The status quo, and defensible on the grounds that Next.js + TS is
  a perfectly good stack and plenty of local dev tools ship exactly that. Rejected because its
  stated rationale is false here in four of five points, and because it cannot be implemented
  without violating ADR-003's no-TCP-listener invariant. A binding decision whose reasons do not
  hold will be re-litigated by every engineer who reads it.
- **Edit ADR-001 in place** to fix its context and rationale while keeping the conclusion. Cheapest
  option, and tempting since the ADR is young. Rejected: `.ai/workflow.md` requires superseding
  rather than silent editing, and the scaffold-inheritance failure is itself worth recording — an
  edited ADR-001 would read as though the premise had always been checked.
- **Delete `001-use-react-and-typescript.md` outright** as scaffold boilerplate that was never a
  real decision. Genuinely arguable: it predates the brief and nobody chose it for *this* product.
  Rejected because the file is cited in six places including the human-owned brief, and a dangling
  ADR-001 is more confusing than a superseded one; also, renumbering or leaving a hole in the index
  loses the history of what the project once believed. Available on request if the product owner
  would rather treat it as scaffold noise.
- **Keep Next.js but forbid its server** (`next build && next export`, static assets only). The
  narrowest possible repair, and it would satisfy ADR-003. Rejected as still deciding a stack for a
  component whose existence is undecided — and a Next.js whose server, API routes, RSC, and Server
  Actions are all forbidden is being used for its bundler alone, which is not a reason to adopt a
  framework. Moot as of 2026-10-02: Q-06 answered with a TUI, so no web stack is adopted at all.
- **Ship a terminal UI (TUI) as the audit viewer** instead of deferring. Attractive: no port, no
  second process, no browser, and it is where the developer already is. Rejected *as part of this
  ADR* because it is a UI stack decision, and item 2 says those wait for Q-06 — but it is the
  recommended first option to evaluate when Q-06 is answered, ahead of a web UI.
- **Ship an Electron or Tauri desktop app.** Gives a real GUI with no listening port. Rejected for
  v1: it adds a large runtime and an auto-update surface to a security tool that must install in
  one command and run offline, for a benefit — viewing a log — that does not need a desktop app.
- **Decide a UI stack now anyway, to unblock Phase 4 §3.** Rejected: that is precisely the error
  ADR-001 made. Phase 4's §3 being provisional is the honest state of a design whose requirement is
  unconfirmed, and marking it so costs nothing.

---
**ADR Number**: 010
**Date**: 2026-10-02
**Author**: Claude (draft for review by Yu Fai (Aries) Ng)
**Related**: [ADR-001](001-use-react-and-typescript.md) (superseded by this ADR) ·
[ADR-002](002-enforcement-core-language.md) (its "TS for the UI" half now rests on item 4 here) ·
[ADR-003](003-local-daemon-over-unix-socket.md) (the no-TCP-listener invariant this protects) ·
[ADR-006](006-audit-log-integrity.md) (read-only audit access) ·
[`../01-discovery/requirements.md`](../01-discovery/requirements.md) Q-06, R-07, NFR accessibility ·
[`../01-discovery/user-personas.md`](../01-discovery/user-personas.md) P3 ·
[`../04-solution-design/component-design.md`](../04-solution-design/component-design.md) A-6, §3
