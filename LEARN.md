# LEARN.md — Accumulated Learnings

A shared, append-only record of **corrections and lessons** for this repository: things a human
told us, a PR reviewer flagged, or a mistake taught us the hard way. It exists so the same
mistake is not repeated by the next contributor — human or AI.

**Who reads this**
- **AI agents** (Claude Code and others): read this file before making non-trivial changes.
  `CLAUDE.md` describes *how the repo works*; this file describes *what we got wrong and what we
  now do instead*.
- **Human contributors**: read it as the informal companion to `CLAUDE.md` and `.ai/rules/`.

**Who writes this**
Anyone. Add an entry when feedback is general enough to matter again — a PR review comment, a
correction in chat, a rule discovered while working. Skip anything that is already stated in
`CLAUDE.md`, `.ai/rules/*.md`, or the code itself.

## How to add an entry

Append to the bottom of **Learnings**, never rewrite history. Use the next `L-NNN` id and this
shape:

```markdown
### L-007 — Short imperative title

- **Date**: 2026-09-27
- **Source**: PR #12 review comment | chat feedback | incident | spec reading
- **Category**: process | architecture | code | docs | security | tooling
- **What happened**: The observed behaviour or mistake, in one or two sentences.
- **Why it matters**: The cost of getting it wrong.
- **Do this instead**: A concrete, checkable instruction.
- **Related**: Links to files, ADRs, or other `L-NNN` entries.
```

Rules for entries:
- One lesson per entry. Two lessons means two entries.
- **Do this instead** must be actionable — "validate the path against the allowlist before
  spawning" rather than "be careful with paths".
- Superseded entries are **not deleted**. Mark them `> **Superseded by L-NNN.**` on the line
  under the title, the same way the phase docs supersede rather than edit.
- If a lesson becomes a hard rule, mirror it into `CLAUDE.md` or propose it for `.ai/rules/`
  (which is human-owned — suggest, do not write) and link the entry from there.

## Learnings

### L-001 — Do not infer the product from the directory name

- **Date**: 2026-09-27
- **Source**: chat feedback while writing `CLAUDE.md`
- **Category**: process
- **What happened**: The folder is named `0004-ai-guard-bot`, but at the time the project brief
  was an unfilled template. Guessing the product from the folder name would have produced
  confidently wrong documentation.
- **Why it matters**: Every downstream phase document inherits an early wrong assumption, and
  the phase gate makes that expensive to unwind.
- **Do this instead**: Take the product definition from `.ai/context/project-brief.md` and
  `README.md` only. If they are empty or contradictory, ask the human before generating.
- **Related**: `CLAUDE.md`, `.ai/context/project-brief.md`

### L-002 — `.ai/` is human-owned; suggest changes, do not write them

- **Date**: 2026-09-27
- **Source**: `.ai/workflow.md`, reinforced in review
- **Category**: process
- **What happened**: The write-permission split is easy to miss because editing files freely is
  the normal default for an agent.
- **Why it matters**: `.ai/` is the process contract. An agent editing its own instructions
  removes the human's control point.
- **Do this instead**: `.ai/` — never write. `docs/` — draft, human approves. `src/`,
  `tests/` — write freely. `infrastructure/` — generate, human tests in non-prod first. To
  change `.ai/`, propose the diff in chat and let the human apply it.
- **Related**: `.ai/workflow.md`, `CLAUDE.md`

### L-003 — Do not restate an absolute safety claim; restate it as a threat model

- **Date**: 2026-09-27
- **Source**: chat feedback while filling `.ai/context/project-brief.md`
- **Category**: security
- **What happened**: The requested capability was a "100% safe sandbox". Writing that down
  verbatim would have shipped an unachievable guarantee into the requirements.
- **Why it matters**: No sandbox is absolutely safe. A requirement that cannot be tested cannot
  be met, and the design that follows from "100% safe" differs sharply depending on whether the
  adversary is an agent that errs or an agent actively escaping.
- **Do this instead**: Convert absolute claims into a stated threat model with a named boundary
  and a testable assertion. Flag the ambiguity as an open question rather than resolving it
  silently.
- **Related**: `.ai/context/project-brief.md` (open question 3), `README.md`

### L-004 — Quantify every non-functional requirement

- **Date**: 2026-09-27
- **Source**: `.ai/instructions.md`, applied while writing `README.md`
- **Category**: docs
- **What happened**: Draft NFR text reached for words like "fast" and "low overhead".
- **Why it matters**: An unquantified NFR cannot be verified, so it silently becomes optional.
- **Do this instead**: Write "P95 added latency < 50 ms for deterministic rule evaluation,
  < 300 ms when local model evaluation is required", with the measurement condition attached.
- **Related**: `README.md` (Starting Non-Functional Targets), `.ai/rules/general.md`

### L-005 — Never claim a build or test command that does not exist

- **Date**: 2026-09-27
- **Source**: chat feedback while writing `CLAUDE.md`
- **Category**: tooling
- **What happened**: `package.json` lists `dev`, `build`, `start`, `lint`, `test`, `test:e2e`,
  and `typecheck` — all of them empty strings. They read as a working toolchain and are not one.
- **Why it matters**: Documenting or running a non-existent command wastes a contributor's time
  and produces a false "verified" claim.
- **Do this instead**: Treat those script names as reserved placeholders until Sprint 1
  (`docs/07-implementation/sprint-001-plan.md`) fills them in. When it does, document the real
  commands in `CLAUDE.md` and `README.md` in the same change.
- **Related**: `package.json`, `docs/07-implementation/sprint-001-plan.md`

### L-006 — Keep derived documents in sync in the same change

- **Date**: 2026-09-27
- **Source**: observed while updating `README.md`
- **Category**: docs
- **What happened**: Filling in `.ai/context/project-brief.md` left `CLAUDE.md` asserting the
  brief was still an unfilled template, and left `README.md` stating the directory was not a git
  repository after it had been initialized.
- **Why it matters**: A stale instruction file is worse than no instruction file — an agent
  follows it confidently.
- **Do this instead**: When a source document changes, grep for the claims it invalidates
  (`README.md`, `CLAUDE.md`, phase `README.md` status lines) and update them in the same commit.
- **Related**: `README.md`, `CLAUDE.md`, `MEMORY.md`

### L-007 — Keep local tool state out of the repository

- **Date**: 2026-09-27
- **Source**: chat feedback
- **Category**: tooling
- **What happened**: `.memsearch/` is a local agent-memory cache created in the working
  directory. It is per-machine state and must never be pushed.
- **Why it matters**: Local caches can carry machine-specific paths and conversation content,
  and they create noisy diffs for everyone else.
- **Do this instead**: Local tooling state belongs under the `# Local tooling state` section of
  `.gitignore`. Anything meant to be *shared* between contributors goes in `MEMORY.md` or this
  file instead, written deliberately.
- **Related**: `.gitignore`, `MEMORY.md`
