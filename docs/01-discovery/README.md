# 01 — Discovery

**Status**: ⬜ Not started

## Purpose
Understand the problem, users, market, and constraints before designing anything.

## Deliverables
- [ ] Problem statement
- [ ] User personas (2-4)
- [ ] Functional requirements
- [ ] Non-functional requirements (quantified)
- [ ] Constraints & risks
- [ ] Scope boundaries
- [ ] User stories **filed as GitHub issues** (`type:story`, one of `P0`/`P1`/`P2`), plus the
      requirement → issue traceability table in `requirements.md`

## Where user stories live

Stories are **GitHub issues**, not a section of `requirements.md` — see
[`docs/07-implementation/issue-tracking.md`](../07-implementation/issue-tracking.md) for the
label taxonomy and lifecycle. `requirements.md` keeps the numbered requirements (`FR-nn`, `NFR-nn`)
that stories trace back to; the story form links up to that id, and the traceability table in
`requirements.md` links back down to the issue.

The `## User Stories` section of `.ai/templates/discovery.md` is therefore replaced by a
traceability table of this shape:

| Req | Story | Priority | Status |
|-----|-------|----------|--------|
| FR-01 | [#12](https://github.com/AriesNg/ai-guard-bot/issues/12) | P0 | Open |

Filing a story does not authorize building it. Work starts only once this phase is **Approved** —
see the phase gate section of the issue-tracking document.

## How to use this phase
1. AI reads `.ai/templates/discovery.md`
2. AI generates draft into this folder as `requirements.md`, **without** a user-stories section
3. AI proposes the story list in chat; the human approves it, then the stories are filed as issues
   (`gh issue create --template user-story.yml`, or the web form)
4. AI fills the traceability table in `requirements.md` with the resulting issue numbers
5. Human reviews and requests changes
6. Once approved, move to Phase 2

Exit checklist: `.ai/rules/review-criteria.md` → Discovery Review. Its "user stories are INVEST"
and "P0 stories are truly must-have" criteria are now checked against the `type:story` issue
queue rather than against a document section:

```bash
gh issue list --label "type:story" --label "P0" --state open
```

## Files
- `requirements.md` — consolidated discovery document, including the requirement → issue traceability table
- `user-personas.md` — persona details (can be inline in requirements)
- `market-analysis.md` — optional, only if relevant
