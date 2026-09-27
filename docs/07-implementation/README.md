# 07 — Implementation

**Status**: ⬜ Not started

## Purpose
Build the application iteratively, sprint by sprint. Each sprint produces working, tested, deployable code.

## Work queue

Stories, tasks, and defects live in **GitHub Issues**; sprints are **milestones**. The rules,
labels, and lifecycle are in [`issue-tracking.md`](issue-tracking.md) — read it before filing or
picking up work. This folder holds the per-sprint snapshots, not the live queue.

## How This Works

1. Select the `P0` story issues for the sprint and assign them the sprint's milestone
   (`gh issue list --label "type:story" --label P0 --state open`)
2. For each sprint:
   - Write `sprint-NNN-plan.md`, listing the issue numbers in scope
   - Build features + tests, one branch and PR per issue (`Closes #N`)
   - Demo to human
   - Write `sprint-NNN-review.md`: issues closed, issues carried over, defects found
   - Retire the milestone; anything unfinished returns to the backlog with its labels intact

Defects found mid-sprint are filed with the defect form. `S1`/`S2` are pulled into the current
milestone and something of equal size is pushed out — recorded in the sprint review, never
absorbed silently. `S3`/`S4` go to the backlog.

## Current Sprint
<!-- AI updates this as work progresses -->

**Sprint**: 1
**Status**: ⬜ Planned | 🟡 In Progress | 🟢 Complete
**Goal**:
**Milestone**: [Sprint 1](https://github.com/AriesNg/ai-guard-bot/milestone/1)
**Issues**: see [`sprint-001-plan.md`](sprint-001-plan.md)
**Blockers**:

## Sprint Log

| Sprint | Goal | Status | Dates |
|--------|------|--------|-------|
| 1 | | ⬜ | |

## Backlog

Not maintained here — it is the open, unmilestoned issue queue:

```bash
gh issue list --search "no:milestone is:open" --label "type:story"   # unscheduled stories
gh issue list --label "type:defect" --state open                     # open defects
gh issue list --label "status:blocked"                               # waiting on something
```

---
**Prerequisite**: Phases 1-6 approved (at least for the scope of Sprint 1)
