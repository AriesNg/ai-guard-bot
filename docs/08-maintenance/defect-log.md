# Defect log

**Status**: Draft

Every defect found in this repository, one record per defect. Open until fixed, then closed in
place. The shape of a record is in `defect-template.md`; the process is in `README.md`.

## Index

| Id | Title | Severity | Status |
|----|-------|----------|--------|
| [D-001](#d-001) | Folder name misspelled "maintainence" | Minor | Closed |
| [D-002](#d-002) | LEARN.md and MEMORY.md lost from master by a force-push | Major | Closed |

---

### D-001 — Folder name misspelled "maintainence"

- **Severity**: Minor
- **Status**: Closed
- **Found by**: review of the repo layout
- **Found**: 2026-10-02
- **Impact**: The maintenance folder was named `docs/08-maintainence/` (a misspelling of
  "maintenance"). It was empty and unlisted, so nothing linked to it, but a misspelled path is a
  broken-link trap for anything that tries to follow the phase numbering.
- **Fix**: Renamed to `docs/08-maintenance/`, documented as Phase 8 in `CLAUDE.md`, and wired
  into `tests/docs/verify-docs.sh` (`phases` check) so the two cannot drift again.

### D-002 — LEARN.md and MEMORY.md lost from master by a force-push

- **Severity**: Major
- **Status**: Closed
- **Found by**: review of branch/merge state (2026-10-02)
- **Found**: 2026-10-02
- **Impact**: `LEARN.md` and `MEMORY.md` existed on branch `worktree-docs-learn-memory` and were
  merged as PR #1, but a later history rewrite dropped that merge from `origin/master`. The
  repository lost its two shared-memory files — the lessons and the project-state snapshot every
  contributor (human or AI) is meant to start from.
- **Fix**: Recovered the originals from `worktree-docs-learn-memory`, updated them to the current
  state of the repo, and restored them to `master`. `tests/docs/verify-docs.sh` (`memory` check)
  now fails if either file is missing, so a silent loss cannot recur.
