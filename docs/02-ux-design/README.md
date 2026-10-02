# 02 — UX Design

**Status**: 🟡 Draft — awaiting human review

> Drafted 2026-10-02, now that [Discovery is Approved](../01-discovery/README.md). Reinterpreted
> for this product's actual interface — **CLI + config file + a read-only TUI**, no web or mobile
> surface ([ADR-010](../05-adr/010-supersede-adr-001-no-web-server-ui.md),
> [ADR-011](../05-adr/011-v1-scope-envelope.md)) — rather than applying the template's web-app
> language literally. See each document's opening note for how a given template section was
> re-mapped.

## Purpose
Design how users interact with the product — flows, screens, design language.

## Deliverables
- [x] User flow diagrams — [`user-flows.md`](user-flows.md)
- [x] Information architecture — [`user-flows.md`](user-flows.md#information-architecture)
- [x] Wireframes / screen descriptions — [`wireframes.md`](wireframes.md)
- [x] Design system choices — [`design-system.md`](design-system.md)
- [x] Responsive behavior defined — [`wireframes.md`](wireframes.md#responsive-behaviour) (terminal
      width, not device class)
- [x] Accessibility requirements — [`design-system.md`](design-system.md#accessibility-considerations)

## Files
- `user-flows.md` — Mermaid flowcharts for key journeys
- `wireframes.md` — screen-by-screen descriptions
- `design-system.md` — component library, typography, colours, spacing

---
**Prerequisite**: Discovery approved
