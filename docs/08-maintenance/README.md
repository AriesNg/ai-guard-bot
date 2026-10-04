# 08 — Maintenance

**Status**: Draft

## Purpose

The defect log and the rules around it. Every change to this repository is verified by a test
(`tests/docs/verify-docs.sh`) before it is committed; a defect the test or a review uncovers is
**raised here as a record**, not left as a chat remark or an inline `TODO`.

## Files

| File | Holds |
|------|-------|
| `defect-log.md` | One `D-NNN` record per defect — found, assessed, and (when resolved) closed |
| `defect-template.md` | The copy-paste shape for a new `D-NNN` record |

## Raising a defect

1. Take the next `D-NNN` id (the log's index table lists the last one used).
2. Append a record to `defect-log.md` following `defect-template.md`.
3. Add the id to the index table at the top of the log, in the same change.

A defect is **open** until the thing that fixes it is committed; then the record's
`**Status**` moves to `Closed` with a link to the fix. Do not delete records — closing them in
place keeps the log honest about what went wrong and why, exactly as the phase docs supersede
rather than silently edit.

## Relationship to the other memory files

The defect log is the *evidence*. `LEARN.md` is the *lesson* — a defect general enough to happen
again becomes an `L-NNN` entry there. `MEMORY.md` is the *current state* snapshot, not the
history, so a defect only appears there if it is still affecting the state of play.

---
**Prerequisite**: none — this folder is process infrastructure, not a design phase. It exists
alongside phases 1–7 rather than after them.
