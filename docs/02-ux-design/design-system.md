# 02 — UX Design: Design System

**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_

> This document reinterprets `.ai/templates/ux-design.md`'s "Design System Decisions" and
> "Accessibility Considerations" sections for a terminal product. There is no component library,
> typeface, or colour palette in the web sense — what follows is the equivalent set of decisions
> for a CLI and a `ratatui`-class TUI, both shipped from the single Rust binary confirmed in
> [ADR-013](../05-adr/013-model-and-language-resolution.md). Every decision here is already implied
> by [ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md),
> [`../04-solution-design/testing-strategy.md`](../04-solution-design/testing-strategy.md) §1a, and
> the Accessibility NFR in [`../01-discovery/requirements.md`](../01-discovery/requirements.md) —
> this document assembles them into one place for the people who will build the TUI, rather than
> deciding anything new.

## Component library

**No widget *library* is chosen here** — that is Phase 3/implementation detail (a `ratatui`-class
Rust TUI crate, per ADR-013's single-binary decision). What belongs in this phase is the **set of
view-level components the TUI needs**, because that set is a UX decision: it was derived from
`component-design.md` §3's withdrawn-as-built-but-retained-as-inventory component tree, re-scoped
to what a read-only view requires (no form inputs, no editors — [ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md)
item 3):

| Component | Purpose | Carried over from (withdrawn web design) |
|---|---|---|
| `HealthBanner` | Engine state, policy version, model availability | `component-design.md` §3 |
| `DecisionRateTile` / `EvaluatorMixTile` / `LatencyTile` | Dashboard summary stats | same |
| `SessionList` | Filterable, keyboard-navigable list | `SessionTable` |
| `DecisionTimeline` | Roving-tabindex list of `AuditRecord`s | same |
| `DecisionBadge` | Icon + text outcome indicator — **never colour alone** | same |
| `DecisionDetail` | Expanded trace view (winner, candidates, provenance) | `RuleChipList` + explain panel |
| `PolicyViewer` | Read-only rule browser — **no editor, no save path** | `RuleEditor` demoted to read-only |
| `UnreachableState` | Full-view replacement when the daemon is down | new — had no web equivalent (a web UI assumes its server is itself) |
| `ChainIntegrityBanner` | Persistent, non-dismissible | `ChainIntegrityNotice` |

No table/list virtualisation library decision is made here either — it is implied by the same
constraint that ruled out a client-side state store in `state-management.md` §B.1: pagination and
filtering happen through `audit.query`, not in front-end code, so the TUI never holds an unbounded
result set to virtualise.

## Typography

There is no font to choose — the terminal emulator owns the rendering font, and the product must
not assume a specific one is installed (no icon fonts, no custom glyphs beyond what a standard
terminal's default encoding reliably renders). Typographic *hierarchy* is expressed through the
attributes a terminal actually offers:

| Role | Treatment |
|---|---|
| Heading / view title | Bold, inside a bordered block title (not a larger size — none exists) |
| Body text | Default weight |
| Secondary / metadata (timestamps, ids) | Dim (`\x1b[2m`), never colour-only, and dim must still clear the 4.5:1 contrast floor (§ Accessibility) |
| Emphasis (the outcome token) | Bold **and** its semantic colour — bold carries the emphasis under `NO_COLOR` |
| Disabled / stale | Dim + explicit text marker (e.g. `(stale)`), not colour alone |

No italics are relied upon — terminal support for them is inconsistent enough that an italic-only
distinction would silently fail on some emulators without any error.

## Colour palette

Colour is **additive only**. Every colour-bearing element has a text-token or icon equivalent that
carries the same information with styling stripped — this is Accessibility NFR 1.4.1, tested
mechanically in `testing-strategy.md` §1a ("No colour-only meaning").

| Semantic role | Text token (always present) | ANSI colour (when available) |
|---|---|---|
| Allow | `ALLOW` / `✔` | green |
| Deny | `DENY` / `⨯` | red |
| Ask (pending or resolved) | `ASK` / `?` | yellow |
| Mask | `MASK` / `▦` | cyan |
| Healthy | `OK` | green |
| Degraded | `DEGRADED` + the named gap | yellow |
| Chain broken | `CHAIN BROKEN` + `seq` | red, non-dismissible banner regardless of colour support |

**`NO_COLOR` and non-TTY output** disable the colour column entirely; the text-token column is
unaffected — this is the mechanism, not a fallback bolted on afterward.

**Contrast**: every pair above is checked at ≥ 4.5:1 for body text and ≥ 3:1 for non-text
indicators against the default light and dark profiles of macOS Terminal, iTerm2, GNOME Terminal,
and Windows Terminal (`testing-strategy.md` §1a, "Contrast ≥ 4.5:1"). A palette entry that fails
on any of the four profiles **blocks the palette**, not the release note — there is no "known
issue in Terminal.app" outcome available here.

**Focus indicator is never colour alone** (WCAG 2.4.7): the focused row/tile is marked with an
inverse background or a border/marker glyph in the text grid itself, verifiable in a plain-text
snapshot with styling stripped.

## Spacing / layout grid

The grid unit is the **character cell**, not a pixel or `rem` value:

- **Minimum supported size: 80×24.** Below this, the TUI declines to start and points at the
  line-oriented fallback (`guard log`, `guard audit query`) — see [`wireframes.md`](wireframes.md)
  "Responsive behaviour."
- **Reference sizes for golden snapshots: 80×24 and 120×40** (`testing-strategy.md` §1, "Snapshot"
  row) — these are the two widths every view is designed against, not just tested against.
- **Borders delimit regions**; there is no shadow/elevation equivalent, so nesting is expressed by
  border style (single vs double) rather than depth.
- **Tables use fixed column widths** computed from content, not viewport fraction — a column never
  shrinks a path or rule id to the point of truncation (the same rule as the Responsive section's
  "never truncate a reason or rule id" at 80 cols).
- **One-line status/footer row** at the bottom of every TUI view, reserved for the key map (`[Enter]
  expand   [e] explain   [q] quit`) — present at every width, never scrolled off.

## Accessibility considerations

This product cannot use `axe-core`/Playwright-class web accessibility tooling — there is no DOM —
so WCAG 2.1 AA is satisfied through the terminal-specific mechanical checks already specified as
**blocking CI gates**, not advisory ones, in `testing-strategy.md` §1a. Restated here as design
commitments rather than test mechanics:

| WCAG criterion | How this design satisfies it |
|---|---|
| **1.4.1 No colour-only meaning** | Every outcome and status carries a text token (`ALLOW`/`DENY`/`ASK`/`MASK`, `OK`/`DEGRADED`), per the palette table above. |
| **1.4.3 Contrast ≥ 4.5:1** | Palette checked against four real terminal emulators' default profiles; failures block the palette. |
| **1.3.1 / 4.1.2 Programmatic / equivalent access** | A full-screen TUI cannot be reliably announced by assistive tech, so the **conformance path is `guard audit query` and friends** — the line-oriented CLI surface — returning the identical row set as the TUI view it mirrors (see [`user-flows.md`](user-flows.md) Information Architecture, "one rule this diagram enforces"). This path is tested row-for-row, not merely documented. |
| **2.1.1 Keyboard operable** | Every TUI view is reachable and every action performable with keystrokes alone — roving tabindex on lists, no element requires a pointer. |
| **2.4.7 Visible, non-colour focus** | Focus is marked in the text grid itself (inverse/border/marker), distinguishable with styling stripped. |
| **2.2.1 Timed interaction states its timeout and default** | The `ask` prompt ([`wireframes.md`](wireframes.md) Screen: interactive `ask` prompt) states its countdown and default outcome in text, and the timeout is configurable. |
| **1.4.10 Reflow** | No decision reason or rule id is truncated at the 80-column minimum; content wraps instead. |

**Scope note**: this table is the same one named in `testing-strategy.md` §1a; it is restated here
because the UX-design phase is where these commitments are supposed to be designed in, not
retrofitted (`CLAUDE.md`: "accessibility ... designed in from phase 1, not retrofitted"), and
because a future phase editing the palette or the key map should find the accessibility
consequence next to the design decision, not three phases away.

---
**Status**: Draft
**Last updated**: 2026-10-02
**Approved by**: _pending_
