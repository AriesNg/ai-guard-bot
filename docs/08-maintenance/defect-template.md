# Defect record template

Copy this block when raising a defect. Replace `N` with the next id, fill every field, and
delete this header (the template is a shape, not a record — it is deliberately excluded from the
`status` check in `tests/docs/verify-docs.sh`).

```markdown
### D-NNN — Short imperative title

- **Severity**: Critical | Major | Minor
- **Status**: Open | Closed
- **Found by**: <a test name> | <a human gate> | <review>
- **Found**: 2026-10-02
- **Impact**: What breaks, and for whom, in one or two sentences.
- **Fix**: What was done, or what will be done. Link the commit or the file when closed.

---
```

Rules:

- One defect per record. A second defect is a second `D-NNN`.
- `**Severity**` is `Critical` only when the repo is wrong in a way that misleads a reader or
  blocks approval — a stale instruction file, a broken link in a decision doc, a test that
  passes while the thing it checks is broken.
- A record stays `Open` until the fix is committed; closing it without a fix is the one thing
  this log forbids.
