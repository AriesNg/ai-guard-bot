# 02 — UX Design: Wireframes

**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_

## What "wireframe" means for this product

There is no web or mobile surface to lay out (Q-06; [ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md)).
A "screen" here is either a **CLI command's text output** or a **view inside the read-only TUI**
(`guard audit view`). Both are rendered as text grids, so a wireframe for this product *is* a
mock-up of that text, at a fixed width — exactly the artefact
[`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md) §1 already
names as the test target ("Golden text grids of each TUI view at 80×24 and 120×40, plus CLI output
snapshots with and without `NO_COLOR`"). The mock-ups below are that artefact's design-time
counterpart; the view inventory and the accessibility notes they follow were carried over, not
invented, from [`../04-solution-design/component-design.md`](../04-solution-design/component-design.md)
§3, which withdrew its own (web) build but kept its component list for exactly this purpose.

Every mock-up is shown in its **unstyled** form — the form `NO_COLOR=1` or a non-TTY must produce
byte-for-identical *information content* against, per the Accessibility NFR (1.4.1). Colour is
additive, never load-bearing; see [`design-system.md`](design-system.md) for the palette itself.

---

## CLI screens

### Screen: `guard install`
- **Purpose**: One-command enable (S-09). The only screen a brand-new user is guaranteed to see.
- **Key elements**: per-adapter registration result, model/runtime provisioning progress, the
  coverage matrix, final state line.
- **Interactions**: none required — a developer can walk away after invoking it; exit code alone
  is scriptable (`0` success).
- **States (loading, empty, error, edge case)**: provisioning progress (model download can be the
  slow step — explicit percentage/size, not a silent hang); partial failure (one adapter fails to
  register — reported per-adapter, the others still install, matching Flow 1's "contain vendor
  breakage in one adapter," R-05); already-installed (idempotent, reports what's already there).

```
$ guard install
✓ Claude Code adapter registered (hook: PreToolUse, PostToolUse)
✓ MCP proxy registered
⠋ Provisioning local model (Laya, ~1.7 GB) ... 640 MB / 1.7 GB
✓ Model provisioned
✓ Policy: none found — wrote default policy (.guard/policy.yaml)
✓ Daemon started — state: Enforcing

Coverage matrix:
  ActionKind         claude-code   mcp-proxy
  shell.exec          intercepted  intercepted
  fs.write            intercepted  intercepted
  net.request         intercepted  n/a
  mcp.tool            n/a          intercepted
  mcp.sample          n/a          intercepted

guard is enforcing. Run `guard status` any time to check on it.
```

### Screen: in-session denial (rendered by the adapter)
- **Purpose**: The single most frequent thing any persona sees after install. Appears inline in
  the host AI CLI's own transcript, rendered by `CliAdapter.renderDenial` (FR-15) in that host's
  shape — the mock-up below is the information content, not literal Claude Code chrome.
- **Key elements**: outcome token (`DENY`/`ASK`/`MASK` — never colour alone, FR-15/Accessibility
  1.4.1), the rule id, a plain-language reason, and what to do instead.
- **Interactions**: for `ASK`, see the dedicated prompt screen below; for `DENY`/`MASK`, none — the
  agent and the developer read it and proceed or adjust the policy (Flow 2).
- **States**: deterministic denial (rule id present), model denial (confidence + reason, no rule
  id), evaluator-unavailable denial (distinct reason text — "the engine could not evaluate this
  action," never phrased as if a rule matched, since none did).

```
[GUARD: DENY] rule R-014 — writes outside the current repository are blocked by the default policy.
  target: /Users/tom/clientB/notes.md   (session repo: /Users/tom/clientA)
  To allow this once: guard allow-once act_01J... --reason "<why>"
  To change this permanently: edit .guard/policy.yaml, rule R-014
```

### Screen: interactive `ask` prompt
- **Purpose**: The one screen required to *block* and wait on a human (FR-25, S-15). Must satisfy
  Accessibility NFR 2.2.1 — states its timeout and default outcome in text.
- **Key elements**: action description, reason it needs a human, countdown/timeout value, default
  outcome, the exact command to answer it.
- **Interactions**: `guard allow-once <actionId> --reason <text>`, or no action (times out to the
  stated default — always deny, per Flow 3).
- **States**: counting down; answered (prints confirmation + who/why, FR-25); timed out (prints the
  default outcome explicitly, not just silence).

```
[GUARD: ASK] rule R-009 — deleting 40+ files in one action needs confirmation (confidence 0.52, below threshold).
  target: rm -rf build/ dist/ .cache/  (37 files)
  Default if unanswered in 120s: DENY
  Resolve: guard allow-once act_01J... --reason "<why>"
  ⏳ 87s remaining
```

### Screen: `guard status`
- **Purpose**: The "is something wrong?" answer every other flow routes back to (Flow 7). Read
  before reporting a bug against this product, not after.
- **Key elements**: engine state (Enforcing / Degraded / DryRun), policy version + hash, per-CLI
  coverage, model-runtime availability.
- **Interactions**: none — read-only report.
- **States**: healthy; degraded (names the gap — coverage or model — never a bare "unhealthy");
  dry-run (explicit banner, since silent dry-run is the one state that could be mistaken for
  enforcement).

```
$ guard status
State:        Enforcing
Policy:       v4  (hash a91f3c…, loaded 2h ago)
Model:        Laya — available  (warm, 41ms avg)
Coverage:
  claude-code   5/5 ActionKinds intercepted
  mcp-proxy     5/5 ActionKinds intercepted
```

### Screen: `guard explain <actionId>`
- **Purpose**: Priya's evidence question, answered without re-running anything (FR-31).
- **Key elements**: winning rule/evaluator, every candidate that matched, the precedence key that
  eliminated each loser, the provenance stamp it was decided under.
- **Interactions**: `--json` for machine use; none otherwise.
- **States**: normal record; `TRACE_UNAVAILABLE` (a record written before traces existed — an
  explicit stated state, never a blank section, matching the withdrawn web route's error-boundary
  note in [`routing.md`](../04-solution-design/routing.md) §3); `RECORD_NOT_FOUND`.

```
$ guard explain act_01J8Q...
Decision: DENY   (evaluator: deterministic, latency: 2ms)
Winning rule: R-014  (deterministic, specificity: path-exact)
Candidates considered:
  R-014  deterministic  DENY   ← winner
  R-002  deterministic  ALLOW  eliminated: lower specificity (glob vs exact path)
  model  —              not reached: deterministic layer decided first (FR-11)
Provenance: guard 0.4.1, matcher-set v12, policy v4 — unchanged since this record
```

### Screen: `guard replay <actionId>`
- **Purpose**: "Would today's rules still decide this way?" (FR-32) — a second, independent check
  from `explain`, which never evaluates.
- **Key elements**: outcome (`identical` / `divergent` / `unreplayable`), and for `divergent`, the
  attribution (policy, provenance, or model-nondeterminism — never `unexplained`).
- **Interactions**: `--policy <version>` to replay against a named policy; `--no-model` to force
  the deterministic path only.
- **States**: identical (confirms); divergent (names the cause plainly); unreplayable (e.g. a
  record predating the trace schema).

```
$ guard replay act_01J8Q... --policy v3
Result: DIVERGENT
  Then (v3): ALLOW  — no matching rule
  Now  (v4): DENY   — rule R-014 (added between v3 and v4)
  Attribution: policy change (not provenance, not model non-determinism)
```

### Screen: `guard policy diff`
- **Purpose**: See the consequence of an edit before `reload` makes it live (Flow 5, S-10, S-20).
- **Key elements**: per-decision deltas over recent history, counts by direction (new denials, new
  allows, new asks).
- **Interactions**: none — informational, read before deciding to reload.
- **States**: no change (explicit "0 of N recent decisions would change," not silence); validation
  failure short-circuits before diff ever runs.

```
$ guard policy diff
Comparing candidate (.guard/policy.yaml) against active v4, last 500 decisions:
  12 would change:  9 ALLOW→DENY (new rule R-021), 3 DENY→ALLOW (R-003 narrowed)
  488 unchanged
```

---

## TUI screens (`guard audit view`)

These carry over the component inventory `component-design.md` §3 retained specifically for this
purpose, re-expressed as text views rather than React components, and the state table from
[`state-management.md`](../04-solution-design/state-management.md) §B.6 almost verbatim — that
table is UX content, not an implementation detail, which is why it is restated here rather than
only linked.

### Screen: Dashboard (entry view)
- **Purpose**: `guard audit view`'s landing view — the TUI counterpart to `guard status`, for
  browsing rather than scripting.
- **Key elements**: health banner, decision-rate summary, evaluator mix (how much is decided
  without the model — the ≥ 80% figure made visible), top-denying rules.
- **Interactions**: arrow keys / `j`/`k` to move focus between tiles, `Enter` to drill into
  Sessions, `q` to quit, `?` for the key map.
- **States**: healthy; **daemon unreachable — a full-page explicit state, never an empty
  dashboard** (`state-management.md` §B.6's flagged requirement); degraded (names the gap).

```
┌ ai-guard-bot ── Enforcing ── policy v4 ───────────────────────────── 12:04 ┐
│ Health: OK    Model: Laya (warm)    Coverage: 5/5 claude-code, 5/5 mcp    │
│                                                                           │
│ Decisions (last hour): 184 allow · 9 deny · 2 ask · 3 mask               │
│ Evaluator mix: 86% deterministic · 11% cache · 3% model                  │
│                                                                           │
│ Top denying rules          │ Top denied targets                         │
│ R-014  7                   │ /clients/b/*       4                       │
│ R-009  2                   │ rm -rf *            2                      │
└───────────────────────────────────────────────────────────────────────── ┘
  [Enter] sessions   [p] policy   [?] help   [q] quit
```

### Screen: Session list
- **Purpose**: Entry point to a specific investigation (Flow 4).
- **Key elements**: per-session agent, time range, decision counts, chain-verified indicator.
- **Interactions**: `/` to filter (agent, time range, decision kind — mirrors `audit.query`
  dimensions, FR-21), arrow keys to move, `Enter` to open.
- **States**: populated; **"no records match this filter" vs "no records exist" — distinguished**,
  never collapsed into one empty state (`state-management.md` §B.6); loading (skeleton rows sized
  to the real row height, no layout shift on arrival).

### Screen: Session detail / decision timeline
- **Purpose**: The decision-by-decision record for one session (Flow 4, S-06, S-07).
- **Key elements**: `DecisionBadge` per row — icon **and** text, never colour alone (carried
  directly from `component-design.md` §3's accessibility note); rule chips; chain-integrity notice.
- **Interactions**: roving-tabindex list (not a mouse-hover list); `Enter`/`→` expands a row in
  place; `e` jumps straight to `guard explain` for the focused row.
- **States**: normal; **chain integrity broken — a persistent, non-dismissible banner naming the
  breaking `seq`, never a toast that can be missed** (`state-management.md` §B.6); a row whose
  trace predates the trace schema shows that fact explicitly, not a blank expansion.

```
┌ Session sess_8f2 ── claude-code v1.2 ── 09:41–10:03 ── chain: ✓ verified ─┐
│ 09:41:02  ✔ ALLOW   fs.write   /repo/src/index.ts                       │
│ 09:41:55  ⨯ DENY    shell.exec rm -rf build/ dist/ .cache/   [R-009]    │
│ 09:42:10  ? ASK→✔   fs.delete  37 files  (allow-once by aries, "clean") │
│ 09:58:30  ▦ MASK    net.request POST https://api…  (1 secret masked)    │
└───────────────────────────────────────────────────────────────────────── ┘
  [→] expand   [e] explain   [r] replay   [/] filter   [Esc] back
```

### Screen: Decision detail (expanded row)
- **Purpose**: In-place equivalent of `guard explain`, reached without leaving the timeline.
- **Key elements**: identical content to the CLI `explain` screen above — winner, candidates,
  eliminating keys, provenance, masked payload view if applicable.
- **Interactions**: collapses back with `Esc`/`←`; `r` triggers `guard replay` for this record
  in place.
- **States**: identical to the CLI `explain` screen's three states (normal, trace-unavailable,
  not-found) — the TUI and CLI paths must render the **same** information content, which is the
  screen-reader-equivalence property tested in `testing-strategy.md` §1a.

### Screen: Policy viewer (read-only)
- **Purpose**: See the active policy without a write path — authoring stays in the config file,
  checked with `guard policy validate` ([ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md)
  item 3). This is the one screen most changed from the withdrawn web design, which had a full
  editor here; the TUI deliberately does not.
- **Key elements**: baseline/project layers, rule list with precedence order visible, content hash
  and version.
- **Interactions**: read/browse only; a visible note pointing at `guard policy diff`/`reload` for
  anyone who reaches for an edit key.
- **States**: normal; stale-since-last-reload indicator if the on-disk file has changed but not
  yet been reloaded.

### Screen: Daemon-unreachable (cross-cutting state, not a single view)
- **Purpose**: The state every view above degrades to together when the daemon is down — called
  out as its own screen because `state-management.md` §B.6 names it a product requirement, not a
  nicety: *"a UI that shows an empty audit log because it could not reach the engine misleads the
  person relying on it."*
- **Key elements**: one explicit message — "the engine is not running; enforcement status
  unknown" — replacing the entire view body, not a corner toast.
- **Interactions**: `?` still works (help is local to the TUI process, not the daemon); every data
  action is disabled rather than silently returning nothing.
- **States**: this *is* a state of every other screen, not a screen with states of its own.

---

## Responsive behaviour

The template's axis is desktop → tablet → mobile. None of those exist here — there is one surface
type, a terminal, and its variable dimension is **character columns × rows**, not device class.
Re-expressed on the axis that actually applies:

| Width | Behaviour |
|---|---|
| **≥ 120 cols** (`120×40` reference) | Full layout: side-by-side tiles on the Dashboard, rule chips inline on timeline rows, no truncation of paths or reasons. |
| **80–119 cols** (`80×24` reference, the minimum supported) | Tiles stack vertically; timeline rows wrap the reason text onto a second line rather than truncating it — **a decision reason or rule id is never truncated at the narrow width** (this is a tested pass condition, `testing-strategy.md` §1a, "Resize / reflow"). |
| **< 80 cols** | Not a supported terminal size for the TUI; `guard audit view` prints a one-line message to use a wider terminal or fall back to `guard log`/`guard audit query`, which have no minimum width because they are line-oriented. |

**Colour-capability axis** (the real equivalent of a device-class fork for this product):
`NO_COLOR` set, or stdout not a TTY, renders the identical information content with styling
stripped — text tokens (`ALLOW`/`DENY`/`ASK`/`MASK`) stand in for colour everywhere, as specified
in [`design-system.md`](design-system.md).

---
**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_
