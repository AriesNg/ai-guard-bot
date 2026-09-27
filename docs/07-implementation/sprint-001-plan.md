# Sprint 1 Plan

**Goal**: Project scaffold, auth, and landing page
**Milestone**: [Sprint 1](https://github.com/AriesNg/ai-guard-bot/milestone/1)

## Scope

Each row is one GitHub issue; this table is the sprint's snapshot of them, not a second work
queue. File them with `gh issue create --template task.yml` / `--template user-story.yml`, assign
them the Sprint 1 milestone, then fill in the Issue column. See
[`issue-tracking.md`](issue-tracking.md).

| Issue | Type | Item |
|-------|------|------|
| _unfiled_ | task | Initialize Next.js project with TypeScript, ESLint, Prettier |
| _unfiled_ | task | Set up project folder structure per solution design |
| _unfiled_ | story | Implement authentication (sign-up, sign-in, sign-out) |
| _unfiled_ | story | Create landing page (unauthenticated) |
| _unfiled_ | story | Create dashboard shell (authenticated) |
| _unfiled_ | task | Set up CI pipeline (lint → test → build) |
| _unfiled_ | task | Write tests for auth flow |

> These items predate the project brief and describe a generic web app, not AI Guard Bot. Re-derive
> them from the approved Phase 1 stories before filing anything — do not file them as they stand.

Live view of what is actually in the sprint:

```bash
gh issue list --milestone "Sprint 1"
```

## Technical Details
<!-- AI fills in: packages to install, components to create, API routes needed -->

## Review Checklist
- [ ] Every issue in the milestone is closed or explicitly carried over
- [ ] Acceptance criteria verified on each closed story, with the evidence in its PR
- [ ] Tests pass
- [ ] CI green
- [ ] No secrets in code
- [ ] Responsive layout works
- [ ] Defects found this sprint are filed, labelled, and triaged (not left in chat)
